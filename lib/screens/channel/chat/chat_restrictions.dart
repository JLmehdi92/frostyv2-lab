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

  /// The input is locked (nothing can be sent until it ends).
  bool get blocksInput => switch (kind) {
    ChatRestrictionKind.banned ||
    ChatRestrictionKind.timedOut ||
    ChatRestrictionKind.slowMode => true,
    _ => false,
  };

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
/// about someone else (or the whole chat).
({bool banned, DateTime? until})? ownClearChat(
  IRCMessage clearChat, {
  required String? ownUserId,
  required DateTime now,
}) {
  final target = clearChat.tags['target-user-id'];
  if (ownUserId == null || target == null || target != ownUserId) return null;
  final seconds = int.tryParse(clearChat.tags['ban-duration'] ?? '');
  if (seconds == null) return (banned: true, until: null);
  return (banned: false, until: now.add(Duration(seconds: seconds)));
}
