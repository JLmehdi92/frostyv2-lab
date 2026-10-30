import 'package:flutter/material.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// ONSET's level colour of a regular (or shared) hype train (board
/// CadeauxHypeTrain, C): it climbs with the level, from green to the signal
/// lime and orange; from level 6 a lime and orange gradient flows. Dark text
/// on the fill, light text on the darkened track, 4.5:1 or better on both.
@immutable
class HtLevelColors {
  const HtLevelColors._({
    required this.fill,
    required this.track,
    required this.hairline,
    required this.pill,
    required this.deep,
    this.gradient,
    this.sheen = false,
  });

  /// The fill (the gradient's first colour when [gradient] is set).
  final Color fill;

  /// A gradient across the banner (level 3, and level 6 and up).
  final List<Color>? gradient;

  /// The level 6+ gradient flows (paused with reduced motion).
  final bool sheen;

  /// The banner behind the fill.
  final Color track;

  /// The 0.5 dp inner ring of the banner.
  final Color hairline;

  /// The level on the dark pill.
  final Color pill;

  /// The colour darkened for icons on the light theme's sheet.
  final Color deep;

  static const lime = Color(0xFFC8FF3D);
  static const orange = Color(0xFFFF7A45);

  static const _levels = [
    HtLevelColors._(
      fill: Color(0xFF12A87A),
      track: Color(0xFF142C24),
      hairline: Color(0x7312A87A),
      pill: Color(0xFF12A87A),
      deep: Color(0xFF0B7A5E),
    ),
    HtLevelColors._(
      fill: Color(0xFF14B8A6),
      track: Color(0xFF142E2B),
      hairline: Color(0x7314B8A6),
      pill: Color(0xFF14B8A6),
      deep: Color(0xFF0F766E),
    ),
    HtLevelColors._(
      fill: Color(0xFF3DDBA6),
      gradient: [Color(0xFF3DDBA6), Color(0xFF7CF0FF), Color(0xFF3DDBA6)],
      track: Color(0xFF1B342B),
      hairline: Color(0x733DDBA6),
      pill: Color(0xFF3DDBA6),
      deep: Color(0xFF0B7A5E),
    ),
    HtLevelColors._(
      fill: lime,
      track: Color(0xFF313A1B),
      hairline: Color(0x66C8FF3D),
      pill: lime,
      deep: Color(0xFF5A7400),
    ),
    HtLevelColors._(
      fill: orange,
      track: Color(0xFF3A241C),
      hairline: Color(0x73FF7A45),
      pill: orange,
      deep: Color(0xFFB0400C),
    ),
    HtLevelColors._(
      fill: lime,
      // One lime → orange → lime period across the banner; it repeats as it
      // flows.
      gradient: [lime, orange, lime],
      sheen: true,
      track: Color(0xFF352F1B),
      hairline: Color(0x73E4BC41),
      pill: lime,
      deep: Color(0xFF5A7400),
    ),
  ];

  /// The colours of [level] (level 6 and up share one).
  static HtLevelColors of(int level) =>
      _levels[(level < 1 ? 1 : (level > 6 ? 6 : level)) - 1];

  /// Text on the fill.
  static const onFill = Color(0xFF0A0A0A);

  /// Text on the track.
  static const onTrack = Color(0xFFF5F5F5);
}

/// Colours and icon of one hype train style: Twitch's per-variant styles,
/// green where Twitch is purple, and ONSET's level colours for the regular
/// and shared trains. Only the theme's brightness is read.
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
    this.textOnFill,
    this.hairline,
    this.fillSheen = false,
    this.radius = HtDims.radius,
  });

  /// Before a train starts: Twitch's float card with the green events pill
  /// (the creator's colour is no longer used).
  factory HtPalette.approaching(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final neutrals = HtNeutrals.of(scheme.brightness);
    final green = dark ? HtGreen.g8 : HtGreen.g10;
    return HtPalette(
      track: neutrals.backgroundFloat,
      fill: green,
      text: neutrals.textBase,
      checkPill: green,
      barTrack: neutrals.buttonBackgroundSecondary,
      link: dark ? HtGreen.g11 : HtGreen.g7,
      icon: Icons.train_rounded,
      a11yName: 'Hype Train',
    );
  }

  /// [level] picks the regular and shared trains' ONSET colours.
  factory HtPalette.of(
    HtStyle style,
    ColorScheme scheme, {
    int level = 1,
    bool treasureUnlocked = false,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    final neutrals = HtNeutrals.of(scheme.brightness);
    final green = dark ? HtGreen.g8 : HtGreen.g10;
    final link = dark ? HtGreen.g11 : HtGreen.g7;

    /// The float card with the green fill and base text (a locked
    /// treasure).
    HtPalette onFloat({required IconData icon, required String name}) =>
        HtPalette(
          track: neutrals.backgroundFloat,
          fill: green,
          text: neutrals.textBase,
          checkPill: green,
          barTrack: neutrals.buttonBackgroundSecondary,
          link: link,
          icon: icon,
          a11yName: name,
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

    /// ONSET's level colours: dark text on the fill, light on the track.
    HtPalette byLevel({
      required IconData icon,
      required String name,
      bool speedlines = false,
    }) {
      final colors = HtLevelColors.of(level);
      return HtPalette(
        track: colors.track,
        fill: colors.fill,
        fillColors: colors.gradient,
        fillSheen: colors.sheen,
        text: HtLevelColors.onTrack,
        textOnFill: HtLevelColors.onFill,
        hairline: colors.hairline,
        pill: const Color(0xDB0A0A0A),
        pillText: colors.pill,
        checkPill: dark ? colors.pill : colors.deep,
        barTrack: neutrals.buttonBackgroundSecondary,
        link: link,
        icon: icon,
        a11yName: name,
        speedlines: speedlines,
        pillFillColors: colors.gradient ?? [colors.fill, colors.fill],
        radius: 12,
      );
    }

    switch (style) {
      case HtStyle.regular:
        return byLevel(icon: Icons.train_rounded, name: 'Hype Train');
      case HtStyle.shared:
        // The board's shared train: the level colour and the speedlines.
        return byLevel(
          icon: Icons.groups_rounded,
          name: 'Shared Hype Train',
          speedlines: true,
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

  /// Text over the fill, when it differs from [text] (the level colours):
  /// the text then turns at the fill's edge.
  final Color? textOnFill;

  /// The banner's 0.5 dp inner ring, if any.
  final Color? hairline;

  /// The fill's gradient flows (level 6 and up).
  final bool fillSheen;

  /// The banner's corners: 12 dp for the level colours, Twitch's 6 dp else.
  final double radius;

  final IconData icon;

  /// The style's name for screen readers.
  final String a11yName;

  /// This palette with all its text in [color] (no turn at the fill's
  /// edge): for announcements that carry pictures.
  HtPalette withText(Color color) => HtPalette(
    track: track,
    fill: fill,
    fillColors: fillColors,
    fillCoversAll: fillCoversAll,
    text: color,
    pill: pill,
    pillText: pillText,
    checkPill: checkPill,
    barTrack: barTrack,
    link: link,
    icon: icon,
    a11yName: a11yName,
    textShadow: textShadow,
    trophy: trophy,
    speedlines: speedlines,
    pillFillColors: pillFillColors,
    hairline: hairline,
    fillSheen: fillSheen,
    radius: radius,
  );

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
