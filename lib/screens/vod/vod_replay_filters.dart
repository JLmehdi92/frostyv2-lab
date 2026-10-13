import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/muted_words.dart';

/// Whether a replayed chat message is hidden by the viewer's blocked users or
/// muted words, mirroring live chat: the channel owner still sees blocked
/// users, and words match case-insensitively, either whole or anywhere in the
/// message.
bool isReplayCommentHidden(
  IRCMessage message, {
  required List<String> blockedLogins,
  required List<String> mutedWords,
  required bool matchWholeWord,
  required String channelLogin,
  String? viewerLogin,
}) {
  final user = message.user;
  if (user != null &&
      viewerLogin != channelLogin &&
      blockedLogins.contains(user)) {
    return true;
  }

  final text = message.message;
  if (text == null) return false;
  // The same rule as live chat.
  return isMuted(text, mutedWords, wholeWord: matchWholeWord);
}
