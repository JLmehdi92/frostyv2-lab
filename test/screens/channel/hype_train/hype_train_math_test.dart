import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_math.dart';

import '../../../fixtures/hype_train_payloads.dart';
import 'hype_train_test_data.dart';

void main() {
  group('percent', () {
    test('uses the in-level values', () {
      expect(percent(progress(value: 1540, goal: 4700)), 33);
    });

    test('a zero goal is 0', () {
      expect(percent(progress(value: 10, goal: 0)), 0);
    });

    test('overflow clamps to 100', () {
      expect(percent(progress(value: 5000, goal: 4700)), 100);
    });
  });

  test('the final level is maxLevel', () {
    expect(isFinalLevel(train(level: 391, maxLevel: 392)), isFalse);
    expect(isFinalLevel(train(level: 392, maxLevel: 392)), isTrue);
    expect(isFinalLevel(train(level: 392)), isFalse);
  });

  group('levelTarget', () {
    test('subs and Bits to finish the level', () {
      final target = levelTarget(
        train(goal: 4700, rates: const {'TIER_1_SUB': 500, 'CHEER': 1}),
      );

      expect(target.subs, 10);
      expect(target.bits, 4700);
    });

    test('missing rates fall back to 500 per sub and 1 per Bit', () {
      final target = levelTarget(train(goal: 1001));

      expect(target.subs, 3);
      expect(target.bits, 1001);
    });

    test('the whole in-level goal counts, not what is left (D6)', () {
      final target = levelTarget(train(value: 4000, goal: 4700));

      expect(target.subs, 10);
      expect(target.bits, 4700);
    });

    test('a zero goal needs nothing', () {
      final target = levelTarget(train(goal: 0));

      expect(target.subs, 0);
      expect(target.bits, 0);
    });
  });

  test('top shares are sorted and capped', () {
    final shared = HtShared(
      id: 's',
      channels: [
        for (final (id, total) in [
          ('a', 100),
          ('b', 400),
          ('c', 300),
          ('d', 200),
        ])
          HtSharedChannel(
            user: user(id),
            progress: progress(total: total),
          ),
      ],
    );

    final shares = topShares(shared);

    expect(shares.map((s) => s.$1.user.id), ['b', 'c', 'd']);
    expect(shares.map((s) => s.$2), [40, 30, 20]);
  });

  test('top shares without totals are empty', () {
    final shared = HtShared(
      id: 's',
      channels: [HtSharedChannel(user: user('a'))],
    );

    expect(topShares(shared), isEmpty);
  });

  test('the record percentage is capped at 100', () {
    const ath = HtAth(level: 5, goal: 100, progression: 50, total: 10000);

    expect(athPercent(5000, ath), 50);
    expect(athPercent(25000, ath), 100);
    expect(
      athPercent(10, const HtAth(level: 1, goal: 0, progression: 0, total: 0)),
      0,
    );
  });

  test('end totals from the captured end', () {
    final end = HypeTrainEvent.parse(htEndCompleted) as HtEndEvent;

    final totals = endTotals(end.totals);

    expect(totals.subs, 6);
    expect(totals.bits, 0);
  });

  test('treasure states around the threshold', () {
    HtUnlockState? state(int level) => treasureState(
      train(
        level: level,
        treasure: const HtTreasure(
          discountPercentage: 50,
          threshold: 2,
          status: HtUnlockStatus.none,
        ),
      ),
    );

    expect(state(1), HtUnlockState.oneLevelAway);
    expect(state(2), HtUnlockState.unlockNow);
    expect(state(3), HtUnlockState.unlocked);
    expect(treasureState(train()), isNull);
  });

  test('community threshold defaults to 5', () {
    final community = HtCommunity.parse(const {});
    HtUnlockState? state(int level) =>
        communityState(train(level: level, community: community));

    expect(state(3), HtUnlockState.locked);
    expect(state(4), HtUnlockState.oneLevelAway);
    expect(state(5), HtUnlockState.unlockNow);
    expect(state(6), HtUnlockState.unlocked);
  });
}
