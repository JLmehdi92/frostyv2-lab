import 'package:onset/models/irc.dart';
import 'package:onset/utils.dart';

final _login = RegExp(r'^[a-z0-9_]{1,25}$');

/// The chat line Twitch shows when a moderator times out or bans someone,
/// for a targeted CLEARCHAT; null for a whole-chat clear or an odd target.
///
/// [displayNameOf] gives the name to show for a login (the login itself
/// when it has not chatted).
String? moderationNotice(
  IRCMessage clearChat, {
  required String Function(String login) displayNameOf,
}) {
  final login = clearChat.message?.trim().toLowerCase();
  if (login == null || !_login.hasMatch(login)) return null;
  final name = displayNameOf(login);
  final duration = clearChat.tags['ban-duration'];
  if (duration == null) return '$name has been permanently banned.';
  final seconds = int.tryParse(duration);
  // A duration that cannot be read is still a timeout, not a ban.
  if (seconds == null) return '$name has been timed out.';
  return '$name has been timed out for ${timeoutLength(seconds)}.';
}

/// The notice line chat adds for a targeted CLEARCHAT, or null: none for a
/// whole-chat clear, an odd target, or someone in [hiddenLogins] (blocked
/// people, whose messages are hidden too). [newestFirst] names the target.
///
/// The line keeps Twitch's time (merged chats sort by it) and history mark,
/// and gets an id from the target and time so a shared chat seen from two
/// tabs shows it once.
IRCMessage? moderationNoticeLine(
  IRCMessage clearChat, {
  required Set<String> hiddenLogins,
  required Iterable<IRCMessage> newestFirst,
}) {
  final target = clearChat.message?.trim().toLowerCase();
  if (target == null || hiddenLogins.contains(target)) return null;
  final text = moderationNotice(
    clearChat,
    displayNameOf: (login) => chatNameOf(login, newestFirst),
  );
  if (text == null) return null;
  final notice = IRCMessage.createNotice(message: text);
  final sentAt = clearChat.tags['tmi-sent-ts'];
  if (sentAt != null) notice.tags['tmi-sent-ts'] = sentAt;
  if (clearChat.tags['historical'] == '1') notice.tags['historical'] = '1';
  final targetId = clearChat.tags['target-user-id'];
  if (targetId != null && sentAt != null) {
    notice.tags['id'] = 'clearchat-$targetId-$sentAt';
  }
  return notice;
}

/// [seconds] as Twitch words it: "1 second", "10 minutes", "2 weeks"…
String timeoutLength(int seconds) {
  const units = [
    (604800, 'week'),
    (86400, 'day'),
    (3600, 'hour'),
    (60, 'minute'),
  ];
  for (final (size, unit) in units) {
    if (seconds >= size && seconds % size == 0) {
      return _plural(seconds ~/ size, unit);
    }
  }
  return _plural(seconds < 0 ? 0 : seconds, 'second');
}

String _plural(int count, String unit) =>
    '$count $unit${count == 1 ? '' : 's'}';

/// How chat names [login]: the display name of their latest message in
/// [newestFirst], or the login when they have not chatted.
String chatNameOf(String login, Iterable<IRCMessage> newestFirst) {
  for (final message in newestFirst) {
    if (message.user != login) continue;
    final name = message.tags['display-name'];
    return name == null || name.isEmpty ? login : getReadableName(name, login);
  }
  return login;
}
