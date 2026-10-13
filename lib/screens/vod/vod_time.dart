/// Playback time as shown on the seek bar: `M:SS` under an hour, otherwise
/// `H:MM:SS`.
String formatVodTime(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = total % 3600 ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
}

/// Time in the Twitch `?t=` link format (`1h2m3s`, `5m0s`, `7s`).
String formatVodTimeForShare(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = total % 3600 ~/ 60;
  final seconds = total % 60;
  if (hours > 0) return '${hours}h${minutes}m${seconds}s';
  if (minutes > 0) return '${minutes}m${seconds}s';
  return '${seconds}s';
}

final _hms = RegExp(r'^(?:(\d{1,3})h)?(?:(\d{1,4})m)?(?:(\d{1,6})s)?$');
final _plainSeconds = RegExp(r'^\d{1,7}$');

/// Parses a Twitch `t=` timestamp (`1h2m3s`, `01h02m03s`, `2m3s`, `3s`, `1h`,
/// `5m`) or plain seconds (`90`). Case and surrounding spaces are ignored.
/// Anything else, or more than 999 hours, gives null.
Duration? parseTwitchTimestamp(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return null;
  if (_plainSeconds.hasMatch(value)) {
    return Duration(seconds: int.parse(value));
  }
  final match = _hms.firstMatch(value);
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

/// How long ago [date] was, the way Twitch lists videos ("3 days ago").
String formatTimeAgo(DateTime date, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(date);
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return plural(elapsed.inMinutes, 'minute');
  if (elapsed.inDays < 1) return plural(elapsed.inHours, 'hour');
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return plural(elapsed.inDays, 'day');
  if (elapsed.inDays < 30) return plural(elapsed.inDays ~/ 7, 'week');
  if (elapsed.inDays < 365) return plural(elapsed.inDays ~/ 30, 'month');
  return plural(elapsed.inDays ~/ 365, 'year');
}
