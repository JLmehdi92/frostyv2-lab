import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/hype_train_payloads.dart';
import '../hype_train_test_data.dart';

class MockService extends Mock implements TwitchHypeTrainService {}

class MockRealtime extends Mock implements TwitchRealtimeClient {}

final _base = DateTime.utc(2026, 10, 13, 16);
const _topic = 'hype-train-events-v2.42';

HypeTrainExecution running({
  int level = 7,
  int value = 1540,
  int goal = 4700,
  int total = 16040,
  Duration expiresIn = const Duration(minutes: 5),
}) => train(
  level: level,
  value: value,
  goal: goal,
  total: total,
).copyWith(expiresAt: _base.add(expiresIn));

HtOngoingSnapshot ongoing(HypeTrainExecution train) =>
    HtOngoingSnapshot(train, fetchedAt: _base);

HtProgressionEvent small(int total, {int level = 7, int value = 1600}) =>
    HtProgressionEvent(
      trainId: 'train',
      sequenceId: total,
      action: const HtAction('CHEER'),
      source: HtSource.bits,
      quantity: 10,
      isLarge: false,
      progress: progress(level: level, value: value, goal: 4700, total: total),
    );

HtLevelUpEvent levelUp(int level, {int total = 20000, int value = 470}) =>
    HtLevelUpEvent(
      timeToExpire: _base.add(const Duration(minutes: 5)),
      progress: progress(level: level, value: value, goal: 4700, total: total),
    );

HypeTrainApproaching approachingIn(
  Map<int, int> deadlines, {
  Set<String> participants = const {},
}) => HypeTrainApproaching(
  id: 'a',
  goal: 3,
  deadlines: deadlines,
  participants: participants,
);

void main() {
  late MockService service;
  late MockRealtime realtime;
  late StreamController<RealtimeTopicEvent> topic;
  late bool cancelled;
  late int fetches;

  setUp(() {
    service = MockService();
    realtime = MockRealtime();
    topic = StreamController<RealtimeTopicEvent>.broadcast();
    cancelled = false;
    fetches = 0;
    when(() => realtime.subscribe(any())).thenAnswer(
      (invocation) => RealtimeTopicSubscription.forTesting(
        invocation.positionalArguments.first as String,
        topic.stream,
        () => cancelled = true,
      ),
    );
    when(() => service.getHypeTrain(any())).thenAnswer((_) async {
      fetches++;
      return const HtNoTrain();
    });
  });

  void snapshot(HypeTrainSnapshot Function() answer) {
    when(() => service.getHypeTrain(any())).thenAnswer((_) async {
      fetches++;
      return answer();
    });
  }

  HypeTrainStore build({String? viewerId, bool presenter = true}) {
    final store = HypeTrainStore(
      channelId: '42',
      service: service,
      realtime: realtime,
      viewerId: () => viewerId,
    );
    if (presenter) store.attachPresenter();
    return store;
  }

  void run(void Function(FakeAsync async) body) =>
      fakeAsync(body, initialTime: _base);

  group('startup and refetch', () {
    test('subscribes the channel topic and fetches once', () {
      run((async) {
        final store = build();
        async.flushMicrotasks();

        verify(() => realtime.subscribe(_topic)).called(1);
        expect(fetches, 1);
        expect(store.phase, HtPhase.hidden);
        store.dispose();
      });
    });

    test('an ongoing snapshot shows at once and counts down', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        expect(store.phase, HtPhase.ongoing);
        expect(store.percent, 33);
        expect(store.level, 7);
        expect(store.step, isNull, reason: 'no start sequence');
        expect(store.remaining, const Duration(minutes: 5));

        async.elapse(const Duration(seconds: 1));
        expect(store.remaining, const Duration(minutes: 4, seconds: 59));
        store.dispose();
      });
    });

    test('remainingSeconds of a snapshot wins over expiresAt', () {
      run((async) {
        final train = running().copyWith(
          progress: HtProgress(
            level: const HtLevel(value: 7, cumulativeGoal: 0),
            goal: 4700,
            value: 1540,
            total: 16040,
            remainingSeconds: 90,
          ),
        );
        snapshot(() => ongoing(train));
        final store = build();
        async.flushMicrotasks();

        expect(store.remaining, const Duration(seconds: 90));
        store.dispose();
      });
    });

    test('a failing service keeps the state', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        when(
          () => service.getHypeTrain(any()),
        ).thenThrow(const HypeTrainApiException('down'));

        async.elapse(const Duration(seconds: 3));
        topic.add(const RealtimeSubscribed(isResubscribe: true));
        async.flushMicrotasks();

        expect(store.phase, HtPhase.ongoing);
        expect(store.level, 7);

        when(
          () => service.getHypeTrain(any()),
        ).thenAnswer((_) => Future.error(const ApiException('network')));
        async.elapse(const Duration(seconds: 3));
        store.handleAppResume();
        async.flushMicrotasks();
        expect(store.phase, HtPhase.ongoing);
        store.dispose();
      });
    });
  });

  group('approaching', () {
    test('only when the first deadline is over 20 s away', () {
      run((async) {
        final store = build()
          ..injectEvent(HtApproachingEvent(approachingIn(const {1: 15})));
        async.flushMicrotasks();
        expect(store.phase, HtPhase.hidden);

        store.injectEvent(HtApproachingEvent(approachingIn(const {1: 25})));
        async.flushMicrotasks();
        expect(store.phase, HtPhase.approaching);
        expect(store.approaching, isNotNull);
        store.dispose();
      });
    });

    test('checks follow the deadline keys', () {
      run((async) {
        final store = build()
          ..injectEvent(
            HtApproachingEvent(approachingIn(const {1: 30, 2: 60})),
          );
        async.flushMicrotasks();
        expect(store.approachingChecks, 2);

        async.elapse(const Duration(seconds: 31));
        expect(store.approachingChecks, 1);
        expect(store.approachingFraction, greaterThan(0));
        store.dispose();
      });
    });

    test('a viewer who already took part sees "N more"', () {
      run((async) {
        final store = build(viewerId: 'me')
          ..injectEvent(
            HtApproachingEvent(
              approachingIn(const {1: 30}, participants: const {'me'}),
            ),
          );
        async.flushMicrotasks();

        expect(store.approachingNMore, isTrue);
        store.dispose();
      });
    });

    test('all deadlines passed without a start: refetch, then hidden', () {
      run((async) {
        final store = build()
          ..injectEvent(HtApproachingEvent(approachingIn(const {1: 30})));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 36));

        expect(store.phase, HtPhase.hidden);
        expect(fetches, 2);
        store.dispose();
      });
    });

    test('a start fills the bar, then plays the start sequence', () {
      run((async) {
        final store = build()
          ..injectEvent(HtApproachingEvent(approachingIn(const {1: 30})));
        async.flushMicrotasks();

        store.injectEvent(HtStartEvent(running(level: 1, value: 0)));
        expect(store.approachingCompleted, isTrue);
        async.flushMicrotasks();
        expect(store.phase, HtPhase.ongoing);
        expect(store.step?.kind, HtStepKind.fadeIn);

        async.elapse(const Duration(milliseconds: 500));
        expect(store.step?.kind, HtStepKind.marquee);
        async.elapse(const Duration(milliseconds: 3000));
        expect(store.step?.kind, HtStepKind.instruction);
        async.elapse(const Duration(milliseconds: 2000));
        expect(store.step, isNull);
        store.dispose();
      });
    });
  });

  test('a captured level-up shows a train we had not seen', () {
    run((async) {
      final store = build();
      async.flushMicrotasks();

      topic.add(RealtimeMessage(htLevelUp));
      async.flushMicrotasks();

      expect(store.phase, HtPhase.ongoing);
      expect(store.train!.variant, HtVariant.goldenKappa);
      expect(store.step, isNull, reason: 'shown as it is, no animation');
      expect(fetches, 1);
      store.dispose();
    });
  });

  test('a progression without a train asks GQL', () {
    run((async) {
      final store = build();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      topic.add(RealtimeMessage(htProgression));
      async.flushMicrotasks();

      expect(fetches, 2);
      expect(store.phase, HtPhase.hidden);
      store.dispose();
    });
  });

  group('pacing', () {
    test('events are shown one at a time', () {
      run((async) {
        final store = build()
          ..injectEvent(HtStartEvent(running(level: 1, value: 0, total: 0)))
          ..injectEvent(small(100, level: 1, value: 100));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 5400));
        expect(store.train!.progress.total, 0);
        async.elapse(const Duration(milliseconds: 200));
        expect(store.train!.progress.total, 100);
        store.dispose();
      });
    });

    test('a burst behind a long sequence is coalesced', () {
      run((async) {
        final store = build()
          ..injectEvent(HtStartEvent(running(level: 1, value: 0, total: 0)));
        async.flushMicrotasks();
        for (var i = 1; i <= 10; i++) {
          store.injectEvent(small(i * 10, level: 1, value: i * 10));
        }

        expect(store.queuedCount, lessThanOrEqualTo(5));
        async.elapse(const Duration(seconds: 10));
        expect(store.train!.progress.total, 100);
        store.dispose();
      });
    });

    test('a conductor update applies without a step', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store.injectEvent(
          HtConductorEvent(HtConductor(source: HtSource.bits, user: user('c'))),
        );
        async.flushMicrotasks();

        expect(store.train!.conductors.single.user.id, 'c');
        expect(store.step, isNull);
        store.dispose();
      });
    });

    test('a redelivered progression applies once', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store
          ..injectEvent(small(16100))
          ..injectEvent(small(16100));
        async.elapse(const Duration(seconds: 1));

        expect(store.appliedEvents, 1);
        store.dispose();
      });
    });

    test('a next-level progression waits for its level-up', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store.injectEvent(small(19400, level: 8, value: 200));
        async.elapse(const Duration(seconds: 1));
        expect(store.level, 7);

        store.injectEvent(levelUp(8, total: 19400, value: 200));
        async.flushMicrotasks();
        final kinds = <HtStepKind>{};
        for (var i = 0; i < 40; i++) {
          if (store.step case final step?) kinds.add(step.kind);
          async.elapse(const Duration(milliseconds: 100));
        }

        expect(kinds, contains(HtStepKind.levelComplete));
        expect(store.level, 8);
        expect(store.percent, 4);
        expect(fetches, 1, reason: 'no refetch needed');
        store.dispose();
      });
    });

    test('the pill and % follow the animation, not the data', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        expect(store.shownLevel, 7);
        expect(store.shownPercent, 33);

        store.injectEvent(levelUp(8));
        async.flushMicrotasks();
        expect(store.level, 8);
        expect(store.shownLevel, 7, reason: 'until level complete');
        expect(store.shownPercent, 100);

        async.elapse(const Duration(milliseconds: 3250));
        expect(store.step?.kind, HtStepKind.levelComplete);
        expect(store.shownLevel, 7);
        async.elapse(const Duration(milliseconds: 500));
        expect(store.shownLevel, 8);
        expect(store.shownPercent, 10);
        store.dispose();
      });
    });

    test('compact sequences still end on the true values', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build()..updatePresentation(compact: true);
        async.flushMicrotasks();

        store.injectEvent(small(16500, value: 2000));
        async.flushMicrotasks();

        expect(store.shownPercent, 43);
        store.dispose();
      });
    });

    test('a next-level progression alone refetches after 3 s', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store.injectEvent(small(19400, level: 8, value: 200));
        async.elapse(const Duration(milliseconds: 2900));
        expect(fetches, 1);
        async.elapse(const Duration(milliseconds: 200));
        expect(fetches, 2);
        store.dispose();
      });
    });

    test('without a presenter a level-up applies at once', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build(presenter: false);
        async.flushMicrotasks();

        store.injectEvent(levelUp(8));
        async.flushMicrotasks();

        expect(store.level, 8);
        expect(store.step, isNull);
        store.dispose();
      });
    });
  });

  group('end and expiry', () {
    test('completed: queue drained, end steps, rewards strip, hidden', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store
          ..injectEvent(levelUp(8))
          ..injectEvent(small(20100, level: 8))
          ..injectEvent(
            // The captured end, for this test's train id.
            HypeTrainEvent.parse(
              htEndCompleted.replaceAll(
                '00000000-0000-4000-8000-000000000004',
                'train',
              ),
            ),
          );
        async.flushMicrotasks();

        expect(store.level, 8, reason: 'drained before the end');
        expect(store.train!.progress.total, 20100);
        expect(store.phase, HtPhase.ending);
        expect(store.endSummary!.subs, 6);
        expect(store.endSummary!.reason, HtEndReason.completed);
        expect(store.endSummary!.rewards, hasLength(3));
        expect(store.unlockedRewards, hasLength(3));

        async.elapse(const Duration(seconds: 11));
        expect(store.phase, HtPhase.rewards);
        async.elapse(const Duration(seconds: 10));
        expect(store.stripFraction, closeTo(0.5, 0.05));
        async.elapse(const Duration(seconds: 10));
        expect(store.phase, HtPhase.hidden);
        expect(store.train, isNull);
        expect(store.unlockedRewards, isEmpty);
        store.dispose();
      });
    });

    test('no end event: completed 10 s after expiry from level 2', () {
      run((async) {
        snapshot(() => ongoing(running(expiresIn: const Duration(minutes: 1))));
        final store = build();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 69));
        expect(store.phase, HtPhase.ongoing);
        async.elapse(const Duration(seconds: 1));
        expect(store.phase, HtPhase.ending);
        expect(store.endSummary!.reason, HtEndReason.completed);
        store.dispose();
      });
    });

    test('no end event at level 1: expired', () {
      run((async) {
        snapshot(
          () =>
              ongoing(running(level: 1, expiresIn: const Duration(minutes: 1))),
        );
        final store = build();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 70));
        expect(store.phase, HtPhase.expired);
        expect(store.endSummary!.reason, HtEndReason.expired);
        async.elapse(const Duration(seconds: 20));
        expect(store.phase, HtPhase.hidden);
        store.dispose();
      });
    });

    test('an end at +9 s cancels the fallback', () {
      run((async) {
        snapshot(() => ongoing(running(expiresIn: const Duration(minutes: 1))));
        final store = build();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 69));
        store.injectEvent(const HtEndEvent(reason: HtEndReason.expired));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(store.phase, HtPhase.expired);
        expect(store.endSummary!.reason, HtEndReason.expired);
        store.dispose();
      });
    });

    test('an approaching train cuts the strip short', () {
      run((async) {
        snapshot(() => ongoing(running(level: 1)));
        final store = build();
        async.flushMicrotasks();
        store.injectEvent(const HtEndEvent(reason: HtEndReason.expired));
        async.flushMicrotasks();
        expect(store.phase, HtPhase.expired);

        store.injectEvent(HtApproachingEvent(approachingIn(const {1: 60})));
        async.flushMicrotasks();

        expect(store.phase, HtPhase.approaching);
        store.dispose();
      });
    });
  });

  group('review fixes', () {
    test('a queued level-up keeps the expiry fallback away', () {
      run((async) {
        snapshot(
          () => ongoing(running(expiresIn: const Duration(seconds: 20))),
        );
        final store = build();
        async.flushMicrotasks();
        for (var i = 1; i <= 6; i++) {
          store.injectEvent(
            HtProgressionEvent(
              trainId: 'train',
              sequenceId: 16040 + i * 10,
              action: const HtAction('TIER_1_GIFTED_SUB'),
              source: HtSource.subs,
              quantity: 50,
              isLarge: true,
              progress: progress(
                level: 7,
                value: 1540 + i * 10,
                goal: 4700,
                total: 16040 + i * 10,
              ),
            ),
          );
        }
        async.elapse(const Duration(seconds: 18));
        store
          ..injectEvent(small(19400, level: 8, value: 200))
          ..injectEvent(levelUp(8, total: 19400, value: 200));

        async.elapse(const Duration(seconds: 13));
        expect(store.phase, HtPhase.ongoing);
        async.elapse(const Duration(seconds: 40));
        expect(store.phase, HtPhase.ongoing);
        expect(store.level, 8);
        store.dispose();
      });
    });

    test('a train our fallback ended comes back when it moves', () {
      run((async) {
        var answer = ongoing(running(expiresIn: const Duration(seconds: 5)));
        snapshot(() => answer);
        final store = build();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 16));
        expect(store.phase, HtPhase.ending);

        answer = ongoing(
          running(total: 16500, expiresIn: const Duration(minutes: 2)),
        );
        store.injectEvent(small(16500));
        async.elapse(const Duration(seconds: 3));

        expect(store.phase, HtPhase.ongoing);
        expect(store.train!.progress.total, 16500);
        store.dispose();
      });
    });

    test("Twitch's own end is not undone by a late snapshot", () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        store.injectEvent(const HtEndEvent(reason: HtEndReason.completed));
        async.elapse(const Duration(seconds: 3));

        store.handleAppResume();
        async.flushMicrotasks();

        expect(store.phase, HtPhase.ending);
        store.dispose();
      });
    });

    test('a late start of the running train changes nothing', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store.injectEvent(HtStartEvent(train(total: 0)));
        async.flushMicrotasks();

        expect(store.level, 7);
        expect(store.train!.progress.total, 16040);
        expect(store.step, isNull);
        store.dispose();
      });
    });

    test('a level gap asks GQL', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        store.injectEvent(small(30000, level: 9));
        async.flushMicrotasks();

        expect(fetches, 2);
        store.dispose();
      });
    });

    test('an end keeps a deferred level', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        store.injectEvent(small(19400, level: 8, value: 200));
        async.elapse(const Duration(milliseconds: 500));
        store.injectEvent(const HtEndEvent(reason: HtEndReason.completed));

        expect(store.endSummary!.level, 8);
        store.dispose();
      });
    });

    test('an unchanged snapshot does not cut the animation', () {
      run((async) {
        snapshot(() => ongoing(running(level: 1, value: 0, total: 0)));
        final store = build()
          ..injectEvent(HtStartEvent(running(level: 1, value: 0, total: 0)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 3000));
        expect(store.step?.kind, HtStepKind.marquee);

        topic.add(const RealtimeSubscribed(isResubscribe: true));
        async.flushMicrotasks();

        expect(store.step?.kind, HtStepKind.marquee);
        store.dispose();
      });
    });

    test('an approaching banner on screen takes later updates', () {
      run((async) {
        final store = build(viewerId: 'me')
          ..injectEvent(HtApproachingEvent(approachingIn(const {1: 30})));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 12));

        store.injectEvent(
          HtApproachingEvent(
            approachingIn(const {1: 15, 2: 50}, participants: const {'me'}),
          ),
        );
        async.flushMicrotasks();

        expect(store.approachingNMore, isTrue);
        expect(store.approachingChecks, 2);
        store.dispose();
      });
    });

    test("another train's events are not applied; GQL is asked", () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        store
          ..injectEvent(
            const HtEndEvent(reason: HtEndReason.completed, trainId: 'old'),
          )
          ..injectEvent(
            HtProgressionEvent(
              trainId: 'other',
              sequenceId: 16100,
              action: const HtAction('CHEER'),
              source: HtSource.bits,
              quantity: 1,
              isLarge: false,
              progress: progress(level: 7, total: 16100),
            ),
          );
        async.flushMicrotasks();

        expect(store.phase, HtPhase.ongoing);
        expect(store.train!.progress.total, 16040);
        async.elapse(const Duration(seconds: 3));
        expect(fetches, 3, reason: 'one fetch now, one trailing for both');
        store.dispose();
      });
    });

    test('polling stops during the end', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        topic.add(const RealtimeUnavailable('reconnecting'));
        async.flushMicrotasks();

        store.injectEvent(const HtEndEvent(reason: HtEndReason.completed));
        final before = fetches;
        async.elapse(const Duration(seconds: 25));

        expect(fetches, before);
        store.dispose();
      });
    });
  });

  group('recovery and lifecycle', () {
    test('refetches are at most every 2 s, and none is lost', () {
      run((async) {
        build();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        topic.add(const RealtimeSubscribed(isResubscribe: true));
        async.flushMicrotasks();
        expect(fetches, 2);

        async.elapse(const Duration(seconds: 1));
        topic
          ..add(const RealtimeSubscribed(isResubscribe: true))
          ..add(const RealtimeSubscribed(isResubscribe: true));
        async.flushMicrotasks();
        expect(fetches, 2, reason: 'too soon');

        async.elapse(const Duration(seconds: 1));
        expect(fetches, 3, reason: 'one trailing fetch for both');
        async.elapse(const Duration(seconds: 10));
        expect(fetches, 3);
      });
    });

    test('a refetch asked during a fetch runs after it', () {
      run((async) {
        final first = Completer<HypeTrainSnapshot>();
        var calls = 0;
        when(() => service.getHypeTrain(any())).thenAnswer((_) {
          calls++;
          return calls == 1 ? first.future : Future.value(ongoing(running()));
        });
        final store = build();
        async.flushMicrotasks();

        // A progression with no train asks GQL while the startup fetch runs.
        store.injectEvent(small(16100));
        first.complete(const HtNoTrain());
        async.elapse(const Duration(seconds: 3));

        expect(calls, 2);
        expect(store.phase, HtPhase.ongoing);
        store.dispose();
      });
    });

    test('degraded realtime polls every 20 s while a train runs', () {
      run((async) {
        var answer = ongoing(running()) as HypeTrainSnapshot;
        snapshot(() => answer);
        final store = build();
        async.flushMicrotasks();

        topic.add(const RealtimeUnavailable('reconnecting'));
        async.flushMicrotasks();
        expect(store.realtimeDegraded, isTrue);
        async.elapse(const Duration(seconds: 41));
        expect(fetches, 3);

        answer = const HtNoTrain();
        store.injectEvent(const HtEndEvent(reason: HtEndReason.expired));
        async.elapse(const Duration(seconds: 25));
        expect(store.phase, HtPhase.hidden);
        final after = fetches;
        async.elapse(const Duration(minutes: 2));
        expect(fetches, after, reason: 'no polling while hidden');

        topic.add(const RealtimeSubscribed(isResubscribe: false));
        async.flushMicrotasks();
        expect(store.realtimeDegraded, isFalse);
        store.dispose();
      });
    });

    test('notification times correct the countdown', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();

        for (var i = 0; i < 3; i++) {
          topic.add(
            RealtimeMessage(
              '{"type":"hype-train-cooldown-expiration","data":{}}',
              serverTime: _base.add(const Duration(seconds: 3)),
            ),
          );
        }
        async.elapse(const Duration(seconds: 1));

        expect(store.remaining, const Duration(minutes: 4, seconds: 56));
        store.dispose();
      });
    });

    test('resuming the app refetches', () {
      run((async) {
        final store = build();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        store.handleAppResume();
        async.flushMicrotasks();

        expect(fetches, 2);
        store.dispose();
      });
    });

    test('dispose cancels everything', () {
      run((async) {
        snapshot(() => ongoing(running()));
        final store = build();
        async.flushMicrotasks();
        topic.add(const RealtimeUnavailable('reconnecting'));
        store.injectEvent(small(16100));
        async.flushMicrotasks();

        store
          ..dispose()
          ..dispose();
        async.flushMicrotasks();

        expect(cancelled, isTrue);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  test('upcoming rewards are fetched once per train', () {
    run((async) {
      snapshot(() => ongoing(running()));
      when(() => service.getUpcomingRewards(any())).thenAnswer(
        (_) async => [
          (8, [const HtReward(type: HtRewardType.emote, id: 'e', token: 't')]),
        ],
      );
      final store = build();
      async.flushMicrotasks();

      List<(int, List<HtReward>)>? first;
      store.loadUpcomingRewards().then((v) => first = v);
      store.loadUpcomingRewards();
      async.flushMicrotasks();

      expect(first!.single.$1, 8);
      verify(() => service.getUpcomingRewards('42')).called(1);
      store.dispose();
    });
  });

  test('the details close when the train is gone', () {
    run((async) {
      snapshot(() => ongoing(running(level: 1)));
      final store = build();
      async.flushMicrotasks();
      store.toggleExpanded();
      expect(store.expanded, isTrue);

      store.injectEvent(const HtEndEvent(reason: HtEndReason.expired));
      async.elapse(const Duration(seconds: 21));

      expect(store.expanded, isFalse);
      store.dispose();
    });
  });

  test('the style follows the priority order', () {
    run((async) {
      snapshot(
        () => ongoing(
          running().copyWith(
            variant: HtVariant.goldenKappa,
            progress: progress(
              level: 7,
              total: 16040,
              athState: HtAthState.approaching,
            ),
          ),
        ),
      );
      final store = build();
      async.flushMicrotasks();

      expect(store.style, HtStyle.athApproaching);
      store.dispose();
    });
  });
}
