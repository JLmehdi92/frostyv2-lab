import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/utils/common_utils.dart';

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
  // A line put in the chat: worded in the language on screen now.
  final l = L10n.current;
  final duration = clearChat.tags['ban-duration'];
  if (duration == null) return l.chatNoticeBanned(name: name);
  final seconds = int.tryParse(duration);
  // A duration that cannot be read is still a timeout, not a ban.
  if (seconds == null) return l.chatNoticeTimedOut(name: name);
  return l.chatNoticeTimedOutFor(
    name: name,
    duration: timeoutLength(seconds, l),
  );
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

IRCMessage? ownDeletedMessageNotice(
  IRCMessage clearMessage, {
  required String? ownLogin,
}) {
  final login = clearMessage.tags['login'];
  final text = clearMessage.message;
  if (ownLogin == null ||
      login == null ||
      login.toLowerCase() != ownLogin.toLowerCase() ||
      clearMessage.tags['historical'] == '1' ||
      text == null ||
      text.isEmpty) {
    return null;
  }
  final notice = IRCMessage.createNotice(
    message: L10n.current.chatNoticeOwnMessageDeleted(message: text),
  );
  if (clearMessage.tags['tmi-sent-ts'] case final sentAt?) {
    notice.tags['tmi-sent-ts'] = sentAt;
  }
  if (clearMessage.tags['target-msg-id'] case final targetId?) {
    notice.tags['id'] = 'clearmsg-$targetId';
  }
  return notice;
}

/// [seconds] as Twitch words it, in [l]'s language (the one on screen by
/// default): "1 second", "10 minutes", "2 weeks"…
String timeoutLength(int seconds, [AppLocalizations? l]) {
  final words = l ?? L10n.current;
  final units = <(int, String Function({required int count}))>[
    (604800, words.chatDurationWeeks),
    (86400, words.chatDurationDays),
    (3600, words.chatDurationHours),
    (60, words.chatDurationMinutes),
  ];
  for (final (size, unit) in units) {
    if (seconds >= size && seconds % size == 0) {
      return unit(count: seconds ~/ size);
    }
  }
  return words.chatDurationSeconds(count: seconds < 0 ? 0 : seconds);
}

/// A followers-only follow [age] as Twitch words it, in [l]'s language
/// (the one on screen by default): whole months of 30 days as months ("1
/// month", "3 months"), else like a timeout ("10 minutes", "1 week").
String followAgeLength(Duration age, [AppLocalizations? l]) {
  final words = l ?? L10n.current;
  final days = age.inDays;
  if (days >= 30 && days % 30 == 0 && age.inSeconds % 86400 == 0) {
    return words.chatDurationMonths(count: days ~/ 30);
  }
  return timeoutLength(age.inSeconds, words);
}

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

/// The header above the messages of someone timed out for [seconds], in
/// [l]'s language, the length worded like the timeout notices
/// ([timeoutLength]: "Timed out for 10 minutes", « Exclusion temporaire
/// (10 minutes) »).
String timedOutLabel(int seconds, AppLocalizations l) =>
    l.chatTimedOutForLength(duration: timeoutLength(seconds, l));
