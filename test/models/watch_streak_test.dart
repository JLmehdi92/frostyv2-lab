import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/watch_streak.dart';

Map<String, Object?> _milestone({
  Object? value = '4',
  int? threshold = 5,
  int? bonus = 450,
  String state = 'ACTIVE',
  String? expiresAt,
  String shareStatus = 'CAN_NOT_SHARE',
  bool optOut = false,
}) => {
  'data': {
    'channel': {
      'self': {
        'watchStreakMilestone': {
          'watchStreakMilestone': {
            'id': 'm1',
            'category': 'WATCH_STREAK',
            'value': value,
            'achievementTimestamp': '2026-10-19T20:00:00Z',
            'shareStatus': shareStatus,
          },
          'watchStreakThreshold': threshold,
          'watchStreakCopoBonus': bonus,
          'state': state,
          'expiresAt': expiresAt,
        },
      },
      'communityPointsSettings': {'isEnabled': true},
    },
    'channelViewerMilestoneSettings': {
      'id': '1',
      'isWatchStreakOptOut': optOut,
    },
  },
};

void main() {
  group('parsing Twitch WatchStreakMilestoneQuery', () {
    test('reads the streak, the next milestone and its bonus', () {
      final streak = WatchStreak.tryParse(_milestone())!;

      expect(streak.value, 4);
      expect(streak.threshold, 5);
      expect(streak.pointsBonus, 450);
      expect(streak.state, WatchStreakState.active);
      expect(streak.canShare, isFalse);
    });

    test('the suspended state and its deadline', () {
      final streak = WatchStreak.tryParse(
        _milestone(state: 'SUSPENDED', expiresAt: '2026-10-21T12:00:00Z'),
      )!;

      expect(streak.state, WatchStreakState.suspended);
      expect(streak.expiresAt, DateTime.utc(2026, 10, 21, 12));
    });

    test('nothing without a streak, an opt-out or an error', () {
      expect(
        WatchStreak.tryParse({
          'data': {
            'channel': {'self': null},
          },
        }),
        isNull,
      );
      expect(
        WatchStreak.tryParse({
          'data': {
            'channel': {
              'self': {'watchStreakMilestone': null},
            },
          },
        }),
        isNull,
      );
      expect(WatchStreak.tryParse(_milestone(optOut: true)), isNull);
      expect(WatchStreak.tryParse(_milestone(value: 'x')), isNull);
      expect(
        WatchStreak.tryParse({
          ..._milestone(),
          'errors': [
            {'message': 'failed integrity check'},
          ],
        }),
        isNull,
      );
      expect(WatchStreak.tryParse(null), isNull);
    });

    test('a numeric value is read too', () {
      expect(WatchStreak.tryParse(_milestone(value: 7))!.value, 7);
    });
  });

  group('the panel wording, as Twitch words it', () {
    final now = DateTime.utc(2026, 10, 20, 12);

    WatchStreakCopy copy(WatchStreak streak, {bool live = true}) =>
        streak.copy(live: live, channelName: 'Ninja', now: now);

    test('a running streak says how far the next bonus is', () {
      final text = copy(
        const WatchStreak(value: 2, threshold: 5, pointsBonus: 1500),
      );

      expect(text.title, 'Your Watch Streak: 2');
      expect(
        text.subtitle,
        'Reach 5-stream streak and earn an extra 1,500 channel points',
      );
    });

    test('one stream away', () {
      expect(
        copy(
          const WatchStreak(value: 4, threshold: 5, pointsBonus: 450),
        ).subtitle,
        '1 more stream until an extra 450 channel points reward',
      );
    });

    test('a milestone that can be shared was just reached', () {
      expect(
        copy(
          const WatchStreak(
            value: 5,
            threshold: 10,
            pointsBonus: 450,
            canShare: true,
          ),
        ).subtitle,
        'You reached a 10-stream streak and earned an extra 450 channel points',
      );
    });

    test('no milestone known, no subtitle', () {
      expect(copy(const WatchStreak(value: 3)).subtitle, isNull);
    });

    test('a suspended streak while the channel is live', () {
      final text = copy(
        const WatchStreak(value: 8, state: WatchStreakState.suspended),
      );

      expect(text.title, 'Keep watching to save your Watch Streak!');
      expect(
        text.subtitle,
        "Watch this live stream and you'll be able to save your current "
        '8-stream streak.',
      );
    });

    test('a suspended streak while the channel is offline', () {
      final text = copy(
        WatchStreak(
          value: 8,
          state: WatchStreakState.suspended,
          expiresAt: now.add(const Duration(hours: 5, minutes: 3, seconds: 9)),
        ),
        live: false,
      );

      expect(text.title, 'Watch Streak Expiring');
      expect(
        text.subtitle,
        'Watch Ninja in the next 5h 3m 9s to save your streak!',
      );
    });

    test('an expired deadline gives no countdown', () {
      final text = copy(
        WatchStreak(
          value: 8,
          state: WatchStreakState.suspended,
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
        live: false,
      );

      expect(text.title, 'Watch Streak Expiring');
      expect(text.subtitle, isNull);
    });
  });

  group('parsing Twitch BatchGetWatchStreaksQuery', () {
    test('keeps running streaks by channel id', () {
      final streaks = WatchStreak.parseBatch({
        'data': {
          'batchGetWatchStreaks': [
            {
              'channel': {'id': '1'},
              'value': 6,
              'isSuspended': false,
            },
            {
              'channel': {'id': '2'},
              'value': 3,
              'isSuspended': true,
            },
            {
              'channel': {'id': '3'},
              'value': 0,
              'isSuspended': false,
            },
            {'channel': null, 'value': 2},
            null,
          ],
        },
      });

      expect(streaks, {'1': 6});
    });

    test('an error or no list gives nothing', () {
      expect(
        WatchStreak.parseBatch({
          'data': {'batchGetWatchStreaks': null},
        }),
        isNull,
      );
      expect(
        WatchStreak.parseBatch({
          'errors': [
            {'message': 'x'},
          ],
        }),
        isNull,
      );
    });
  });
}
