import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/theme.dart';

/// The "Noir & Signal 2.0" values, read off the design system board
/// (Main.dc.html). The board is the source of truth: a token that drifts from
/// it fails here.
void main() {
  group('tokens v2', () {
    test('keep every existing token as it was', () {
      expect(FrostyTokens.backgroundDark, const Color(0xFF0A0A0A));
      expect(FrostyTokens.surfaceDark, const Color(0xFF141414));
      expect(FrostyTokens.backgroundLight, const Color(0xFFF8F8F8));
      expect(FrostyTokens.surfaceLight, const Color(0xFFFFFFFF));
      expect(FrostyTokens.hairlineWidth, 0.5);
      expect(FrostyTokens.hairlineDark, const Color(0x14FFFFFF));
      expect(FrostyTokens.accent, const Color(0xFFC8FF3D));
      expect(FrostyTokens.radiusSmall, 8);
      expect(FrostyTokens.radiusCard, 12);
      expect(FrostyTokens.radiusDialog, 16);
      expect(FrostyTokens.radiusPill, 100);
    });

    test('add the raised surface and the three text tiers', () {
      expect(FrostyTokens.raisedDark, const Color(0xFF1E1E1E));
      expect(FrostyTokens.textPrimaryDark, const Color(0xFFF5F5F5));
      expect(FrostyTokens.textBodyDark, const Color(0xFFD6D6D6));
      expect(FrostyTokens.textSecondaryDark, const Color(0xFFA1A1A1));
      expect(FrostyTokens.textTertiaryDark, const Color(0xFF8A8A8A));
    });

    test('the secondary text tier is the metadata colour', () {
      expect(FrostyColors.dark.metadata, FrostyTokens.textSecondaryDark);
    });

    test('add the stronger hairlines, the signal tint, hype and danger', () {
      expect(FrostyTokens.hairlineRaisedDark, const Color(0x1FFFFFFF));
      expect(FrostyTokens.hairlineStrongDark, const Color(0x29FFFFFF));
      expect(FrostyTokens.accentTint, const Color(0x1AC8FF3D));
      expect(FrostyTokens.hype, const Color(0xFF12A87A));
      expect(FrostyTokens.hype, FrostyColors.dark.subNoticeAccent);
      expect(FrostyTokens.hypeText, const Color(0xFF3DDBA6));
      expect(FrostyTokens.danger, const Color(0xFFFF5A5F));
      // The loading board's greys.
      expect(FrostyTokens.skeletonDark, const Color(0xFF161616));
      expect(FrostyTokens.skeletonSheenDark, const Color(0xFF232323));
    });

    test('radii run 8 / 12 / 16 / 24 / pill', () {
      expect(
        [
          FrostyTokens.radiusSmall,
          FrostyTokens.radiusCard,
          FrostyTokens.radiusDialog,
          FrostyTokens.radiusLarge,
        ],
        [8, 12, 16, 24],
      );
      expect(FrostyTokens.radiusBadge, 6);
    });

    test('spacing is a 4-pt grid', () {
      final scale = [
        FrostySpacing.xxs,
        FrostySpacing.xs,
        FrostySpacing.sm,
        FrostySpacing.md,
        FrostySpacing.lg,
        FrostySpacing.xl,
        FrostySpacing.xxl,
      ];
      expect(scale, [2, 4, 8, 12, 16, 24, 32]);
      for (final step in scale.skip(1)) {
        expect(step % 4, 0, reason: '$step is off the 4-pt grid');
      }
      expect(FrostySpacing.gutterPhone, 16);
      expect(FrostySpacing.gutterTablet, 28);
    });
  });

  group('type scale', () {
    void expectStyle(
      TextStyle style, {
      required double size,
      required FontWeight weight,
      required double trackingEm,
    }) {
      expect(style.fontFamily, 'Inter');
      expect(style.fontSize, size);
      expect(style.fontWeight, weight);
      expect(style.letterSpacing, closeTo(trackingEm * size, 0.001));
      // Colour comes from the theme, so the scale serves both themes.
      expect(style.color, isNull);
    }

    test('matches the board', () {
      expectStyle(
        FrostyType.display,
        size: 34,
        weight: FontWeight.w800,
        trackingEm: -0.035,
      );
      expect(FrostyType.display.height, 1.05);
      expectStyle(
        FrostyType.screenTitle,
        size: 24,
        weight: FontWeight.w700,
        trackingEm: -0.02,
      );
      expectStyle(
        FrostyType.section,
        size: 18,
        weight: FontWeight.w700,
        trackingEm: -0.015,
      );
      expectStyle(
        FrostyType.channelName,
        size: 16,
        weight: FontWeight.w600,
        trackingEm: -0.01,
      );
      expectStyle(
        FrostyType.body,
        size: 14,
        weight: FontWeight.w400,
        trackingEm: 0,
      );
      expect(FrostyType.body.height, 1.5);
      expectStyle(
        FrostyType.meta,
        size: 13,
        weight: FontWeight.w400,
        trackingEm: 0,
      );
      expectStyle(
        FrostyType.label,
        size: 11,
        weight: FontWeight.w600,
        trackingEm: 0.14,
      );
      expectStyle(
        FrostyType.badge,
        size: 11,
        weight: FontWeight.w800,
        trackingEm: 0.06,
      );
      expectStyle(
        FrostyType.wordmark,
        size: 20,
        weight: FontWeight.w800,
        trackingEm: -0.035,
      );
    });

    test('numbers do not dance: metadata uses tabular figures', () {
      expect(
        FrostyType.meta.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final tabular = FrostyType.tabular(FrostyType.section);
      expect(
        tabular.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(tabular.fontSize, FrostyType.section.fontSize);
      // Already tabular: not added twice.
      expect(
        FrostyType.tabular(
          FrostyType.meta,
        ).fontFeatures!.where((f) => f == const FontFeature.tabularFigures()),
        hasLength(1),
      );
    });
  });
}
