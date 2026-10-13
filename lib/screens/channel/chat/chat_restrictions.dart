import 'package:frosty/models/irc.dart';

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

  /// What the banner says; [left] is the time to [until].
  String describe(Duration? left) => switch (kind) {
    ChatRestrictionKind.banned => 'You are permanently banned from this chat',
    ChatRestrictionKind.timedOut =>
      'You are timed out${left == null ? '' : ' · ${formatWait(left)}'}',
    ChatRestrictionKind.slowMode =>
      'Slow mode · you can chat again in ${formatWait(left ?? Duration.zero)}',
    ChatRestrictionKind.emoteOnly => 'Emote-only chat',
    ChatRestrictionKind.subscribersOnly => 'Subscribers-only chat',
    ChatRestrictionKind.followersOnly => switch (minutes) {
      null || 0 => 'Followers-only chat',
      final m => 'Followers-only chat · following for $m+ min',
    },
  };
}

/// Height of the line [ChatRestriction.showsBar] puts above the input.
const kRestrictionBarHeight = 28.0;

/// "4:05", "1:02:03", "12s".
String formatWait(Duration left) {
  final seconds = left.inSeconds < 0 ? 0 : left.inSeconds;
  if (seconds < 60) return '${seconds}s';
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
