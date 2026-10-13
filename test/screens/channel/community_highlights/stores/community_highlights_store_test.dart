import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_community_highlights_service.dart';
import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/community_highlights_harness.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());

  // fake_async drives `clock` too, from [harnessNow].
  void run(void Function(FakeAsync async) body) =>
      fakeAsync(body, initialTime: harnessNow);

  test('subscribes the four public topics and cancels them on dispose', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      expect(h.subscribed, {
        'polls.42',
        'predictions-channel-v1.42',
        'pinned-chat-updates-v1.42',
        'raid.42',
      });

      h.store.dispose();
      h.store.dispose();
      expect(h.cancelled.toSet(), h.subscribed.toSet());
      expect(h.cancelled, hasLength(4));
    });
  });

  test('the initial pinned message is sticky; a new poll takes the slot', () {
    run((async) {
      when(
        () => h.service.getPinned(any()),
      ).thenAnswer((_) async => pinnedModel('pin'));
      h.create();
      async.flushMicrotasks();
      expect(h.store.current!.kind, HighlightKind.pinned);

      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      async.flushMicrotasks();
      expect(h.store.current!.kind, HighlightKind.poll);
      expect(h.store.stack.items.last.kind, HighlightKind.pinned);
      h.store.dispose();
    });
  });

  test('one failing fetch never blocks the others', () {
    run((async) {
      when(() => h.service.getPoll(any())).thenThrow(Exception('down'));
      when(
        () => h.service.getPinned(any()),
      ).thenAnswer((_) async => pinnedModel('pin'));
      h.create();
      async.flushMicrotasks();
      expect(h.store.pinned?.id, 'pin');
      h.store.dispose();
    });
  });

  test('frequent vote updates reach the screen at most twice a second', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      var commits = 0;
      final dispose = mobx.reaction((_) => h.store.poll, (_) => commits++);

      for (var i = 0; i < 20; i++) {
        h.send(
          HighlightTopic.polls,
          pollPayload('POLL_UPDATE', votes: [i + 2, i + 3]),
        );
        async.elapse(const Duration(milliseconds: 50));
      }
      async.elapse(const Duration(milliseconds: 600));

      expect(commits, lessThanOrEqualTo(3));
      expect(h.store.poll!.totalVotes, 21 + 22);
      dispose();
      h.store.dispose();
    });
  });

  test('a status change shows at once; results linger 60 s', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      h.send(
        HighlightTopic.polls,
        pollPayload('POLL_COMPLETE', status: 'COMPLETED', endedAt: harnessNow),
      );
      expect(h.store.poll!.status, PollStatus.completed);

      async.elapse(const Duration(seconds: 59));
      expect(h.store.poll, isNotNull);
      async.elapse(const Duration(seconds: 2));
      expect(h.store.poll, isNull);
      expect(h.store.stack.items, isEmpty);
      h.store.dispose();
    });
  });

  test('an archive removes the results sooner', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(
        HighlightTopic.polls,
        pollPayload('POLL_COMPLETE', status: 'COMPLETED', endedAt: harnessNow),
      );
      h.send(
        HighlightTopic.polls,
        pollPayload('POLL_ARCHIVE', status: 'ARCHIVED'),
      );
      expect(h.store.poll, isNull);
      h.store.dispose();
    });
  });

  test("another channel's events are dropped", () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE', owner: '99'));
      h.send(HighlightTopic.raid, raidPayload('raid_update_v2', source: '99'));
      expect(h.store.stack.items, isEmpty);
      h.store.dispose();
    });
  });

  test('an old resolved prediction from GQL is not shown', () {
    run((async) {
      when(() => h.service.getPredictions(any())).thenAnswer(
        (_) async => (
          active: null,
          locked: null,
          lastResolved: Prediction.fromPubsub({
            'id': 'old',
            'status': 'RESOLVED',
            'ended_at': harnessNow
                .subtract(const Duration(days: 5))
                .toIso8601String(),
            'outcomes': const [],
          }),
        ),
      );
      h.create();
      async.flushMicrotasks();
      expect(h.store.prediction, isNull);
      h.store.dispose();
    });
  });

  test('a prediction resolves, then leaves after 60 s', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.predictions, predictionPayload());
      expect(h.store.prediction!.status, PredictionStatus.active);
      h.send(
        HighlightTopic.predictions,
        predictionPayload(status: 'RESOLVED', endedAt: harnessNow, winner: 'a'),
      );
      expect(h.store.prediction!.winningOutcomeId, 'a');
      async.elapse(const Duration(seconds: 61));
      expect(h.store.prediction, isNull);
      h.store.dispose();
    });
  });

  test('a pinned message expires on its end; unpin removes it', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(
        HighlightTopic.pinned,
        pinPayload('a', endsAt: harnessNow.add(const Duration(seconds: 30))),
      );
      expect(h.store.pinned?.id, 'a');
      async.elapse(const Duration(seconds: 31));
      expect(h.store.pinned, isNull);

      h.send(HighlightTopic.pinned, pinPayload('b'));
      h.send(
        HighlightTopic.pinned,
        jsonEncode({
          'type': 'unpin-message',
          'data': {'id': 'b'},
        }),
      );
      expect(h.store.pinned, isNull);
      h.store.dispose();
    });
  });

  test('an update-message refetches the pin, at most every 2 s', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.pinned, pinPayload('a'));
      clearInteractions(h.service);
      for (var i = 0; i < 3; i++) {
        h.send(
          HighlightTopic.pinned,
          jsonEncode({
            'type': 'update-message',
            'data': {'id': 'a', 'updated_at': 1},
          }),
        );
      }
      async.elapse(const Duration(seconds: 3));
      final calls = verify(() => h.service.getPinned(harnessChannel)).callCount;
      expect(calls, inInclusiveRange(1, 2));
      h.store.dispose();
    });
  });

  test('a resubscribe refetches that kind only', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      clearInteractions(h.service);
      h.topics[HighlightTopic.polls]!.add(
        const RealtimeSubscribed(isResubscribe: true),
      );
      async.flushMicrotasks();
      verify(() => h.service.getPoll(harnessChannel)).called(1);
      verifyNever(() => h.service.getPinned(any()));
      h.store.dispose();
    });
  });

  test('without realtime, GQL is polled every 30 s until it is back', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      clearInteractions(h.service);
      h.topics[HighlightTopic.polls]!.add(const RealtimeUnavailable('down'));
      async.elapse(const Duration(seconds: 61));
      verify(() => h.service.getPoll(harnessChannel)).called(2);

      h.topics[HighlightTopic.polls]!.add(
        const RealtimeSubscribed(isResubscribe: false),
      );
      clearInteractions(h.service);
      async.elapse(const Duration(seconds: 61));
      verifyNever(() => h.service.getPoll(any()));
      h.store.dispose();
    });
  });

  test('three failed fetches turn a kind off for the session', () {
    run((async) {
      when(
        () => h.service.getPoll(any()),
      ).thenThrow(const CommunityHighlightsApiException('schema'));
      h.create();
      async.flushMicrotasks();
      h.topics[HighlightTopic.polls]!.add(const RealtimeUnavailable('down'));
      async.elapse(const Duration(minutes: 5));
      verify(() => h.service.getPoll(harnessChannel)).called(3);
      h.store.dispose();
    });
  });

  test('a late answer after dispose is ignored', () {
    run((async) {
      final late = Completer<Poll?>();
      when(() => h.service.getPoll(any())).thenAnswer((_) => late.future);
      h.create();
      async.flushMicrotasks();
      h.store.dispose();
      late.complete(
        Poll.fromPubsub(
          (jsonDecode(pollPayload('POLL_CREATE')) as Map)['data']['poll'],
        ),
      );
      async.flushMicrotasks();
      expect(h.store.poll, isNull);
    });
  });

  test('an outgoing raid: updates, leaves, then goes away', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.raid, raidPayload('raid_update_v2'));
      expect(h.store.raid!.raid.targetLogin, 'friend');
      expect(h.store.current!.kind, HighlightKind.raid);
      for (var i = 0; i < 5; i++) {
        h.send(HighlightTopic.raid, raidPayload('raid_go_v2'));
      }
      expect(h.store.raid!.gone, isTrue);
      async.elapse(const Duration(seconds: 61));
      expect(h.store.raid, isNull);
      h.store.dispose();
    });
  });

  test('dismiss hides that highlight for the session', () {
    run((async) {
      h.create();
      async.flushMicrotasks();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      h.store.dismissCurrent();
      expect(h.store.stack.items, isEmpty);
      h.send(HighlightTopic.polls, pollPayload('POLL_UPDATE', votes: [3, 3]));
      async.elapse(const Duration(seconds: 1));
      expect(h.store.stack.items, isEmpty);
      h.store.dispose();
    });
  });

  test('a stale first answer never wipes what Hermes sent meanwhile', () {
    run((async) {
      final poll = Completer<Poll?>();
      final pin = Completer<PinnedChatMessage?>();
      when(() => h.service.getPoll(any())).thenAnswer((_) => poll.future);
      when(() => h.service.getPinned(any())).thenAnswer((_) => pin.future);
      h.create();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      h.send(HighlightTopic.pinned, pinPayload('live'));
      poll.complete(null);
      pin.complete(pinnedModel('old'));
      async.flushMicrotasks();

      expect(h.store.poll?.id, 'p');
      expect(h.store.pinned?.id, 'live');
      h.store.dispose();
    });
  });

  test('a pin update during a refetch fetches once more', () {
    run((async) {
      var calls = 0;
      final answers = [
        pinnedModel('pin'),
        pinnedModel('pin', endsAt: harnessNow.add(const Duration(hours: 1))),
        pinnedModel('pin', endsAt: harnessNow.add(const Duration(hours: 2))),
      ];
      final pending = <Completer<PinnedChatMessage?>>[];
      when(() => h.service.getPinned(any())).thenAnswer((_) {
        final c = Completer<PinnedChatMessage?>();
        pending.add(c);
        calls++;
        return c.future;
      });
      h.create();
      pending.removeAt(0).complete(answers[0]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      final update = jsonEncode({
        'type': 'update-message',
        'data': {'id': 'pin', 'updated_at': harnessNow.toIso8601String()},
      });
      h.send(HighlightTopic.pinned, update);
      expect(calls, 2);
      // A second edit while the first refetch is still out.
      h.send(HighlightTopic.pinned, update);
      pending.removeAt(0).complete(answers[1]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      expect(calls, 3);
      pending.removeAt(0).complete(answers[2]);
      async.flushMicrotasks();

      expect(h.store.pinned?.endsAt, answers[2].endsAt);
      h.store.dispose();
    });
  });
}
