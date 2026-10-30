import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/chat_gif.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/utils/irc_privmsg_builder.dart';

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

  IRCMessage build({
    List<({String text, String? emoteId})> fragments = const [
      (text: 'hi', emoteId: null),
    ],
    Map<String, String> extraTags = const {},
    Map<int, ({String id, String url})> gifs = const {},
  }) => buildPrivmsgIrcMessage(
    fragments: fragments,
    login: 'viewer',
    displayName: 'Viewer',
    id: 'm-1',
    channelId: '1',
    channelLogin: 'chan',
    sentAt: DateTime.utc(2026),
    extraTags: extraTags,
    gifs: gifs,
  );

  test('extra tags: only the allowlisted ones, escaped', () {
    final message = build(
      extraTags: {
        'historical': '1',
        'bits': '100',
        'source-room-id': '42',
        'reply-parent-msg-id': 'parent-1',
        'reply-parent-msg-body': 'hello there; mod=1',
        'reply-parent-display-name': 'Parent',
        'reply-parent-user-login': 'parent',
        'reply-parent-user-id': '7',
        'reply-thread-parent-msg-id': 'root-1',
        'reply-thread-parent-user-login': 'root',
        'reply-thread-parent-display-name': 'Root',
        // Not allowed: these would change who sent it or what it is.
        'id': 'forged',
        'display-name': 'Forged',
        'badges': 'broadcaster/1',
        'mod': '1',
        'msg-id': 'highlighted-message',
        'first-msg': '1',
      },
    );

    expect(message.tags['historical'], '1');
    expect(message.tags['bits'], '100');
    expect(message.tags['source-room-id'], '42');
    expect(message.tags['reply-parent-msg-id'], 'parent-1');
    // Spaces kept, the tag separators dropped: nothing leaks into a tag.
    expect(message.tags['reply-parent-msg-body'], 'hello there mod1');
    expect(message.tags['reply-parent-display-name'], 'Parent');
    expect(message.tags['reply-thread-parent-msg-id'], 'root-1');
    expect(message.tags['id'], 'm-1');
    expect(message.tags['display-name'], 'Viewer');
    expect(message.tags.containsKey('badges'), isFalse);
    expect(message.tags.containsKey('mod'), isFalse);
    expect(message.tags.containsKey('msg-id'), isFalse);
    expect(message.tags.containsKey('first-msg'), isFalse);
    expect(message.message, 'hi');
  });

  test('a GIF fragment becomes a gifs tag, counted in characters', () {
    final message = build(
      fragments: const [
        (text: '\u{1F600} ', emoteId: null),
        (text: 'Party Parrot', emoteId: null),
      ],
      gifs: {
        1: (id: 'g1', url: 'https://media.giphy.com/media/g1/giphy.gif?a=b;c'),
      },
    );

    expect(message.gifParts, hasLength(2));
    final gif = message.gifParts.last.gif!;
    expect(gif.start, 2);
    expect(gif.end, 13);
    expect(gif.id, 'g1');
    // The url survives the tag as sent, `;` and `=` included.
    expect(gif.url, 'https://media.giphy.com/media/g1/giphy.gif?a=b;c');
    expect(gif.isLoadable, isTrue);
    expect(message.gifParts.last.text, 'Party Parrot');
  });

  test('a GIF from a host off the allowlist stays its title', () {
    final message = build(
      fragments: const [(text: 'Party Parrot', emoteId: null)],
      gifs: {0: (id: 'g1', url: 'https://evil.example/x.gif')},
    );

    expect(message.gifParts, isEmpty);
    expect(message.tags.containsKey('gifs'), isFalse);
    expect(message.message, 'Party Parrot');
  });

  test('a GIF entry that could break the tag is dropped', () {
    for (final gif in [
      (id: 'a|b', url: 'https://media.giphy.com/a.gif'),
      (id: 'a,b', url: 'https://media.giphy.com/a.gif'),
      (id: 'g', url: 'https://media.giphy.com/a b.gif'),
      (id: 'g', url: 'https://media.giphy.com/a,|b.gif'),
      (id: 'g', url: 'http://media.giphy.com/a.gif'),
    ]) {
      final message = build(
        fragments: const [(text: 'gif', emoteId: null)],
        gifs: {0: gif},
      );
      expect(message.tags.containsKey('gifs'), isFalse, reason: '$gif');
      expect(message.message, 'gif');
    }
  });

  test('control characters cannot make a /me line or a second line', () {
    final message = build(
      fragments: const [
        (text: '\x01ACTION waves\x01', emoteId: null),
        (
          text: '\r\n@badges=broadcaster/1 :x!x@x PRIVMSG #chan :pwn',
          emoteId: null,
        ),
      ],
    );

    expect(message.action, isFalse);
    expect(message.command, Command.privateMessage);
    expect(message.message, isNot(contains('\x01')));
    expect(message.message, startsWith('ACTION waves'));
    expect(message.tags.containsKey('badges'), isFalse);
    expect(message.user, 'viewer');
  });

  test('at most GifMessagePart.maxGifs GIFs go in the tag', () {
    final message = build(
      fragments: [for (var i = 0; i < 8; i++) (text: 'gif$i ', emoteId: null)],
      gifs: {
        for (var i = 0; i < 8; i++)
          i: (id: 'g$i', url: 'https://media.giphy.com/media/g$i/giphy.gif'),
      },
    );
    expect(message.tags['gifs']!.split(','), hasLength(GifMessagePart.maxGifs));
  });

  test('a moderator badge gives the mod tag, as live IRC has it', () {
    IRCMessage withBadges(List<({String setId, String version})> badges) =>
        buildPrivmsgIrcMessage(
          fragments: const [(text: 'hi', emoteId: null)],
          login: 'viewer',
          displayName: 'Viewer',
          id: 'm-1',
          channelId: '1',
          channelLogin: 'chan',
          sentAt: DateTime.utc(2026),
          badges: badges,
        );

    expect(
      withBadges(const [(setId: 'moderator', version: '1')]).tags['mod'],
      '1',
    );
    expect(
      withBadges(const [(setId: 'subscriber', version: '1')]).tags['mod'],
      isNull,
    );
    // Not settable from outside.
    expect(build(extraTags: const {'mod': '1'}).tags['mod'], isNull);
  });

  test('action: a /me line, still safe', () {
    final message = buildPrivmsgIrcMessage(
      fragments: const [
        (text: 'waves ', emoteId: null),
        (text: 'Kappa', emoteId: '25'),
        (text: ' \x01ACTION x\x01', emoteId: null),
      ],
      login: 'viewer',
      displayName: 'Viewer',
      id: 'm-1',
      channelId: '1',
      channelLogin: 'chan',
      sentAt: DateTime.utc(2026),
      action: true,
    );
    expect(message.action, isTrue);
    expect(message.message, 'waves Kappa ACTION x');
    expect(message.tags['emotes'], '25:6-10');
    expect(message.localEmotes!['Kappa'], isNotNull);
  });
}
