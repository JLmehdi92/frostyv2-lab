import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/celebrations/onset_rocket.dart';

void main() {
  test('the rocket asset splits into a body and a flame', () {
    final svg = File(kRocketAsset).readAsStringSync();
    final art = splitRocketSvg(svg)!;
    expect(art.whole, svg);
    expect(art.body, isNot(contains('rk-flame')));
    expect(art.body, contains('M60 12C75 25'));
    expect(art.flame, contains('rk-flame'));
    expect(art.flame, isNot(contains('M60 12C75 25')));
    // Both keep the drawing's frame and gradients.
    for (final part in [art.body, art.flame]) {
      expect(part, contains('rotate(45 60 60)'));
      expect(part, contains('<defs>'));
      expect(part.trim(), endsWith('</svg>'));
    }
  });

  test('a drawing without the flame group is drawn whole', () {
    expect(splitRocketSvg('<svg><g><path/></g></svg>'), isNull);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool flicker = true,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(child: OnsetRocket(size: 32, flicker: flicker)),
      ),
    );
  }

  setUpAll(() => debugSetRocketArt(File(kRocketAsset).readAsStringSync()));
  tearDownAll(() => debugSetRocketArt(null));

  testWidgets('a flickering flame under the body, at its size', (tester) async {
    await pump(tester);
    expect(tester.getSize(find.byType(OnsetRocket)), const Size.square(32));
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(OnsetRocket),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 55));
    expect(tester.hasRunningAnimations, isTrue);
    // A burst, not a loop: it settles by itself.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduce motion: one still drawing', (tester) async {
    await pump(tester, reduceMotion: true);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('without flicker: one still drawing', (tester) async {
    await pump(tester, flicker: false);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
