import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/moderation_notice.dart';

import '../../../fixtures/irc_messages.dart';

IRCMessage clear(String target, {String? duration}) => IRCMessage.fromString(
  '@${duration == null ? '' : 'ban-duration=$duration;'}room-id=1;'
  'tmi-sent-ts=1700000000000 :tmi.twitch.tv CLEARCHAT #channel :$target',
);

IRCMessage said(String login, String displayName) => IRCMessage.fromString(
  '@display-name=$displayName;id=x;tmi-sent-ts=1 '
  ':$login!$login@$login.tmi.twitch.tv PRIVMSG #channel :hi',
);

void main() {
  String notice(IRCMessage message) =>
      moderationNotice(message, displayNameOf: (login) => login)!;

  test('a timeout says for how long, like Twitch', () {
    expect(
      notice(IRCMessage.fromString(clearChatUser)),
      'banneduser has been timed out for 10 minutes.',
    );
    expect(
      notice(clear('a', duration: '1')),
      'a has been timed out for 1 second.',
    );
    expect(
      notice(clear('a', duration: '90')),
      'a has been timed out for 90 seconds.',
    );
    expect(
      notice(clear('a', duration: '86400')),
      'a has been timed out for 1 day.',
    );
    expect(
      notice(clear('a', duration: '1209600')),
      'a has been timed out for 2 weeks.',
    );
  });

  test('a ban is permanent', () {
    expect(notice(clear('a')), 'a has been permanently banned.');
  });

  test('a whole-chat clear or an odd target has no line', () {
    String none(String login) => login;
    expect(
      moderationNotice(
        IRCMessage.fromString(clearChatAll),
        displayNameOf: none,
      ),
      isNull,
    );
    expect(moderationNotice(clear('a/b'), displayNameOf: none), isNull);
  });

  test('the name is the one shown in chat', () {
    expect(
      moderationNotice(
        clear('xqc', duration: '60'),
        displayNameOf: (login) =>
            chatNameOf(login, [said('other', 'Other'), said('xqc', 'xQc')]),
      ),
      'xQc has been timed out for 1 minute.',
    );
    expect(chatNameOf('nobody', [said('xqc', 'xQc')]), 'nobody');
    // The newest message wins.
    expect(chatNameOf('xqc', [said('xqc', 'XQC'), said('xqc', 'xQc')]), 'XQC');
  });

  test('lengths', () {
    expect(timeoutLength(0), '0 seconds');
    expect(timeoutLength(-5), '0 seconds');
    expect(timeoutLength(120), '2 minutes');
    expect(timeoutLength(3600), '1 hour');
    expect(timeoutLength(3660), '61 minutes');
  });
}
