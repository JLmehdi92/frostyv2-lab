import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/server_notice.dart';

import '../../../helpers/l10n.dart';

void main() {
  final english = lookupAppLocalizations(en);
  final french = lookupAppLocalizations(fr);

  group('send rejections', () {
    test('every msg_ notice refuses the pending message', () {
      for (final id in [
        'msg_channel_suspended',
        'msg_invalid_reply_parent',
        'msg_banned_email_alias',
        'msg_banned_phone_number_alias',
        'msg_user_has_consequence',
        'msg_channel_has_consequence',
        'msg_unexpected_error',
        'msg_concurrent_channel_limit_reached',
        'msg_warned',
        'msg_slowmode',
        'msg_duplicate',
        'msg_some_future_reason',
      ]) {
        expect(isSendRejection(id), isTrue, reason: id);
      }
    });

    test('command answers and mode changes do not', () {
      for (final id in ['mod_success', 'room_mods', 'slow_on', 'no_help']) {
        expect(isSendRejection(id), isFalse, reason: id);
      }
    });
  });

  group('server notices', () {
    test('a refusal is worded by the app in each language', () {
      expect(
        serverNoticeText(
          'msg_channel_suspended',
          'This channel has been suspended.',
          english,
        ),
        'This channel doesn’t exist or is suspended.',
      );
      expect(
        serverNoticeText(
          'msg_channel_suspended',
          'This channel has been suspended.',
          french,
        ),
        'Cette chaîne n’existe pas ou est suspendue.',
      );
      expect(
        serverNoticeText('msg_invalid_reply_parent', 'x', french),
        'Impossible d’envoyer votre réponse. Il n’est pas possible de répondre à ce message.',
      );
    });

    test('every refusal Twitch can send has its own sentence', () {
      for (final id in [
        'msg_ratelimit',
        'msg_duplicate',
        'msg_subsonly',
        'msg_emoteonly',
        'msg_r9k',
        'msg_followersonly',
        'msg_followersonly_zero',
        'msg_followersonly_followed',
        'msg_verified_email',
        'msg_requires_verified_phone_number',
        'msg_banned_email_alias',
        'msg_banned_phone_number_alias',
        'msg_channel_suspended',
        'msg_suspended',
        'msg_channel_blocked',
        'msg_user_has_consequence',
        'msg_channel_has_consequence',
        'msg_invalid_reply_parent',
        'msg_unexpected_error',
        'msg_bad_characters',
        'msg_rejected_mandatory',
        'msg_concurrent_channel_limit_reached',
        'msg_warned',
        'msg_banned',
      ]) {
        for (final l in [english, french]) {
          final text = serverNoticeText(id, 'twitch words', l);
          expect(text, isNot('twitch words'), reason: '$id ${l.localeName}');
          expect(text, isNotEmpty, reason: id);
        }
      }
    });

    test('a refusal in followers-only mode asks to follow', () {
      for (final id in ['msg_followersonly', 'msg_followersonly_zero']) {
        expect(
          serverNoticeText(id, 'x', english),
          'Couldn’t send your message. This chat is in followers-only mode: '
          'follow the channel to chat.',
          reason: id,
        );
      }
    });

    test('replies to IRC commands Twitch removed keep Twitch’s text', () {
      for (final (id, text) in [
        (
          'mod_success',
          'You have added friend as a moderator of this channel.',
        ),
        ('room_mods', 'The moderators of this channel are: alice, bob.'),
        ('bad_unban_no_ban', 'troll is not banned from this channel.'),
        ('commercial_success', 'Initiating 30 second commercial break.'),
        ('no_help', 'No help available.'),
      ]) {
        expect(serverNoticeText(id, text, french), text, reason: id);
      }
    });

    test('numbers and lists are read from Twitch’s text', () {
      expect(
        serverNoticeText(
          'msg_timedout',
          'You are timed out for 600 more seconds.',
          english,
        ),
        'You’re timed out: you can chat again in 10 minutes.',
      );
      expect(
        serverNoticeText(
          'msg_slowmode',
          'This room is in slow mode and you are sending messages too quickly. You will be able to talk again in 12 seconds.',
          french,
        ),
        'Impossible d’envoyer votre message. Le chat est en mode lent : vous pourrez écrire de nouveau dans 12 secondes.',
      );
      expect(
        serverNoticeText(
          'unrecognized_cmd',
          'Unrecognized command: /dance',
          english,
        ),
        'Unknown command: /⁠dance.',
      );
    });

    test(
      'Twitch’s text stays when its shape is unexpected or the id unknown',
      () {
        expect(
          serverNoticeText('mod_success', 'Something new', french),
          'Something new',
        );
        expect(
          serverNoticeText('msg_timedout', 'No number', french),
          'No number',
        );
        expect(
          serverNoticeText('slow_on', 'This room is now in slow mode.', french),
          'This room is now in slow mode.',
        );
        expect(serverNoticeText(null, 'Hello', french), 'Hello');
      },
    );
  });
}
