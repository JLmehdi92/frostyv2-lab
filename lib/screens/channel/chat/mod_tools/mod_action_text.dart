import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';

String modActionKey(String action) => action.replaceAllMapped(
  RegExp(r'_([a-z])'),
  (match) => match[1]!.toUpperCase(),
);

String modActionLine(AppLocalizations l, ModActionEntry entry) {
  final length = entry.timeoutLength;
  final duration = length == null || length.isNegative
      ? ''
      : timeoutLength(roundedTimeoutSeconds(length), l);
  final key = modActionKey(entry.action);
  final line = l.chatModAction(
    action: key == 'timeout' && duration.isEmpty ? 'timeoutUnknown' : key,
    moderator: entry.moderatorName,
    user: entry.userName ?? '',
    duration: duration,
  );
  if (entry.reason.isEmpty) return line;
  return l.chatModActionWithReason(line: line, reason: entry.reason);
}

int roundedTimeoutSeconds(Duration length) {
  final seconds = length.inMilliseconds / 1000;
  final rounded = seconds < 60 ? seconds.round() : (seconds / 60).round() * 60;
  return rounded.clamp(1, 1209600);
}
