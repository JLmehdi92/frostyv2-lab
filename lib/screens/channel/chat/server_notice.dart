import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';

bool isSendRejection(String msgId) => msgId.startsWith('msg_');

const kPlainServerNotices = {
  'msg_ratelimit': 'rateLimit',
  'msg_duplicate': 'duplicate',
  'msg_subsonly': 'subsOnly',
  'msg_emoteonly': 'emoteOnly',
  'msg_r9k': 'uniqueChat',
  'msg_followersonly': 'followRequired',
  'msg_followersonly_zero': 'followRequired',
  'msg_followersonly_followed': 'followedTooRecently',
  'msg_verified_email': 'verifiedEmail',
  'msg_requires_verified_phone_number': 'verifiedPhone',
  'msg_banned_email_alias': 'emailAliasBanned',
  'msg_banned_phone_number_alias': 'phoneAliasBanned',
  'msg_channel_suspended': 'channelSuspended',
  'msg_suspended': 'accountSuspended',
  'msg_channel_blocked': 'channelBlocked',
  'msg_user_has_consequence': 'userRestricted',
  'msg_channel_has_consequence': 'channelRestricted',
  'msg_invalid_reply_parent': 'invalidReply',
  'msg_unexpected_error': 'unexpected',
  'msg_bad_characters': 'badCharacters',
  'msg_rejected_mandatory': 'rejectedBySettings',
  'msg_concurrent_channel_limit_reached': 'tooManyChats',
  'msg_warned': 'warned',
  'msg_banned': 'banned',
  'followers_on_zero': 'followersOnNow',
  'no_permission': 'noPermission',
};

final _seconds = RegExp(r'(\d+) (?:more )?seconds?');
final _unrecognized = RegExp(r'Unrecognized command: /(\S+)');

String serverNoticeText(String? msgId, String twitchText, AppLocalizations l) {
  if (msgId == null) return twitchText;
  return _localized(msgId, twitchText, l) ?? twitchText;
}

String? _localized(String msgId, String text, AppLocalizations l) {
  if (kPlainServerNotices[msgId] case final kind?) {
    return l.chatServerNotice(notice: kind);
  }
  switch (msgId) {
    case 'msg_timedout':
      final seconds = _secondsIn(text);
      if (seconds == null) return null;
      return l.chatServerNoticeTimedOut(wait: timeoutLength(seconds, l));
    case 'msg_slowmode':
      final seconds = _secondsIn(text);
      if (seconds == null) return null;
      return l.chatServerNoticeSlowMode(wait: timeoutLength(seconds, l));
    case 'unrecognized_cmd':
      final command = _unrecognized.firstMatch(text)?[1];
      if (command == null) return null;
      return l.chatServerNoticeUnknownCommand(
        command: commandInChatLine(command),
      );
  }
  return null;
}

int? _secondsIn(String text) =>
    int.tryParse(_seconds.firstMatch(text)?[1] ?? '');
