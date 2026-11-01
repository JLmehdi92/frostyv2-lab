import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';

/// Why the viewer cannot chat right now, or what limits their messages.
enum ChatRestrictionKind {
  banned,
  timedOut,
  slowMode,
  emoteOnly,
  subscribersOnly,
  followersOnly,
}

/// One line above the chat input, like the official app's mode banners.
class ChatRestriction {
  const ChatRestriction(this.kind, {this.until, this.minutes});

  final ChatRestrictionKind kind;

  /// When it ends (timeout, slow-mode wait); a countdown shows until then.
  final DateTime? until;

  /// The followers-only follow age, in minutes.
  final int? minutes;

  /// The input is locked (nothing can be sent until it ends). A ban does
  /// not lock it: Twitch says nothing on an unban, so a send is how the
  /// viewer finds out (a refused one bans again).
  bool get blocksInput => switch (kind) {
    ChatRestrictionKind.timedOut || ChatRestrictionKind.slowMode => true,
    _ => false,
  };

  /// Said on its own line above the input (the rest goes in its
  /// placeholder).
  bool get showsBar => blocksInput || kind == ChatRestrictionKind.banned;

  /// What the banner says, in [l]'s language (the one on screen by
  /// default); [left] is the time to [until].
  String describe(Duration? left, [AppLocalizations? l]) =>
      _describe(left, l ?? L10n.current);

  String _describe(Duration? left, AppLocalizations l) => switch (kind) {
    ChatRestrictionKind.banned => l.chatRestrictionBanned,
    ChatRestrictionKind.timedOut =>
      left == null
          ? l.chatRestrictionTimedOut
          : l.chatRestrictionTimedOutFor(wait: formatWait(left, l)),
    ChatRestrictionKind.slowMode => l.chatRestrictionSlow(
      wait: formatWait(left ?? Duration.zero, l),
    ),
    ChatRestrictionKind.emoteOnly => l.chatRestrictionEmoteOnly,
    ChatRestrictionKind.subscribersOnly => l.chatRestrictionSubscribersOnly,
    ChatRestrictionKind.followersOnly => switch (minutes) {
      null || 0 => l.chatRestrictionFollowersOnly,
      final m => l.chatRestrictionFollowersFor(
        duration: followAgeShort(Duration(minutes: m), l),
      ),
    },
  };
}

/// A followers-only follow [age] for the one-line input, short so it stays
/// in sight on a phone at large text, in [l]'s language: minutes and hours
/// in short units ("10m", « 10 min », "3h", « 3 h »), longer ages in whole
/// days or months of 30 days ("7 days", « 7 jours », "3 months").
String followAgeShort(Duration age, AppLocalizations l) {
  final minutes = age.inMinutes;
  if (minutes < 60) return l.chatShortMinutes(minutes: minutes);
  if (minutes < 1440 || minutes % 1440 != 0) {
    return minutes % 60 == 0
        ? l.chatShortHours(hours: minutes ~/ 60)
        : l.chatShortHoursMinutes(hours: minutes ~/ 60, minutes: minutes % 60);
  }
  final days = minutes ~/ 1440;
  return days % 30 == 0
      ? l.chatDurationMonths(count: days ~/ 30)
      : l.chatDurationDays(count: days);
}

/// Height of the line [ChatRestriction.showsBar] puts above the input.
const kRestrictionBarHeight = 28.0;

/// "4:05", "1:02:03", "12s" (« 12 s » in French), in [l]'s language (the
/// one on screen by default).
String formatWait(Duration left, [AppLocalizations? l]) {
  final seconds = left.inSeconds < 0 ? 0 : left.inSeconds;
  if (seconds < 60) {
    return (l ?? L10n.current).chatShortSeconds(seconds: seconds);
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// The restriction that matters most for the viewer now, or null.
///
/// [privileged]: the broadcaster, moderators and VIPs (no slow mode, no
/// room modes). A ban or timeout comes first, then the slow-mode wait,
/// then the room modes.
ChatRestriction? chatRestriction({
  required ROOMSTATE room,
  required bool privileged,
  required bool subscriber,
  required DateTime now,
  bool banned = false,
  DateTime? timedOutUntil,
  DateTime? lastSentAt,
}) {
  if (banned) return const ChatRestriction(ChatRestrictionKind.banned);
  if (timedOutUntil != null && timedOutUntil.isAfter(now)) {
    return ChatRestriction(ChatRestrictionKind.timedOut, until: timedOutUntil);
  }
  if (privileged) return null;
  final slow = int.tryParse(room.slowMode) ?? 0;
  if (slow > 0 && lastSentAt != null) {
    final until = lastSentAt.add(Duration(seconds: slow));
    if (until.isAfter(now)) {
      return ChatRestriction(ChatRestrictionKind.slowMode, until: until);
    }
  }
  if (room.emoteOnly == '1') {
    return const ChatRestriction(ChatRestrictionKind.emoteOnly);
  }
  if (room.subMode == '1' && !subscriber) {
    return const ChatRestriction(ChatRestrictionKind.subscribersOnly);
  }
  final followers = int.tryParse(room.followersOnly) ?? -1;
  if (followers >= 0) {
    return ChatRestriction(
      ChatRestrictionKind.followersOnly,
      minutes: followers,
    );
  }
  return null;
}

/// The viewer's own ban or timeout from a CLEARCHAT, or null when it is
/// about someone else (or the whole chat), replayed history, or already
/// over. A timeout counts from when Twitch sent it (`tmi-sent-ts`), so a
/// delayed chat does not lengthen it.
({bool banned, DateTime? until})? ownClearChat(
  IRCMessage clearChat, {
  required String? ownUserId,
  required DateTime now,
}) {
  final target = clearChat.tags['target-user-id'];
  if (ownUserId == null || target == null || target != ownUserId) return null;
  if (clearChat.tags['historical'] == '1') return null;
  final seconds = int.tryParse(clearChat.tags['ban-duration'] ?? '');
  if (seconds == null) return (banned: true, until: null);
  final sentMs = int.tryParse(clearChat.tags['tmi-sent-ts'] ?? '');
  final sent = sentMs == null
      ? now
      : DateTime.fromMillisecondsSinceEpoch(sentMs, isUtc: true);
  // A sent time in the future (clock skew) counts from now.
  final from = sent.isAfter(now) ? now : sent;
  final until = from.add(Duration(seconds: seconds));
  return until.isAfter(now) ? (banned: false, until: until) : null;
}
