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
  'msg_followersonly': 'followersOnly',
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
  'no_help': 'noHelp',
  'no_permission': 'noPermission',
  'no_mods': 'noMods',
  'bad_ban_broadcaster': 'banBroadcaster',
  'bad_mod_max_mods_reached': 'maxMods',
  'bad_mod_invalid': 'modInvalid',
};

const _login = r'([A-Za-z0-9_]{1,25})';

final _namedNotices = {
  'mod_success': RegExp('You have added $_login as a moderator'),
  'unmod_success': RegExp('You have removed $_login as a moderator'),
  'bad_mod_mod': RegExp('^$_login is already a moderator'),
  'bad_unmod_mod': RegExp('^$_login is not a moderator'),
  'bad_mod_banned': RegExp('^$_login is banned in this channel'),
  'bad_unban_no_ban': RegExp('^$_login is not banned'),
  'timeout_no_timeout': RegExp('^$_login is not timed out'),
  'already_banned': RegExp('^$_login is already banned'),
  'bad_ban_mod': RegExp('You cannot ban moderator $_login'),
  'bad_timeout_mod': RegExp('You cannot timeout moderator $_login'),
  'invalid_user': RegExp('Invalid username: $_login'),
};

const kNamedServerNotices = {
  'mod_success': 'modAdded',
  'unmod_success': 'modRemoved',
  'bad_mod_mod': 'alreadyMod',
  'bad_unmod_mod': 'notMod',
  'bad_mod_banned': 'modBanned',
  'bad_unban_no_ban': 'notBanned',
  'timeout_no_timeout': 'notTimedOut',
  'already_banned': 'alreadyBanned',
  'bad_ban_mod': 'banMod',
  'bad_timeout_mod': 'timeoutMod',
  'invalid_user': 'invalidUser',
};

final _seconds = RegExp(r'(\d+) (?:more )?seconds?');
final _roomMods = RegExp(r'moderators of this channel are: ([A-Za-z0-9_, ]+)');
final _unrecognized = RegExp(r'Unrecognized command: /(\S+)');
final _commercial = RegExp(r'Initiating (\d+) second commercial');

String serverNoticeText(String? msgId, String twitchText, AppLocalizations l) {
  if (msgId == null) return twitchText;
  return _localized(msgId, twitchText, l) ?? twitchText;
}

String? _localized(String msgId, String text, AppLocalizations l) {
  if (kPlainServerNotices[msgId] case final kind?) {
    return l.chatServerNotice(notice: kind);
  }
  if (_namedNotices[msgId] case final pattern?) {
    final name = pattern.firstMatch(text)?[1];
    if (name == null) return null;
    return l.chatServerNoticeName(
      notice: kNamedServerNotices[msgId]!,
      name: name,
    );
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
    case 'room_mods':
      final names = _roomMods.firstMatch(text)?[1]?.trim();
      if (names == null || names.isEmpty) return null;
      return l.chatServerNoticeMods(names: names);
    case 'unrecognized_cmd':
      final command = _unrecognized.firstMatch(text)?[1];
      if (command == null) return null;
      return l.chatServerNoticeUnknownCommand(
        command: commandInChatLine(command),
      );
    case 'commercial_success':
      final seconds = int.tryParse(_commercial.firstMatch(text)?[1] ?? '');
      if (seconds == null) return null;
      return l.chatServerNoticeCommercial(seconds: seconds);
  }
  return null;
}

int? _secondsIn(String text) =>
    int.tryParse(_seconds.firstMatch(text)?[1] ?? '');
