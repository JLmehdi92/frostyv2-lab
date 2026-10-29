import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';

/// The "Noir & Signal 2.0" values, read off the design system board
/// (Main.dc.html). The board is the source of truth: a token that drifts from
/// it fails here.
void main() {
  group('tokens v2', () {
    test('keep every existing token as it was', () {
      expect(OnsetTokens.backgroundDark, const Color(0xFF0A0A0A));
      expect(OnsetTokens.surfaceDark, const Color(0xFF141414));
      expect(OnsetTokens.backgroundLight, const Color(0xFFF8F8F8));
      expect(OnsetTokens.surfaceLight, const Color(0xFFFFFFFF));
      expect(OnsetTokens.hairlineWidth, 0.5);
      expect(OnsetTokens.hairlineDark, const Color(0x14FFFFFF));
      expect(OnsetTokens.accent, const Color(0xFFC8FF3D));
      expect(OnsetTokens.radiusSmall, 8);
      expect(OnsetTokens.radiusCard, 12);
      expect(OnsetTokens.radiusDialog, 16);
      expect(OnsetTokens.radiusPill, 100);
    });

    test('add the raised surface and the three text tiers', () {
      expect(OnsetTokens.raisedDark, const Color(0xFF1E1E1E));
      expect(OnsetTokens.textPrimaryDark, const Color(0xFFF5F5F5));
      expect(OnsetTokens.textBodyDark, const Color(0xFFD6D6D6));
      expect(OnsetTokens.textSecondaryDark, const Color(0xFFA1A1A1));
      expect(OnsetTokens.textTertiaryDark, const Color(0xFF8A8A8A));
    });

    test('the secondary text tier is the metadata colour', () {
      expect(OnsetColors.dark.metadata, OnsetTokens.textSecondaryDark);
    });

    test('add the stronger hairlines, the signal tint, hype and danger', () {
      expect(OnsetTokens.hairlineRaisedDark, const Color(0x1FFFFFFF));
      expect(OnsetTokens.hairlineStrongDark, const Color(0x29FFFFFF));
      expect(OnsetTokens.accentTint, const Color(0x1AC8FF3D));
      expect(OnsetTokens.hype, const Color(0xFF12A87A));
      expect(OnsetTokens.hype, OnsetColors.dark.subNoticeAccent);
      expect(OnsetTokens.hypeText, const Color(0xFF3DDBA6));
      expect(OnsetTokens.danger, const Color(0xFFFF5A5F));
    });

    test('skeletons read on the ground and on cards, with a subtle sheen', () {
      int step(Color c) => (c.r * 255).round();
      // Neutral greys.
      for (final c in [
        OnsetTokens.skeletonDark,
        OnsetTokens.skeletonSheenDark,
      ]) {
        expect(c.r, c.g);
        expect(c.g, c.b);
      }
      final base = step(OnsetTokens.skeletonDark);
      // Visible on a sheet or card (#141414), not only on the ground.
      expect(base - step(OnsetTokens.surfaceDark), greaterThanOrEqualTo(12));
      expect(base - step(OnsetTokens.backgroundDark), greaterThanOrEqualTo(20));
      // The sheen is a hint, not a flash.
      final sheen = step(OnsetTokens.skeletonSheenDark) - base;
      expect(sheen, inInclusiveRange(8, 14));
    });

    test('radii run 8 / 12 / 16 / 24 / pill', () {
      expect(
        [
          OnsetTokens.radiusSmall,
          OnsetTokens.radiusCard,
          OnsetTokens.radiusDialog,
          OnsetTokens.radiusLarge,
        ],
        [8, 12, 16, 24],
      );
      expect(OnsetTokens.radiusBadge, 6);
    });

    test('spacing is a 4-pt grid', () {
      final scale = [
        OnsetSpacing.xxs,
        OnsetSpacing.xs,
        OnsetSpacing.sm,
        OnsetSpacing.md,
        OnsetSpacing.lg,
        OnsetSpacing.xl,
        OnsetSpacing.xxl,
      ];
      expect(scale, [2, 4, 8, 12, 16, 24, 32]);
      for (final step in scale.skip(1)) {
        expect(step % 4, 0, reason: '$step is off the 4-pt grid');
      }
      expect(OnsetSpacing.gutterPhone, 16);
      expect(OnsetSpacing.gutterTablet, 28);
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
        OnsetType.display,
        size: 34,
        weight: FontWeight.w800,
        trackingEm: -0.035,
      );
      expect(OnsetType.display.height, 1.05);
      expectStyle(
        OnsetType.screenTitle,
        size: 24,
        weight: FontWeight.w700,
        trackingEm: -0.02,
      );
      expectStyle(
        OnsetType.section,
        size: 18,
        weight: FontWeight.w700,
        trackingEm: -0.015,
      );
      expectStyle(
        OnsetType.channelName,
        size: 16,
        weight: FontWeight.w600,
        trackingEm: -0.01,
      );
      expectStyle(
        OnsetType.body,
        size: 14,
        weight: FontWeight.w400,
        trackingEm: 0,
      );
      expect(OnsetType.body.height, 1.5);
      expectStyle(
        OnsetType.meta,
        size: 13,
        weight: FontWeight.w400,
        trackingEm: 0,
      );
      expectStyle(
        OnsetType.label,
        size: 11,
        weight: FontWeight.w600,
        trackingEm: 0.14,
      );
      expectStyle(
        OnsetType.badge,
        size: 11,
        weight: FontWeight.w800,
        trackingEm: 0.06,
      );
      expectStyle(
        OnsetType.wordmark,
        size: 20,
        weight: FontWeight.w800,
        trackingEm: -0.035,
      );
    });

    test('numbers do not dance: metadata uses tabular figures', () {
      expect(
        OnsetType.meta.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final tabular = OnsetType.tabular(OnsetType.section);
      expect(
        tabular.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(tabular.fontSize, OnsetType.section.fontSize);
      // Already tabular: not added twice.
      expect(
        OnsetType.tabular(
          OnsetType.meta,
        ).fontFeatures!.where((f) => f == const FontFeature.tabularFigures()),
        hasLength(1),
      );
    });
  });
}
