import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Every Inter face the app bundles draws the characters French needs: the
/// no-break spaces of its punctuation, the curly apostrophe, the ellipsis,
/// the quotation marks, œ and the accented capitals. A missing one would
/// fall back to another font (or a box) in the middle of a word.
void main() {
  const french = {
    0x00A0: 'no-break space',
    0x202F: 'narrow no-break space',
    0x2019: '’',
    0x2026: '…',
    0x00AB: '«',
    0x00BB: '»',
    0x201C: '“',
    0x201D: '”',
    0x2013: '–',
    0x2014: '—',
    0x00B7: '·',
    0x0153: 'œ',
    0x0152: 'Œ',
    0x00E6: 'æ',
    0x00C6: 'Æ',
    0x00C9: 'É',
    0x00C8: 'È',
    0x00CA: 'Ê',
    0x00CB: 'Ë',
    0x00C0: 'À',
    0x00C2: 'Â',
    0x00C7: 'Ç',
    0x00CE: 'Î',
    0x00CF: 'Ï',
    0x00D4: 'Ô',
    0x00D9: 'Ù',
    0x00DB: 'Û',
    0x00DC: 'Ü',
    0x0178: 'Ÿ',
    0x00E9: 'é',
    0x00E8: 'è',
    0x00EA: 'ê',
    0x00EB: 'ë',
    0x00E0: 'à',
    0x00E2: 'â',
    0x00E7: 'ç',
    0x00EE: 'î',
    0x00EF: 'ï',
    0x00F4: 'ô',
    0x00F9: 'ù',
    0x00FB: 'û',
    0x00FC: 'ü',
    0x00FF: 'ÿ',
  };

  final faces = Directory(
    'assets/fonts',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).toList();

  test('the bundled faces are found', () {
    expect(faces.length, greaterThanOrEqualTo(9));
  });

  test('the reader finds what is there and misses what is not', () {
    final regular = faces.firstWhere((f) => f.path.endsWith('Regular.ttf'));
    final mapped = cmapCodePoints(regular.readAsBytesSync());
    expect(mapped, containsAll(['A'.codeUnitAt(0), 'z'.codeUnitAt(0)]));
    // A CJK ideograph and an emoji: not in Inter.
    expect(mapped, isNot(contains(0x4E2D)));
    expect(mapped, isNot(contains(0x1F600)));
  });

  for (final face in faces) {
    test('${face.uri.pathSegments.last} draws French', () {
      final mapped = cmapCodePoints(face.readAsBytesSync());
      final missing = [
        for (final MapEntry(key: code, value: name) in french.entries)
          if (!mapped.contains(code))
            'U+${code.toRadixString(16).toUpperCase().padLeft(4, '0')} $name',
      ];
      expect(missing, isEmpty);
    });
  }
}

/// The code points a TrueType/OpenType font maps to glyphs (its Unicode
/// `cmap` subtables of format 4 and 12).
Set<int> cmapCodePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tableCount = data.getUint16(4);
  int? cmap;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap == null) throw const FormatException('No cmap table');
  final codes = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final record = cmap + 4 + 8 * i;
    final platform = data.getUint16(record);
    final encoding = data.getUint16(record + 2);
    final unicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode) continue;
    final table = cmap + data.getUint32(record + 4);
    switch (data.getUint16(table)) {
      case 4:
        final segments = data.getUint16(table + 6) ~/ 2;
        final ends = table + 14;
        final starts = ends + 2 * segments + 2;
        final deltas = starts + 2 * segments;
        final ranges = deltas + 2 * segments;
        for (var s = 0; s < segments; s++) {
          final end = data.getUint16(ends + 2 * s);
          final start = data.getUint16(starts + 2 * s);
          final delta = data.getUint16(deltas + 2 * s);
          final rangeOffset = data.getUint16(ranges + 2 * s);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            final int glyph;
            if (rangeOffset == 0) {
              glyph = (c + delta) & 0xFFFF;
            } else {
              final at = ranges + 2 * s + rangeOffset + 2 * (c - start);
              final raw = data.getUint16(at);
              glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
            }
            if (glyph != 0) codes.add(c);
          }
        }
      case 12:
        final groups = data.getUint32(table + 12);
        for (var g = 0; g < groups; g++) {
          final group = table + 16 + 12 * g;
          final start = data.getUint32(group);
          final end = data.getUint32(group + 4);
          final glyph = data.getUint32(group + 8);
          for (var c = start; c <= end; c++) {
            if (glyph + (c - start) != 0) codes.add(c);
          }
        }
    }
  }
  return codes;
}
