import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';

import '../fixtures/irc_messages.dart';

/// A PRIVMSG from `viewer` with [tags] (already escaped) and [text].
String _line(String tags, String text) =>
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=gif-1;room-id=12345;user-id=55555;$tags '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :$text';

void main() {
  group('the gifs tag', () {
    test('the official example gives one GIF with its exact url', () {
      final msg = IRCMessage.fromString(gifMessage);

      expect(msg.tags['gifs'], '0-33|joSNxeswxuc74Juo8X|$gifMessageUrl');
      expect(msg.message, '[Y A Y Yes GIF by Djemilah Birnie]');
      expect(msg.gifParts, hasLength(1));
      final part = msg.gifParts.single;
      expect(part.text, '[Y A Y Yes GIF by Djemilah Birnie]');
      expect(part.gif!.id, 'joSNxeswxuc74Juo8X');
      expect(part.gif!.url, gifMessageUrl);
      expect(part.gif!.isLoadable, isTrue);
    });

    test('a GIF in the middle of text keeps the text around it', () {
      final msg = IRCMessage.fromString(
        _line('gifs=5-9|id|https://x.test/g.gif', 'look [YAY] wow'),
      );

      expect(msg.gifParts.map((part) => part.text), ['look ', '[YAY]', ' wow']);
      expect(msg.gifParts.map((part) => part.gif?.id), [null, 'id', null]);
      // Copy, search and mentions still see the whole text.
      expect(msg.message, 'look [YAY] wow');
      expect(msg.split, ['look', '[YAY]', 'wow']);
    });

    test('several GIFs are all kept, in order', () {
      final msg = IRCMessage.fromString(
        _line(
          'gifs=6-8|b|https://x.test/b.gif,0-4|a|https://x.test/a.gif',
          '[YAY] [W]',
        ),
      );

      expect(msg.gifParts.map((part) => part.gif?.id), ['a', null, 'b']);
    });

    test('an emoji before the GIF counts as two positions', () {
      final msg = IRCMessage.fromString(
        _line('gifs=3-7|id|https://x.test/g.gif', '😀 [YAY]'),
      );

      expect(msg.gifParts.map((part) => part.text), ['😀 ', '[YAY]']);
    });

    test('a /me GIF counts from after the ACTION prefix', () {
      final msg = IRCMessage.fromString(
        _line('gifs=0-4|id|https://x.test/g.gif', '\x01ACTION [YAY]\x01'),
      );

      expect(msg.action, isTrue);
      expect(msg.gifParts.single.text, '[YAY]');
    });

    test('malformed entries and ranges outside the text are ignored', () {
      final msg = IRCMessage.fromString(
        _line(
          'gifs=0-4|only-two,0-4||https://x.test/a.gif,0-99|id|https://x.test/b.gif',
          '[YAY]',
        ),
      );

      expect(msg.gifParts, isEmpty);
      expect(msg.message, '[YAY]');
    });

    test('IRCv3 escapes in the value are undone', () {
      final msg = IRCMessage.fromString(
        _line(r'gifs=0-4|id|https://x.test/a\:b\\c.gif', '[YAY]'),
      );

      expect(msg.gifParts.single.gif!.url, r'https://x.test/a;b\c.gif');
    });

    test('an http url is kept but not loadable', () {
      final msg = IRCMessage.fromString(
        _line('gifs=0-4|id|http://x.test/g.gif', '[YAY]'),
      );

      expect(msg.gifParts.single.gif!.isLoadable, isFalse);
    });

    test('a message without the tag has no GIF part', () {
      expect(IRCMessage.fromString(basicPrivmsg).gifParts, isEmpty);
      expect(IRCMessage.fromString(replyMessage).gifParts, isEmpty);
    });
  });
}
