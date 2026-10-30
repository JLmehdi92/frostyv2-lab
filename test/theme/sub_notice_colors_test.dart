import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';

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
    test('the accent is the signal lime, darkened on white', () {
      // Board CadeauxHypeTrain: lime rows, green stays with the hype train.
      expect(OnsetColors.dark.subNoticeAccent, OnsetTokens.accent);
      expect(OnsetColors.dark.subNoticeAccent, OnsetColors.dark.live);
      expect(OnsetColors.light.subNoticeAccent, const Color(0xFF6B8A00));
    });

    test('the background is the accent tinting each theme', () {
      expect(OnsetColors.dark.subNoticeBackground, const Color(0xFF171B0E));
      expect(
        OnsetColors.dark.subNoticeBackground,
        _closeTo(
          Color.alphaBlend(
            OnsetTokens.accent.withValues(alpha: 0.07),
            OnsetTokens.backgroundDark,
          ),
        ),
      );
      expect(
        OnsetColors.light.subNoticeBackground,
        _closeTo(
          Color.alphaBlend(
            const Color(0xFF6B8A00).withValues(alpha: 0.08),
            OnsetTokens.backgroundLight,
          ),
        ),
      );
    });

    test('the accent bar stands out from the tint', () {
      for (final colors in [OnsetColors.light, OnsetColors.dark]) {
        expect(
          _contrast(colors.subNoticeAccent, colors.subNoticeBackground),
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('lime text reads on the tint in both themes', () {
      for (final colors in [OnsetColors.light, OnsetColors.dark]) {
        expect(
          _contrast(colors.subNoticeText, colors.subNoticeBackground),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('the theme carries the colours', () {
      final dark = const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark;

      expect(
        dark.extension<OnsetColors>()!.subNoticeBackground,
        OnsetColors.dark.subNoticeBackground,
      );
    });

    test('copyWith keeps or replaces them', () {
      final kept = OnsetColors.dark.copyWith(live: Colors.red);
      expect(kept.subNoticeAccent, OnsetColors.dark.subNoticeAccent);
      expect(kept.subNoticeBackground, OnsetColors.dark.subNoticeBackground);
      expect(kept.subNoticeText, OnsetColors.dark.subNoticeText);

      final replaced = OnsetColors.dark.copyWith(
        subNoticeAccent: Colors.red,
        subNoticeBackground: Colors.green,
        subNoticeText: Colors.blue,
      );
      expect(replaced.subNoticeAccent, Colors.red);
      expect(replaced.subNoticeBackground, Colors.green);
      expect(replaced.subNoticeText, Colors.blue);
    });

    test('lerp blends them', () {
      final halfway = OnsetColors.light.lerp(OnsetColors.dark, 0.5);

      expect(
        halfway.subNoticeBackground,
        Color.lerp(
          OnsetColors.light.subNoticeBackground,
          OnsetColors.dark.subNoticeBackground,
          0.5,
        ),
      );
      expect(
        halfway.subNoticeText,
        Color.lerp(
          OnsetColors.light.subNoticeText,
          OnsetColors.dark.subNoticeText,
          0.5,
        ),
      );
      expect(
        halfway.subNoticeAccent,
        Color.lerp(
          OnsetColors.light.subNoticeAccent,
          OnsetColors.dark.subNoticeAccent,
          0.5,
        ),
      );
    });
  });
}
