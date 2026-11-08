import 'package:onset/l10n/l10n.dart';

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
    final seconds = int.parse(value);
    return seconds > 999 * 3600 ? null : Duration(seconds: seconds);
  }
  final match = _hms.firstMatch(value);
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

final _clock = RegExp(r'^(?:(\d{1,3}):)?(\d{1,2}):(\d{2})$');

Duration? parseGoToTime(String raw) {
  final value = raw.trim();
  final match = _clock.firstMatch(value);
  if (match == null) return parseTwitchTimestamp(value);
  final hours = int.parse(match.group(1) ?? '0');
  final minutes = int.parse(match.group(2)!);
  final seconds = int.parse(match.group(3)!);
  if (seconds > 59 || (match.group(1) != null && minutes > 59)) return null;
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

/// How long ago [date] was, the way Twitch lists videos ("3 days ago"), in
/// [l]'s language. Starts with a capital: [timeAgoInText] for one inside a
/// sentence.
String formatTimeAgo(DateTime date, AppLocalizations l, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(date);
  if (elapsed.inMinutes < 1) return l.timeAgoJustNow;
  if (elapsed.inHours < 1) return l.timeAgoMinutes(count: elapsed.inMinutes);
  if (elapsed.inDays < 1) return l.timeAgoHours(count: elapsed.inHours);
  if (elapsed.inDays == 1) return l.timeAgoYesterday;
  if (elapsed.inDays < 7) return l.timeAgoDays(count: elapsed.inDays);
  if (elapsed.inDays < 30) return l.timeAgoWeeks(count: elapsed.inDays ~/ 7);
  if (elapsed.inDays < 365) {
    return l.timeAgoMonths(count: elapsed.inDays ~/ 30);
  }
  return l.timeAgoYears(count: elapsed.inDays ~/ 365);
}

/// [formatTimeAgo] inside a sentence ("Last live 3 days ago"): its first
/// letter in lower case ("just now", « il y a 3 jours »).
String timeAgoInText(DateTime date, AppLocalizations l, {DateTime? now}) {
  final text = formatTimeAgo(date, l, now: now);
  return text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}
