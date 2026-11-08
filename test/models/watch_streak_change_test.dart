import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/models/watch_streak.dart';

void main() {
  const suspended = WatchStreak(value: 6, state: WatchStreakState.suspended);

  test('a suspended streak running again was recovered', () {
    expect(
      watchStreakChange(suspended, const WatchStreak(value: 7)),
      WatchStreakChange.recovered,
    );
  });

  test('a suspended streak gone to none or reset has expired', () {
    expect(
      watchStreakChange(
        suspended,
        const WatchStreak(value: 0, state: WatchStreakState.none),
      ),
      WatchStreakChange.expired,
    );
    expect(
      watchStreakChange(suspended, const WatchStreak(value: 1)),
      WatchStreakChange.expired,
    );
  });

  test('nothing to say otherwise', () {
    expect(watchStreakChange(null, const WatchStreak(value: 3)), isNull);
    expect(
      watchStreakChange(const WatchStreak(value: 3), const WatchStreak(value: 4)),
      isNull,
    );
    expect(watchStreakChange(suspended, suspended), isNull);
    expect(watchStreakChange(suspended, null), isNull);
  });

  test('the snack bar says what happened', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      watchStreakChangeText(
        WatchStreakChange.recovered,
        streak: const WatchStreak(value: 7),
        l: l,
      ),
      'Your watch streak is saved: 7 streams in a row.',
    );
    expect(
      watchStreakChangeText(WatchStreakChange.expired, streak: null, l: l),
      'Your watch streak in this channel has ended.',
    );
  });
}
