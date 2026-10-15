import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/theme.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Whether two colours differ by at most one step on every channel.
Matcher _closeTo(Color expected) => predicate<Color>(
  (actual) =>
      (actual.r - expected.r).abs() * 255 <= 1.01 &&
      (actual.g - expected.g).abs() * 255 <= 1.01 &&
      (actual.b - expected.b).abs() * 255 <= 1.01,
  'within one step of $expected',
);

void main() {
  group('sub notice colours', () {
    test('the accent is the same green in both themes', () {
      expect(FrostyColors.light.subNoticeAccent, const Color(0xFF12A87A));
      expect(FrostyColors.dark.subNoticeAccent, const Color(0xFF12A87A));
    });

    test('the background is the accent tinting each theme', () {
      expect(
        FrostyColors.dark.subNoticeBackground,
        _closeTo(
          Color.alphaBlend(
            const Color(0xFF12A87A).withValues(alpha: 0.10),
            FrostyTokens.backgroundDark,
          ),
        ),
      );
      expect(
        FrostyColors.light.subNoticeBackground,
        _closeTo(
          Color.alphaBlend(
            const Color(0xFF12A87A).withValues(alpha: 0.08),
            FrostyTokens.backgroundLight,
          ),
        ),
      );
    });

    test('green text reads on the tint in both themes', () {
      for (final colors in [FrostyColors.light, FrostyColors.dark]) {
        expect(
          _contrast(colors.subNoticeText, colors.subNoticeBackground),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('the theme carries the colours', () {
      final dark = const FrostyThemes(
        colorSchemeSeed: FrostyTokens.accent,
      ).dark;

      expect(
        dark.extension<FrostyColors>()!.subNoticeBackground,
        FrostyColors.dark.subNoticeBackground,
      );
    });

    test('copyWith keeps or replaces them', () {
      final kept = FrostyColors.dark.copyWith(live: Colors.red);
      expect(kept.subNoticeAccent, FrostyColors.dark.subNoticeAccent);
      expect(kept.subNoticeBackground, FrostyColors.dark.subNoticeBackground);
      expect(kept.subNoticeText, FrostyColors.dark.subNoticeText);

      final replaced = FrostyColors.dark.copyWith(
        subNoticeAccent: Colors.red,
        subNoticeBackground: Colors.green,
        subNoticeText: Colors.blue,
      );
      expect(replaced.subNoticeAccent, Colors.red);
      expect(replaced.subNoticeBackground, Colors.green);
      expect(replaced.subNoticeText, Colors.blue);
    });

    test('lerp blends them', () {
      final halfway = FrostyColors.light.lerp(FrostyColors.dark, 0.5);

      expect(
        halfway.subNoticeBackground,
        Color.lerp(
          FrostyColors.light.subNoticeBackground,
          FrostyColors.dark.subNoticeBackground,
          0.5,
        ),
      );
      expect(
        halfway.subNoticeText,
        Color.lerp(
          FrostyColors.light.subNoticeText,
          FrostyColors.dark.subNoticeText,
          0.5,
        ),
      );
      expect(halfway.subNoticeAccent, FrostyColors.dark.subNoticeAccent);
    });
  });
}
