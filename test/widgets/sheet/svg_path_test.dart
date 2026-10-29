import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/sheet/svg_path.dart';

void main() {
  test('absolute and relative lines end where the data says', () {
    final path = parseSvgPath('M4 5h16v11H9l-5 4z');
    final bounds = path.getBounds();
    expect(bounds.left, 4);
    expect(bounds.top, 5);
    expect(bounds.right, 20);
    expect(bounds.bottom, 20);
  });

  test('arcs, smooth curves and joined numbers are read', () {
    final arc = parseSvgPath('M10 20a2 2 0 0 0 4 0');
    expect(arc.getBounds().width, closeTo(4, 0.01));
    expect(arc.getBounds().bottom, closeTo(22, 0.05));

    final smooth = parseSvgPath('M8 3c0 5 8 5 8 9s-8 4-8 9');
    expect(smooth.getBounds().bottom, closeTo(21, 0.01));

    // "5.6.7" is 5.6 then .7; "-5.7-5.7" two negatives.
    final joined = parseSvgPath('M12 4l2.4 5 5.6.7-4.1 3.8');
    expect(joined.getBounds().right, closeTo(20, 0.01));
  });

  test('compact arc flags are split', () {
    final compact = parseSvgPath('M0 0a5 5 0 014 4');
    final spaced = parseSvgPath('M0 0a5 5 0 0 1 4 4');
    expect(compact.getBounds(), spaced.getBounds());
  });

  test('broken data is refused, not drawn half', () {
    expect(() => parseSvgPath('5 5'), throwsFormatException);
    expect(() => parseSvgPath('M5'), throwsFormatException);
    expect(() => parseSvgPath('M5 5 X 3'), throwsFormatException);
    // A number after Z has no command to belong to: refused, not looped on.
    expect(() => parseSvgPath('M0 0Z 1 1'), throwsFormatException);
    expect(() => parseSvgPath('M0 0 L1 1 z 3'), throwsFormatException);
    // Z then a command is fine.
    expect(() => parseSvgPath('M0 0 L1 1 Z M2 2 L3 3 z'), returnsNormally);
  });

  test('every sheet glyph parses inside its 24 dp box', () {
    for (final kind in SheetGlyphKind.values) {
      final bounds = sheetGlyphPath(kind).getBounds();
      expect(
        bounds.isEmpty && bounds.width == 0 && bounds.height == 0,
        isFalse,
        reason: '$kind is empty',
      );
      expect(
        const Rect.fromLTWH(-0.5, -0.5, 25, 25).contains(bounds.topLeft) &&
            const Rect.fromLTWH(
              -0.5,
              -0.5,
              25,
              25,
            ).contains(bounds.bottomRight),
        isTrue,
        reason: '$kind spills out: $bounds',
      );
    }
  });
}
