import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/chat_filters.dart';

const _all = ChatFilterSettings(
  enabled: true,
  discrimination: true,
  sexual: true,
  harassment: true,
  profanity: true,
);

/// The masked text as shown: each hidden unit as `*`.
String? _shown(String text, String tag, [ChatFilterSettings s = _all]) {
  final masked = maskFilteredText(text, parseAutoModFlags(tag), s);
  return masked?.text.replaceAll(masked.mark, '*');
}

void main() {
  group('the flags tag', () {
    test("reads each range's categories and levels", () {
      final flags = parseAutoModFlags('18-21:A.7/I.6/P.7,0-3:S.3');

      expect(flags, hasLength(2));
      final first = flags.first;
      expect((first.start, first.end), (18, 21));
      expect(
        (first.aggressive, first.identity, first.profanity, first.sexual),
        (7, 6, 7, 0),
      );
      expect(flags.last.sexual, 3);
    });

    test('skips what cannot be read and reads nothing from nothing', () {
      expect(parseAutoModFlags(null), isEmpty);
      expect(parseAutoModFlags(''), isEmpty);
      expect(parseAutoModFlags('x,1:P.3,a-b:P.3,1-2'), isEmpty);
      // A level that cannot be read is no level; the range still counts.
      final flags = parseAutoModFlags('0-3:P.x/Q.5/A.4');
      expect(flags.single.profanity, 0);
      expect(flags.single.aggressive, 4);
    });
  });

  group('what the settings hide (level 3 or more, like Twitch)', () {
    final flag = parseAutoModFlags('0-3:P.3').single;

    test('a category at 3 or more is hidden when its filter is on', () {
      expect(_all.hides(flag), isTrue);
      expect(_all.hides(parseAutoModFlags('0-3:P.2').single), isFalse);
      expect(_all.hides(parseAutoModFlags('0-3:P.0').single), isFalse);
    });

    test('nothing is hidden with the master switch off', () {
      expect(_all.copyWith(enabled: false).hides(flag), isFalse);
    });

    test('each category follows its own switch', () {
      expect(_all.copyWith(profanity: false).hides(flag), isFalse);
      final a = parseAutoModFlags('0-3:A.5').single;
      expect(_all.copyWith(harassment: false).hides(a), isFalse);
      expect(_all.copyWith(profanity: false).hides(a), isTrue);
      final i = parseAutoModFlags('0-3:I.3').single;
      expect(_all.copyWith(discrimination: false).hides(i), isFalse);
      final s = parseAutoModFlags('0-3:S.6').single;
      expect(_all.copyWith(sexual: false).hides(s), isFalse);
    });
  });

  group('masking', () {
    test('the range is hidden, end included, spaces kept', () {
      expect(_shown('kappa shut up', '6-12:A.5'), 'kappa **** **');
      expect(_shown('cock imorgen ?', '0-3:P.3'), '**** imorgen ?');
    });

    test('nothing to hide is null', () {
      expect(_shown('aint no damn way', '8-11:P.0'), isNull);
      expect(_shown('hello', ''), isNull);
    });

    test('positions count characters, an emoji being one', () {
      expect(_shown('😀 damn it', '2-5:P.3'), '😀 **** it');
    });

    test('an emoji inside a range is kept', () {
      expect(_shown('fu😀ck x', '0-4:P.3'), '**😀** x');
    });

    test('ranges Twitch drops are dropped', () {
      // A one-character range, an end past the text, a negative start.
      expect(_shown('a bc', '0-0:P.7'), isNull);
      expect(_shown('a bc', '2-9:P.7'), isNull);
      expect(_shown('a bc', '-1-2:P.7'), isNull);
    });

    test('a range starting inside the previous one is skipped', () {
      // Sorted by start: 0-3 is kept (not hidden), 2-6 overlaps it.
      expect(_shown('damn shit', '2-6:P.7,0-3:P.0'), isNull);
      expect(_shown('damn shit', '0-3:P.3,5-8:P.3'), '**** ****');
    });

    test('the mark is never a character of the text', () {
      final masked = maskFilteredText(
        '\u{E000}\u{E001} damn',
        parseAutoModFlags('3-6:P.3'),
        _all,
      )!;
      expect(masked.mark, '\u{E002}');
      expect(masked.text, '\u{E000}\u{E001} ${'\u{E002}' * 4}');
    });

    test('a long tag stops at 100 ranges', () {
      final tag = List.generate(150, (i) => '${i * 2}-${i * 2 + 1}:P.3');
      expect(parseAutoModFlags(tag.join(',')), hasLength(100));
    });
  });
}
