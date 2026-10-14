import 'package:frosty/models/irc.dart';
import 'package:frosty/utils.dart';

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
  final seconds = int.tryParse(clearChat.tags['ban-duration'] ?? '');
  if (seconds == null) return '$name has been permanently banned.';
  return '$name has been timed out for ${timeoutLength(seconds)}.';
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
