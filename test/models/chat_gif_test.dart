import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/chat_gif.dart';

const _url =
    'https://media4.giphy.com/media/joSNxeswxuc74Juo8X/giphy.gif?cid=095d7a5dzizsiwgabonagkmigggv8v1spfai91ac3x0dsiy0&ep=v1_gifs_trending&rid=giphy.gif&ct=g';

void main() {
  group('ChatGif.parseTag', () {
    test('reads one entry and keeps its url untouched', () {
      final gifs = ChatGif.parseTag('0-33|joSNxeswxuc74Juo8X|$_url');

      expect(gifs, [
        const ChatGif(start: 0, end: 33, id: 'joSNxeswxuc74Juo8X', url: _url),
      ]);
    });

    test('reads several entries, sorted by their start', () {
      final gifs = ChatGif.parseTag(
        '10-12|b|https://x.test/b.gif,0-3|a|https://x.test/a.gif',
      );

      expect(gifs.map((gif) => gif.id), ['a', 'b']);
      expect(gifs.first.start, 0);
      expect(gifs.first.end, 3);
    });

    test('skips malformed entries like Twitch and keeps the others', () {
      final gifs = ChatGif.parseTag(
        [
          '0-3|only-two-fields',
          '0-3|a|https://x.test/a.gif|extra',
          '0-3||https://x.test/empty-id.gif',
          '0-3|empty-url|',
          '0|no-dash|https://x.test/c.gif',
          '0-1-2|two-dashes|https://x.test/d.gif',
          'a-3|not-a-number|https://x.test/e.gif',
          '',
          '4-8|good|https://x.test/good.gif',
        ].join(','),
      );

      expect(gifs, [
        const ChatGif(
          start: 4,
          end: 8,
          id: 'good',
          url: 'https://x.test/good.gif',
        ),
      ]);
    });

    test('no tag or an empty one has no GIF', () {
      expect(ChatGif.parseTag(null), isEmpty);
      expect(ChatGif.parseTag(''), isEmpty);
    });
  });

  group('GifMessagePart.split', () {
    const gif = ChatGif(
      start: 6,
      end: 10,
      id: 'id',
      url: 'https://x.test/g.gif',
    );

    test('cuts the message around the GIF, the range being its title', () {
      final parts = GifMessagePart.split('hello [YAY] there', [gif]);

      expect(parts.map((part) => part.text), ['hello ', '[YAY]', ' there']);
      expect(parts.map((part) => part.gif), [null, gif, null]);
    });

    test('a message that is only the GIF is one part', () {
      const whole = ChatGif(
        start: 0,
        end: 4,
        id: 'id',
        url: 'https://x.test/g.gif',
      );
      final parts = GifMessagePart.split('[YAY]', [whole]);

      expect(parts, hasLength(1));
      expect(parts.single.text, '[YAY]');
      expect(parts.single.gif, whole);
    });

    test('drops a range that does not fit the message', () {
      for (final bad in const [
        ChatGif(start: 0, end: 50, id: 'past-end', url: 'https://x.test/a'),
        ChatGif(start: 4, end: 2, id: 'reversed', url: 'https://x.test/a'),
        ChatGif(start: -1, end: 2, id: 'negative', url: 'https://x.test/a'),
      ]) {
        expect(GifMessagePart.split('[YAY]', [bad]), isEmpty, reason: bad.id);
      }
    });

    test('drops a GIF that starts inside the previous one', () {
      const first = ChatGif(start: 0, end: 4, id: 'a', url: 'https://x.test/a');
      const overlap = ChatGif(
        start: 3,
        end: 8,
        id: 'b',
        url: 'https://x.test/b',
      );
      const after = ChatGif(start: 6, end: 8, id: 'c', url: 'https://x.test/c');

      final parts = GifMessagePart.split('[YAY] [W]', [first, overlap, after]);

      expect(parts.map((part) => part.gif?.id), ['a', null, 'c']);
      expect(parts.map((part) => part.text), ['[YAY]', ' ', '[W]']);
    });

    test('counts positions in characters, like the emotes tag', () {
      // The emoji is one character (two UTF-16 units): the GIF is 2-6.
      const gif = ChatGif(start: 2, end: 6, id: 'id', url: 'https://x.test/g');

      final parts = GifMessagePart.split('😀 [YAY]', [gif]);

      expect(parts.map((part) => part.text), ['😀 ', '[YAY]']);
    });

    test('an emoji in the title counts as one position', () {
      const gif = ChatGif(start: 0, end: 4, id: 'id', url: 'https://x.test/g');

      final parts = GifMessagePart.split('[Y😀Y]', [gif]);

      expect(parts.single.text, '[Y😀Y]');
    });

    test(
      'reads UTF-16 units, as the Twitch app does, when that alone fits',
      () {
        // 0-5 overruns the 5 characters but fits the 6 UTF-16 units.
        const gif = ChatGif(
          start: 0,
          end: 5,
          id: 'id',
          url: 'https://x.test/g',
        );

        final parts = GifMessagePart.split('[Y😀Y]', [gif]);

        expect(parts.single.text, '[Y😀Y]');
      },
    );

    test('never cuts an emoji in two', () {
      // 3-6 overruns the 6 characters; in UTF-16 units it would start in the
      // middle of the second emoji.
      const gif = ChatGif(start: 3, end: 6, id: 'id', url: 'https://x.test/g');

      expect(GifMessagePart.split('😀😀[Y]', [gif]), isEmpty);
    });

    test('no GIF gives no part', () {
      expect(GifMessagePart.split('hello', const []), isEmpty);
    });
  });

  group('ChatGif.isLoadable', () {
    test('only an https url with a host is loaded', () {
      ChatGif gif(String url) => ChatGif(start: 0, end: 1, id: 'id', url: url);

      expect(gif(_url).isLoadable, isTrue);
      expect(gif('HTTPS://media.giphy.com/a.gif').isLoadable, isTrue);
      expect(gif('http://media.giphy.com/a.gif').isLoadable, isFalse);
      expect(gif('file:///data/a.gif').isLoadable, isFalse);
      expect(gif('javascript:alert(1)').isLoadable, isFalse);
      expect(gif('https:///no-host.gif').isLoadable, isFalse);
      expect(gif('not a url').isLoadable, isFalse);
    });
  });
}
