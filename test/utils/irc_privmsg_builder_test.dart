import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/irc_privmsg_builder.dart';

void main() {
  test('builds a chat message with emotes, badges and colour', () {
    final message = buildPrivmsgIrcMessage(
      fragments: const [
        (text: 'hi ', emoteId: null),
        (text: 'Kappa', emoteId: '25'),
      ],
      login: 'NightBot',
      displayName: 'Nightbot',
      userId: '19264788',
      color: '#7C7CE1',
      badges: const [(setId: 'moderator', version: '1')],
      id: 'pin-1',
      channelId: '1',
      channelLogin: 'chan',
      sentAt: DateTime.utc(2026, 10, 13),
    );

    expect(message.user, 'nightbot');
    expect(message.message, 'hi Kappa');
    expect(message.tags['display-name'], 'Nightbot');
    expect(message.tags['color'], '#7C7CE1');
    expect(message.tags['emotes'], '25:3-7');
    expect(message.tags['badges'], 'moderator/1');
    expect(message.tags['user-id'], '19264788');
  });

  test('anything that could break the line is dropped', () {
    final message = buildPrivmsgIrcMessage(
      fragments: const [(text: 'a\r\nb', emoteId: 'x;y')],
      login: 'not a login',
      displayName: 'x;y=z',
      color: 'red',
      badges: const [(setId: 'a;b', version: '1')],
      id: 'id;=x',
      channelId: '1',
      channelLogin: '#bad',
      sentAt: DateTime.utc(2026),
    );

    expect(message.message, isNot(contains('\n')));
    expect(message.message, startsWith('a'));
    expect(message.user, 'deleted_user');
    expect(message.tags.containsKey('color'), isFalse);
    expect(message.tags.containsKey('badges'), isFalse);
    expect(message.tags.containsKey('emotes'), isFalse);
    expect(message.tags['id'], 'idx');
  });
}
