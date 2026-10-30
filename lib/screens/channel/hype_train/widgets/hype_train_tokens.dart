import 'package:flutter/material.dart';
import 'package:onset/theme.dart';

/// The hype train's green ramp, from the darkest ([ink]) to the lightest
/// ([light]), in the hue of #12A87A. Each step keeps the luminance of the
/// purple it stands for (in its doc), so contrasts stay the same.
abstract final class HtGreen {
  /// For #5C16C5: links in light mode.
  static const ink = Color(0xFF09553D);

  /// For #772CE8: the dark fill and the landscape pill.
  static const deep = Color(0xFF0C6D4F);

  /// For #9147FF: dark gradient starts and the unlocked treasure.
  static const strong = Color(0xFF0E8661);

  /// For #A970FF: the light fill.
  static const base = Color(0xFF12A87A);

  /// For #BF94FF: links and icons in dark mode.
  static const light = Color(0xFF15C08B);

  /// Where the all-time-high gradient ends (Twitch's pink).
  static const azureLight = Color(0xFF069DE9);
  static const azureDark = Color(0xFF057DB8);
}

/// The hype train details sheet's background (board ChaineHypeDetail): the
/// community green at 10 % (8 % light) over the theme's background. Sub and
/// gift rows moved to lime; the hype train keeps its green.
Color htSheetBackground(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF0B1A15)
    : const Color(0xFFE6F2EE);

/// Twitch's neutrals inside the hype train, for one brightness.
@immutable
class HtNeutrals {
  const HtNeutrals._({
    required this.backgroundFloat,
    required this.backgroundBase,
    required this.backgroundAlt,
    required this.textBase,
    required this.textAlt,
    required this.textAlt2,
    required this.borderBase,
    required this.buttonBackgroundSecondary,
  });

  static const light = HtNeutrals._(
    backgroundFloat: Color(0xFFFFFFFF),
    backgroundBase: Color(0xFFFFFFFF),
    backgroundAlt: Color(0xFFEFEFF1),
    textBase: Color(0xFF0E0E10),
    textAlt: Color(0xFF3B3B44),
    textAlt2: Color(0xFF3B3B44),
    borderBase: Color(0x59ADADB8),
    buttonBackgroundSecondary: Color(0x14000000),
  );

  static const dark = HtNeutrals._(
    backgroundFloat: Color(0xFF1F1F23),
    backgroundBase: Color(0xFF18181B),
    backgroundAlt: Color(0xFF1F1F23),
    textBase: Color(0xFFEFEFF1),
    textAlt: Color(0xFFDEDEE3),
    textAlt2: Color(0xFFADADB8),
    borderBase: Color(0x7A53535F),
    buttonBackgroundSecondary: Color(0x29FFFFFF),
  );

  static HtNeutrals of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The card the banner and its details sit in.
  final Color backgroundFloat;

  /// Behind the all-time-high fill.
  final Color backgroundBase;

  /// The variant card in the details.
  final Color backgroundAlt;
  final Color textBase;
  final Color textAlt;
  final Color textAlt2;
  final Color borderBase;

  /// The track of the approaching details bar.
  final Color buttonBackgroundSecondary;

  /// The level pill, and the merge pill.
  static const pill = Color(0xCC000000);

  /// The level pill on the golden fill.
  static const pillGolden = Color(0x99000000);

  /// The landscape pill over the video.
  static const overlayPill = Color(0x80000000);
}

/// Twitch's hype train dimensions, in dp.
abstract final class HtDims {
  /// The banner's height at text scale 1 (see [htBannerHeight]).
  static const banner = 74.0;
  static const radius = 6.0;
  static const margin = 8.0;
  static const marginHalf = 4.0;
  static const marginQuarter = 2.0;
  static const pillRadius = 20.0;
  static const elevation = 4.0;

  static const icon = 24.0;
  static const iconLarge = 40.0;

  /// The all-time-high approaching trophy, cropped by the banner.
  static const trophy = 100.0;

  /// The trophies of another channel's record.
  static const trophyOther = 80.0;

  /// End strips, the approaching banner and its details.
  static const bar = 3.0;
  static const reward = 28.0;
  static const lock = 9.0;

  static const avatar = 32.0;
  static const avatarSmall = 24.0;
  static const avatarTiny = 16.0;
  static const avatarOverlap = 6.0;
  static const aura = 80.0;

  /// Past the banner's width the scrolling announcement travels this much
  /// more before it is gone.
  static const marqueeGap = 42.0;

  /// The landscape pill.
  static const videoPill = 32.0;
  static const touchTarget = 48.0;
}

/// Twitch's type styles on Inter (Roobert maps to Inter on Twitch too).
abstract final class HtType {
  static const _family = OnsetTokens.displayFamily;

  static const titleExtraSmall = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const titleDefault = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
  static const titleLarge = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );
  static const bodySmall = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static const bodySemibold = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const header = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const footnote = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  static const footnoteSemibold = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Tabular figures for the countdown and percentages.
  static const tabular = [FontFeature.tabularFigures()];
}

/// The trophy of the all-time high.
const htTrophyGold = Color(0xFFFFB300);

/// The banner's height: 74 dp, growing with the text up to twice that.
double htBannerHeight(TextScaler scaler) =>
    HtDims.banner * (scaler.scale(14) / 14).clamp(1.0, 2.0);
