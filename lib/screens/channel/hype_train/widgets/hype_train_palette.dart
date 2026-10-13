import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';

/// Colours and icon of one hype train style, built on the app's
/// [ColorScheme] so it follows the theme and accent colour.
@immutable
class HtPalette {
  const HtPalette({
    required this.background,
    required this.onBackground,
    required this.fill,
    required this.track,
    required this.icon,
    required this.iconColor,
    required this.a11yName,
    this.fillEnd,
  });

  factory HtPalette.of(HtStyle style, ColorScheme scheme, {int? creatorColor}) {
    final dark = scheme.brightness == Brightness.dark;
    HtPalette tinted({
      required Color light,
      required Color darkBackground,
      required Color fill,
      Color? fillEnd,
      required IconData icon,
      required String name,
    }) {
      final background = dark ? darkBackground : light;
      final on = onColor(background);
      return HtPalette(
        background: background,
        onBackground: on,
        fill: fill,
        fillEnd: fillEnd,
        track: on.withValues(alpha: 0.16),
        icon: icon,
        iconColor: dark ? fillEnd ?? fill : on,
        a11yName: name,
      );
    }

    switch (style) {
      case HtStyle.regular:
        final background = scheme.primaryContainer;
        final on = onColor(background);
        return HtPalette(
          background: background,
          onBackground: on,
          fill: creatorColor != null ? Color(creatorColor) : scheme.primary,
          track: on.withValues(alpha: 0.16),
          icon: Icons.train_rounded,
          iconColor: on,
          a11yName: 'Hype Train',
        );
      case HtStyle.shared:
        final background = scheme.tertiaryContainer;
        final on = onColor(background);
        return HtPalette(
          background: background,
          onBackground: on,
          fill: scheme.tertiary,
          track: on.withValues(alpha: 0.16),
          icon: Icons.groups_rounded,
          iconColor: on,
          a11yName: 'Shared Hype Train',
        );
      case HtStyle.goldenKappa:
        return tinted(
          light: const Color(0xFFFFF3C4),
          darkBackground: const Color(0xFF3D2E00),
          fill: const Color(0xFFFFC94D),
          fillEnd: const Color(0xFFFFA000),
          icon: Icons.star_rounded,
          name: 'Golden Kappa Train',
        );
      case HtStyle.treasure:
        return tinted(
          light: const Color(0xFFDDF4F1),
          darkBackground: const Color(0xFF0B3330),
          fill: const Color(0xFF26A69A),
          fillEnd: const Color(0xFFFFC94D),
          icon: Icons.savings_rounded,
          name: 'Treasure Train',
        );
      case HtStyle.community:
        return tinted(
          light: const Color(0xFFE3F2FD),
          darkBackground: const Color(0xFF0D2A45),
          fill: const Color(0xFF42A5F5),
          fillEnd: const Color(0xFF1E88E5),
          icon: Icons.rocket_launch_rounded,
          name: 'Community Train',
        );
      case HtStyle.mythic:
        return tinted(
          light: const Color(0xFFF6E3FF),
          darkBackground: const Color(0xFF2D0F3D),
          fill: const Color(0xFFE040FB),
          fillEnd: const Color(0xFF7C4DFF),
          icon: Icons.auto_awesome_rounded,
          name: 'Mythic Train',
        );
      case HtStyle.athApproaching:
        return tinted(
          light: const Color(0xFFFFF0E0),
          darkBackground: const Color(0xFF3D2200),
          fill: const Color(0xFFFFA726),
          fillEnd: const Color(0xFFFB8C00),
          icon: Icons.emoji_events_outlined,
          name: 'Hype Train near its record',
        );
      case HtStyle.athReached:
        return tinted(
          light: const Color(0xFFFFE5E0),
          darkBackground: const Color(0xFF3D1010),
          fill: const Color(0xFFFF7043),
          fillEnd: const Color(0xFFE53935),
          icon: Icons.emoji_events_rounded,
          name: 'Record Hype Train',
        );
    }
  }

  final Color background;
  final Color onBackground;
  final Color fill;

  /// The gradient's end; a flat fill without it.
  final Color? fillEnd;
  final Color track;
  final IconData icon;
  final Color iconColor;

  /// The style's name for screen readers.
  final String a11yName;

  Gradient get fillGradient => LinearGradient(colors: [fill, fillEnd ?? fill]);

  /// Black or white, whichever reads better on [background] (always at
  /// least 4.5:1).
  static Color onColor(Color background) =>
      contrast(Colors.black, background) >= contrast(Colors.white, background)
      ? Colors.black
      : Colors.white;

  /// WCAG contrast ratio between two colours.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final (hi, lo) = la > lb ? (la, lb) : (lb, la);
    return (hi + 0.05) / (lo + 0.05);
  }
}
