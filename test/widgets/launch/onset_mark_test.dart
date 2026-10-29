import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/launch/onset_mark.dart';

void main() {
  group('ON outline', () {
    test('sits centred in the 72 × 72 tile, inside its margins', () {
      final bounds = OnsetMark.glyphs().getBounds();
      expect(bounds.center.dx, closeTo(36, 0.05));
      expect(bounds.center.dy, closeTo(36, 0.05));
      expect(bounds.left, greaterThan(8));
      expect(bounds.right, lessThan(64));
      // 32 px Inter: cap height ≈ 23 px.
      expect(bounds.height, closeTo(23.9, 0.5));
    });

    test('has the two letters: the O with its counter, then the N', () {
      final svg = OnsetMark.glyphsSvg;
      expect('M'.allMatches(svg), hasLength(3));
      expect('Z'.allMatches(svg), hasLength(3));
      final path = OnsetMark.glyphs();
      // Inside the O's counter: empty. On the O's ring and the N: filled.
      expect(path.contains(const Offset(24, 36)), isFalse);
      expect(path.contains(const Offset(15, 38)), isTrue);
      expect(path.contains(const Offset(57, 26)), isTrue);
    });

    test('is the outline the Android splash draws', () {
      final xml = File(
        'android/app/src/main/res/drawable/launch_tile.xml',
      ).readAsStringSync();
      expect(xml, contains('android:pathData="${OnsetMark.glyphsSvg}"'));
      expect(xml, contains('android:viewportWidth="72"'));
      // The tile itself: the accent, with the board's 20 px corners.
      expect(xml, contains('android:fillColor="#C8FF3D"'));
      expect(xml, contains('android:fillColor="#0A0A0A"'));
      expect(xml, contains('A20,20'));
    });
  });

  group('OnsetMarkTile', () {
    testWidgets('is the accent tile with the dark ON, at any size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: OnsetMarkTile(size: 28)),
        ),
      );
      expect(tester.getSize(find.byType(OnsetMarkTile)), const Size(28, 28));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(OnsetMarkTile),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, OnsetTokens.accent);
      // Corners scale with the tile: 20 at 72.
      expect(decoration.borderRadius, BorderRadius.circular(20 * 28 / 72));
    });

    testWidgets('carries the brand name for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: OnsetMarkTile()),
        ),
      );
      expect(find.bySemanticsLabel('ONSET'), findsOneWidget);
      semantics.dispose();
    });
  });
}
