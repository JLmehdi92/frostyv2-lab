import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// Colours and icon of one hype train style: Twitch's per-variant styles,
/// green where Twitch is purple. Only the theme's brightness is read.
@immutable
class HtPalette {
  const HtPalette({
    required this.track,
    required this.fill,
    required this.text,
    required this.checkPill,
    required this.barTrack,
    required this.link,
    required this.icon,
    required this.a11yName,
    this.fillColors,
    this.fillCoversAll = false,
    this.pill = HtNeutrals.pill,
    this.pillText = Colors.white,
    this.textShadow,
    this.trophy = false,
    this.speedlines = false,
    this.pillFillColors,
  });

  factory HtPalette.of(
    HtStyle style,
    ColorScheme scheme, {
    int? creatorColor,
    bool treasureUnlocked = false,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    final neutrals = HtNeutrals.of(scheme.brightness);
    final green = dark ? HtGreen.g8 : HtGreen.g10;
    final link = dark ? HtGreen.g11 : HtGreen.g7;

    /// The float card with the green (or creator) fill and base text.
    HtPalette onFloat({
      required IconData icon,
      required String name,
      Color? fill,
      bool speedlines = false,
      List<Color>? pillFillColors,
    }) => HtPalette(
      track: neutrals.backgroundFloat,
      fill: fill ?? green,
      text: neutrals.textBase,
      checkPill: fill ?? green,
      barTrack: neutrals.buttonBackgroundSecondary,
      link: link,
      icon: icon,
      a11yName: name,
      speedlines: speedlines,
      pillFillColors: pillFillColors,
    );

    /// The record: green to azure over the base background.
    HtPalette record({
      required IconData icon,
      required String name,
      required bool trophy,
    }) {
      final colors = dark
          ? const [HtGreen.g9, HtGreen.azureDark]
          : const [HtGreen.g10, HtGreen.azureLight];
      return HtPalette(
        track: neutrals.backgroundBase,
        fill: colors.first,
        fillColors: colors,
        text: neutrals.textBase,
        checkPill: green,
        barTrack: neutrals.buttonBackgroundSecondary,
        link: link,
        icon: icon,
        a11yName: name,
        trophy: trophy,
      );
    }

    switch (style) {
      case HtStyle.regular:
        final creator = creatorColor;
        return onFloat(
          icon: Icons.train_rounded,
          name: 'Hype Train',
          fill: creator == null || isTwitchPurple(creator)
              ? null
              : Color(creator),
        );
      case HtStyle.shared:
        return onFloat(
          icon: Icons.groups_rounded,
          name: 'Shared Hype Train',
          speedlines: true,
          // Twitch's collab colours, purple turned green.
          pillFillColors: const [Color(0xFFBE0078), HtGreen.g9],
        );
      case HtStyle.treasure:
        if (!treasureUnlocked) {
          return onFloat(icon: Icons.savings_rounded, name: 'Treasure Train');
        }
        return HtPalette(
          track: neutrals.backgroundFloat,
          fill: HtGreen.g9,
          fillColors: const [Color(0xFF1345AA), HtGreen.g9],
          fillCoversAll: true,
          text: Colors.white,
          checkPill: green,
          barTrack: neutrals.buttonBackgroundSecondary,
          link: link,
          icon: Icons.savings_rounded,
          a11yName: 'Treasure Train',
        );
      case HtStyle.community:
        return HtPalette(
          track: const Color(0xFF071A40),
          fill: const Color(0xFF1756D3),
          text: Colors.white,
          checkPill: const Color(0xFF1756D3),
          barTrack: neutrals.buttonBackgroundSecondary,
          link: link,
          icon: Icons.rocket_launch_rounded,
          a11yName: 'Community Train',
        );
      case HtStyle.mythic:
        return HtPalette(
          track: const Color(0xFF403520),
          fill: const Color(0x80976700),
          fillColors: const [
            Color(0x80976700),
            Color(0x80FFF9EB),
            Color(0x80FFD760),
          ],
          text: Colors.white,
          // The gold gradient is light: the text needs a shadow.
          textShadow: const Shadow(color: Color(0xCC000000), blurRadius: 1),
          checkPill: const Color(0xFF976700),
          barTrack: neutrals.buttonBackgroundSecondary,
          link: link,
          icon: Icons.auto_awesome_rounded,
          a11yName: 'Mythic Train',
        );
      case HtStyle.goldenKappa:
        return HtPalette(
          track: const Color(0xFFFFB31A),
          fill: const Color(0xFFFFDF9E),
          text: Colors.black,
          pill: HtNeutrals.pillGolden,
          checkPill: const Color(0xFFFFB31A),
          barTrack: neutrals.buttonBackgroundSecondary,
          link: link,
          icon: Icons.star_rounded,
          a11yName: 'Golden Kappa Train',
        );
      case HtStyle.athReached:
        return record(
          icon: Icons.emoji_events_rounded,
          name: 'All-Time High Hype Train',
          trophy: true,
        );
      case HtStyle.athApproaching:
        return record(
          icon: Icons.emoji_events_outlined,
          name: 'Approaching Hype Train Record',
          trophy: false,
        );
    }
  }

  /// Behind the fill: the banner's background.
  final Color track;

  /// The fill; the gradient's first colour when [fillColors] is set.
  final Color fill;

  /// A gradient across the whole banner width, clipped to the progress
  /// (not squeezed into it).
  final List<Color>? fillColors;

  /// The gradient covers the whole banner whatever the progress (an
  /// unlocked treasure).
  final bool fillCoversAll;

  final Color text;

  /// The level pill and its text.
  final Color pill;
  final Color pillText;

  /// The approaching banner's events pill.
  final Color checkPill;

  /// The track of the details' 3 dp bar.
  final Color barTrack;

  /// "learn more" and "More Info".
  final Color link;

  /// On light gradients (Mythic) the text gets a 1 px shadow.
  final Shadow? textShadow;

  /// A white trophy sits in the level pill (the record).
  final bool trophy;

  /// Our own speedlines and sparkles over the track (shared trains).
  final bool speedlines;

  /// The landscape pill's fill as a gradient; flat #0C6D4F without it.
  final List<Color>? pillFillColors;

  final IconData icon;

  /// The style's name for screen readers.
  final String a11yName;

  /// The fill as a gradient (flat when there is one colour).
  Gradient get fillGradient =>
      LinearGradient(colors: fillColors ?? [fill, fill]);

  /// The text style's colour and shadow.
  TextStyle textStyle(TextStyle base) => base.copyWith(
    color: text,
    shadows: textShadow == null ? null : [textShadow!],
  );

  /// WCAG contrast ratio between two colours.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final (hi, lo) = la > lb ? (la, lb) : (lb, la);
    return (hi + 0.05) / (lo + 0.05);
  }
}
