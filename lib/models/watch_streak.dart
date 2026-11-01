import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';

/// Twitch's state of a viewer's watch streak in a channel.
enum WatchStreakState {
  /// Running.
  active,

  /// A stream was missed: the streak can still be saved before it expires.
  suspended,

  /// Nothing running.
  none,
}

/// What the channel points panel says about the streak.
typedef WatchStreakCopy = ({String title, String? subtitle});

/// The viewer's watch streak in one channel, as Twitch's own
/// `WatchStreakMilestoneQuery` reports it. Read only: it is shown as Twitch
/// counts it, never computed or advanced here.
class WatchStreak {
  /// Streams watched in a row.
  final int value;

  /// The streak that earns the next bonus, when Twitch says.
  final int? threshold;

  /// The channel points that bonus gives, when Twitch says.
  final int? pointsBonus;

  final WatchStreakState state;

  /// When a suspended streak is lost for good.
  final DateTime? expiresAt;

  /// The milestone was just reached (Twitch offers to share it in chat).
  final bool canShare;

  const WatchStreak({
    required this.value,
    this.threshold,
    this.pointsBonus,
    this.state = WatchStreakState.active,
    this.expiresAt,
    this.canShare = false,
  });

  /// The streak in a `WatchStreakMilestoneQuery` answer, or null when there
  /// is none to show: an error (integrity included), no signed-in viewer, no
  /// streak, or a viewer who opted out of streaks.
  static WatchStreak? tryParse(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final settings = data['channelViewerMilestoneSettings'];
    if (settings is Map && settings['isWatchStreakOptOut'] == true) {
      return null;
    }
    final self = (data['channel'] as Map?)?['self'];
    if (self is! Map) return null;
    final streak = self['watchStreakMilestone'];
    if (streak is! Map) return null;
    final milestone = streak['watchStreakMilestone'];
    if (milestone is! Map) return null;
    final value = _int(milestone['value']);
    if (value == null || value < 0) return null;
    final expiresAt = streak['expiresAt'];
    return WatchStreak(
      value: value,
      threshold: _positive(streak['watchStreakThreshold']),
      pointsBonus: _positive(streak['watchStreakCopoBonus']),
      state: switch (streak['state']) {
        'SUSPENDED' => WatchStreakState.suspended,
        'NONE' => WatchStreakState.none,
        _ => WatchStreakState.active,
      },
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
      canShare: milestone['shareStatus'] == 'CAN_SHARE',
    );
  }

  /// Running streaks (not suspended, at least one stream) by channel id, from
  /// a `BatchGetWatchStreaksQuery` answer; null when Twitch gave none.
  static Map<String, int>? parseBatch(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final list = (body['data'] as Map?)?['batchGetWatchStreaks'];
    if (list is! List) return null;
    return {
      for (final entry in list)
        if (entry is Map &&
            entry['isSuspended'] != true &&
            (entry['channel'] as Map?)?['id'] is String &&
            (_int(entry['value']) ?? 0) > 0)
          (entry['channel'] as Map)['id'] as String: _int(entry['value'])!,
    };
  }

  /// The streak panel's wording, in [l]'s language (the one on screen by
  /// default): [live] says whether the channel is live, which changes how a
  /// suspended streak is saved.
  WatchStreakCopy copy({
    required bool live,
    required String channelName,
    required DateTime now,
    AppLocalizations? l,
  }) {
    final words = l ?? L10n.current;
    if (state == WatchStreakState.suspended) {
      if (live) {
        return (
          title: words.streakSaveTitle,
          subtitle: words.streakSaveLive(count: value),
        );
      }
      final left = expiresAt?.difference(now);
      return (
        title: words.streakExpiringTitle,
        subtitle: left == null || left.isNegative
            ? null
            : words.streakExpiring(
                name: channelName,
                hours: left.inHours,
                minutes: left.inMinutes % 60,
                seconds: left.inSeconds % 60,
              ),
      );
    }
    final next = threshold;
    final bonus = pointsBonus;
    final points = bonus == null
        ? null
        : NumberFormat.decimalPattern(words.localeName).format(bonus);
    return (
      title: words.streakYour(value: value),
      subtitle: next == null || points == null || bonus == null
          ? null
          : next - value == 1
          ? words.streakOneMore(count: bonus, points: points)
          : canShare
          ? words.streakReached(count: bonus, next: next, points: points)
          : words.streakReach(count: bonus, next: next, points: points),
    );
  }

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  static int? _positive(Object? value) {
    final number = _int(value);
    return number != null && number > 0 ? number : null;
  }
}
