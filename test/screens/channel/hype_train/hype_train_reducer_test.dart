import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_reducer.dart';

import '../../../fixtures/hype_train_payloads.dart';
import 'hype_train_test_data.dart';

HtProgressionEvent progression({
  String? trainId = 'train',
  int level = 7,
  int value = 1600,
  int goal = 4700,
  required int total,
  int? sequenceId,
  DateTime? expiresAt,
  HtTreasure? treasure,
  HtAthState athState = HtAthState.none,
  Map<String, HtProgress>? sharedProgress,
  bool isLarge = false,
}) => HtProgressionEvent(
  trainId: trainId,
  sequenceId: sequenceId ?? total,
  action: const HtAction('CHEER'),
  source: HtSource.bits,
  quantity: 60,
  isLarge: isLarge,
  progress: progress(
    level: level,
    value: value,
    goal: goal,
    total: total,
    athState: athState,
  ),
  expiresAt: expiresAt,
  treasure: treasure,
  sharedProgress: sharedProgress,
);

HtLevelUpEvent levelUp(
  int level, {
  int total = 20000,
  DateTime? timeToExpire,
  HypeTrainExecution? train,
}) => HtLevelUpEvent(
  timeToExpire: timeToExpire ?? DateTime.utc(2026, 10, 13, 16),
  progress: progress(level: level, goal: 5000, total: total),
  train: train,
);

HtConductor conductor(HtSource source, String userId, int amount) =>
    HtConductor(
      source: source,
      user: user(userId),
      participations: {'CHEER': amount},
    );

void main() {
  late Set<String> seen;
  final running = train(level: 7, value: 1540, goal: 4700, total: 16040);

  setUp(() => seen = {});

  group('progression', () {
    test('applies at the same level and records its key', () {
      final expires = DateTime.utc(2026, 10, 13, 16, 5);
      final result = applyEvent(
        running,
        progression(total: 16100, expiresAt: expires),
        seenIds: seen,
      );

      expect(result.applied, isTrue);
      expect(result.train.progress.value, 1600);
      expect(result.train.progress.total, 16100);
      expect(result.train.expiresAt, expires);
      expect(seen, {'train:16100'});
    });

    test('a redelivered progression is ignored', () {
      final first = applyEvent(
        running,
        progression(total: 16100),
        seenIds: seen,
      );
      final second = applyEvent(
        first.train,
        progression(total: 16200),
        seenIds: seen,
      );
      expect(second.applied, isTrue, reason: 'same train, next sequence');

      final result = applyEvent(
        running,
        progression(total: 16100),
        seenIds: seen,
      );

      expect(result.applied, isFalse);
      expect(result.ignoredReason, 'duplicate');
      expect(identical(result.train, running), isTrue);
    });

    test('an older sequence id is ignored', () {
      final result = applyEvent(
        running,
        progression(total: 16000),
        seenIds: seen,
      );

      expect(result.applied, isFalse);
      expect(result.ignoredReason, 'stale');
    });

    test('the progression after its level-up still applies', () {
      final levelled = applyEvent(
        running,
        levelUp(8, total: 19300),
        seenIds: seen,
      ).train;

      final result = applyEvent(
        levelled,
        progression(level: 8, value: 100, goal: 5000, total: 19300),
        seenIds: seen,
      );

      expect(result.applied, isTrue);
      expect(result.levelChangedFrom, isNull);
    });

    test('a next-level progression is deferred, not applied', () {
      final result = applyEvent(
        running,
        progression(level: 8, value: 10, total: 19210),
        seenIds: seen,
      );

      expect(result.applied, isFalse);
      expect(result.deferredNextLevel, isTrue);
      expect(result.train.level, 7);
      expect(seen, isEmpty, reason: 'it may be applied later');
    });

    test('forcing a deferred progression changes the level', () {
      final result = applyEvent(
        running,
        progression(level: 8, value: 10, total: 19210),
        seenIds: seen,
        force: true,
      );

      expect(result.applied, isTrue);
      expect(result.train.level, 8);
      expect(result.levelChangedFrom, 7);
    });

    test('a two-level jump is ignored', () {
      final result = applyEvent(
        running,
        progression(level: 9, total: 25000),
        seenIds: seen,
      );

      expect(result.applied, isFalse);
      expect(result.ignoredReason, 'level mismatch');
    });

    test('keeps the expiry and treasure when the event has none', () {
      final expires = DateTime.utc(2026, 10, 13, 16);
      const treasure = HtTreasure(
        discountPercentage: 50,
        threshold: 9,
        status: HtUnlockStatus.none,
      );
      final before = train(
        level: 7,
        total: 100,
        treasure: treasure,
      ).copyWith(expiresAt: expires);

      final result = applyEvent(before, progression(total: 200), seenIds: seen);

      expect(result.train.expiresAt, expires);
      expect(result.train.treasure, same(treasure));
    });

    test('a shared train takes this channel\'s record state', () {
      final shared = HtShared(
        id: 's',
        channels: [
          HtSharedChannel(user: user('42'), progress: progress(total: 100)),
          HtSharedChannel(user: user('43'), progress: progress(total: 50)),
        ],
      );
      final before = train(level: 7, total: 150, shared: shared);

      final result = applyEvent(
        before,
        progression(
          total: 300,
          sharedProgress: {
            '42': progress(
              level: 7,
              total: 200,
              athState: HtAthState.approaching,
            ),
            '43': progress(level: 7, total: 100),
          },
        ),
        seenIds: seen,
        channelId: '42',
      );

      expect(result.train.progress.athState, HtAthState.approaching);
      expect(result.athTransition, HtAthTransition.approaching);
      expect(result.train.shared!.channels.map((c) => c.progress!.total), [
        200,
        100,
      ]);
    });
  });

  group('level-up', () {
    test('sets the expiry and records the level change', () {
      final result = applyEvent(
        running,
        levelUp(8, timeToExpire: DateTime.utc(2026, 10, 13, 16, 10)),
        seenIds: seen,
      );

      expect(result.applied, isTrue);
      expect(result.train.level, 8);
      expect(result.train.expiresAt, DateTime.utc(2026, 10, 13, 16, 10));
      expect(result.levelChangedFrom, 7);
    });

    test('the captured level-up refreshes the variant (golden)', () {
      final event = HypeTrainEvent.parse(htLevelUp) as HtLevelUpEvent;
      final before = train(
        id: event.train!.id,
        level: event.progress.level.value - 1,
        total: 10,
        conductors: [conductor(HtSource.bits, 'kept', 100)],
      );

      final result = applyEvent(before, event, seenIds: seen);

      expect(result.train.variant, HtVariant.goldenKappa);
      expect(result.train.level, event.progress.level.value);
      expect(result.train.expiresAt, event.timeToExpire);
      expect(result.train.conductors, isNotEmpty);
    });

    test('an older level-up is ignored', () {
      final result = applyEvent(running, levelUp(6), seenIds: seen);

      expect(result.applied, isFalse);
      expect(result.ignoredReason, 'stale');
    });

    test('the same level refreshes without a level change', () {
      final result = applyEvent(running, levelUp(7), seenIds: seen);

      expect(result.applied, isTrue);
      expect(result.levelChangedFrom, isNull);
    });

    test('treasure unlocks only at its threshold level', () {
      const treasure = HtTreasure(
        discountPercentage: 50,
        threshold: 3,
        status: HtUnlockStatus.none,
      );

      bool unlocked(int from) => applyEvent(
        train(level: from, treasure: treasure),
        levelUp(from + 1),
        seenIds: {},
      ).treasureUnlockedNow;

      expect(unlocked(1), isFalse);
      expect(unlocked(2), isTrue);
      expect(unlocked(3), isFalse);
    });

    test('community unlocks at its threshold level', () {
      final community = HtCommunity.parse(const {'rewardLevelThreshold': 4});

      final result = applyEvent(
        train(level: 3, community: community),
        levelUp(4),
        seenIds: seen,
      );

      expect(result.communityUnlockedNow, isTrue);
    });
  });

  group('record (all-time high)', () {
    test('none to approaching to reached is flagged', () {
      final approaching = applyEvent(
        running,
        progression(total: 16100, athState: HtAthState.approaching),
        seenIds: seen,
      );
      expect(approaching.athTransition, HtAthTransition.approaching);

      final still = applyEvent(
        approaching.train,
        progression(total: 16150, athState: HtAthState.approaching),
        seenIds: seen,
      );
      expect(still.athTransition, HtAthTransition.none);

      final reached = applyEvent(
        approaching.train,
        progression(total: 16200, athState: HtAthState.reached),
        seenIds: seen,
      );
      expect(reached.athTransition, HtAthTransition.reached);

      final again = applyEvent(
        reached.train,
        progression(total: 16300, athState: HtAthState.reached),
        seenIds: seen,
      );
      expect(again.athTransition, HtAthTransition.none);
    });
  });

  group('conductors', () {
    final bits = conductor(HtSource.bits, 'a', 100);
    final subs = conductor(HtSource.subs, 'b', 5);

    test('a new source goes to the top', () {
      final result = applyEvent(
        train(conductors: [bits]),
        HtConductorEvent(subs),
        seenIds: seen,
      );

      expect(result.train.conductors, [subs, bits]);
    });

    test('the same source is replaced in place', () {
      final newer = conductor(HtSource.bits, 'c', 500);

      final result = applyEvent(
        train(conductors: [subs, bits]),
        HtConductorEvent(newer),
        seenIds: seen,
      );

      expect(result.train.conductors, [subs, newer]);
    });
  });

  test('the end sets the reason, totals and rewards', () {
    final end = HypeTrainEvent.parse(htEndCompleted) as HtEndEvent;

    final result = applyEvent(running, end, seenIds: seen);

    expect(result.train.endReason, HtEndReason.completed);
    expect(result.train.endedAt, end.endedAt);
    expect(result.endTotals, end.totals);
    expect(result.endRewards, hasLength(3));
  });

  group('shared trains', () {
    test('channel left with shouldEnd completes the train', () {
      final result = applyEvent(
        running,
        const HtChannelLeftEvent(shouldEnd: true),
        seenIds: seen,
      );

      expect(result.train.endReason, HtEndReason.completed);
      expect(result.continuesIn, isNull);
    });

    test('channel left otherwise names where it continues', () {
      final result = applyEvent(
        running,
        HtChannelLeftEvent(shouldEnd: false, continuesIn: user('43')),
        seenIds: seen,
      );

      expect(result.train.endReason, HtEndReason.inProgress);
      expect(result.continuesIn!.id, '43');
    });

    test('a merge replaces the train', () {
      final merged = train(id: 'merged', level: 9, total: 30000);

      final result = applyEvent(
        running,
        HtMergeEvent(
          train: merged,
          previousProgress: running.progress,
          joiningChannels: [user('43')],
        ),
        seenIds: seen,
      );

      expect(result.train.id, 'merged');
      expect(result.train.level, 9);
      expect(result.levelChangedFrom, 7);
      expect(result.mergedFrom, same(running.progress));
      expect(result.joiningChannels.single.id, '43');
    });
  });

  test('a start replaces the train', () {
    final next = train(id: 'next', total: 100);

    final result = applyEvent(running, HtStartEvent(next), seenIds: seen);

    expect(result.applied, isTrue);
    expect(result.train, same(next));
  });

  test('other events leave the train alone', () {
    for (final event in const [HtIgnoredEvent('x'), HtUnknownEvent('y')]) {
      final result = applyEvent(running, event, seenIds: seen);

      expect(result.applied, isFalse);
      expect(identical(result.train, running), isTrue);
    }
  });
}
