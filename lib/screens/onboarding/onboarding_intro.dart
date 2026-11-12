import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/onboarding/onboarding_language_choice.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// Step 1, Intro, on a phone: the description under the
/// tile and the name (the flow draws those), the language pill, the
/// version, "Next".
///
/// [nameBottom] is where the name's underline ends, in the step's
/// coordinates; [fit] says how tight the parts sit (the flow works it out
/// with [IntroPhoneFit.of], and places the tile and the name by it).
/// [language] is the language the pill shows selected; [onLanguage] is
/// told a tap on the other one.
///
/// The language pill is the screen's key choice, so it is always shown
/// whole, above "Next": the description is the only part that scrolls,
/// when even the tightest [fit] leaves it too little room.
///
/// A phone held sideways (a landscape window: split screen, a freeform or
/// desktop window) has too little height for one column: [column] then
/// places the description, the pill, the version and "Next" in a column
/// beside the tile and the name.
class OnboardingIntroPhone extends StatelessWidget {
  const OnboardingIntroPhone({
    super.key,
    required this.nameBottom,
    required this.fit,
    required this.version,
    required this.accent,
    required this.bottomInset,
    required this.language,
    required this.onLanguage,
    required this.onNext,
    this.column,
  });

  final double nameBottom;
  final IntroPhoneFit fit;

  /// On a landscape window, the column beside the tile and the name; null
  /// on a portrait one (the parts under the name, the window wide).
  final IntroColumn? column;
  final String? version;
  final Color accent;
  final double bottomInset;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;
  final VoidCallback onNext;

  /// The language pill's width at text scale 1.
  static const languageWidth = 232.0;

  /// The space between the version and the bottom: "Next" (52) and 16
  /// above it, over the bottom inset's 24.
  static const aboveNext = 24 + 52 + 16.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final column = this.column;
    final width = column?.width ?? MediaQuery.sizeOf(context).width;
    final left = column?.left ?? 0.0;
    final right = column?.right ?? 0.0;
    return Stack(
      children: [
        // The description from the top, the pill and the version from the
        // bottom: one column, so they never overlap. The pill and the
        // version keep their room; when the description has too little,
        // it scrolls in what is left.
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              left: left,
              right: right,
              top: column?.top ?? nameBottom + fit.descriptionGap,
              bottom: bottomInset + aboveNext,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: column == null
                            ? descriptionSide
                            : IntroColumn.descriptionSide,
                      ),
                      child: StepRise(
                        order: 2,
                        child: Text(
                          context.l10n.onboardingIntroDescription,
                          textAlign: TextAlign.center,
                          style: descriptionStyle,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: fit.pillGap),
                StepRise(
                  order: 5,
                  child: SizedBox(
                    width: math.min(
                      textScaler.scale(languageWidth),
                      width - 32,
                    ),
                    child: OnboardingLanguageChoice(
                      value: language,
                      onChanged: onLanguage,
                    ),
                  ),
                ),
                if (fit.showVersion) ...[
                  SizedBox(height: fit.versionGap),
                  StepRise(
                    order: 3,
                    child: OnboardingVersion(version: version),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: left + 16,
          right: right + 16,
          bottom: bottomInset + 24,
          child: StepRise(
            order: 4,
            child: OnboardingButton(
              label: context.l10n.commonNext,
              accent: accent,
              trailing: OnboardingGlyphKind.arrowRight,
              onPressed: onNext,
            ),
          ),
        ),
      ],
    );
  }

  /// The description's margins and type.
  static const descriptionSide = 36.0;
  static const descriptionStyle = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: OnboardingColors.secondary,
  );

  /// The room the description [text] takes in [width], in [body] (the
  /// style it inherits) scaled by [textScaler]: three lines at least, more
  /// when the language or large text needs them. The flow measures it in
  /// every language and keeps the tallest, so a tap on the language pill
  /// never moves the tile.
  static double descriptionRoom(
    String text, {
    required TextStyle? body,
    required TextScaler textScaler,
    required double width,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: (body ?? const TextStyle()).merge(descriptionStyle),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    final threeLines = textScaler.scale(70);
    return height > threeLines ? height : threeLines;
  }
}

/// Where the phone's Intro puts its description, pill, version and "Next"
/// on a landscape window: a column [left] from the window's left edge to
/// [right] from its right edge, from [top] down.
@immutable
class IntroColumn {
  const IntroColumn({
    required this.left,
    required this.right,
    required this.top,
    required this.width,
  });

  final double left;
  final double right;
  final double top;

  /// Its width: the window's, less [left] and [right].
  final double width;

  /// The description's margins inside the column.
  static const descriptionSide = 8.0;

  @override
  bool operator ==(Object other) =>
      other is IntroColumn &&
      other.left == left &&
      other.right == right &&
      other.top == top &&
      other.width == width;

  @override
  int get hashCode => Object.hash(left, right, top, width);
}

/// How the phone's Intro fits its window: the tile's size and the gaps
/// between the tile, the name, the description, the language pill and the
/// version.
///
/// A roomy window gets the design ([roomy]). A short one (a small phone,
/// large text) first loses its decoration, in this order, and only as far
/// as needed: tighter gaps, a smaller tile (down to [minTileScale] of its
/// size), then no version line. When even that leaves the description too
/// little room, the description scrolls; the pill never does.
@immutable
class IntroPhoneFit {
  const IntroPhoneFit({
    required this.tileScale,
    required this.tileGap,
    required this.descriptionGap,
    required this.pillGap,
    required this.versionGap,
    required this.showVersion,
  });

  /// The design, when everything fits.
  static const roomy = IntroPhoneFit(
    tileScale: 1,
    tileGap: 30,
    descriptionGap: 31,
    pillGap: 24,
    versionGap: 16,
    showVersion: true,
  );

  /// The gaps of a short window.
  static const tight = IntroPhoneFit(
    tileScale: 1,
    tileGap: 18,
    descriptionGap: 18,
    pillGap: 16,
    versionGap: 10,
    showVersion: true,
  );

  /// The smallest the tile gets, as a share of its design size.
  static const minTileScale = 0.6;

  /// The tile's size at its design scale.
  static const tileSize = OnsetMark.designSize;

  /// The tile's scale at rest (1 at its design size).
  final double tileScale;

  /// From the tile's bottom to the name's top.
  final double tileGap;

  /// From the name's underline to the description.
  final double descriptionGap;

  /// From the description's room to the language pill.
  final double pillGap;

  /// From the language pill to the version line.
  final double versionGap;

  /// Whether the version line is shown under the pill.
  final bool showVersion;

  /// The height from the name's underline to the top of "Next"'s area:
  /// the description's [descriptionRoom], the pill and the version.
  double belowName(double descriptionRoom, TextScaler textScaler) =>
      descriptionGap +
      descriptionRoom +
      pillGap +
      OnboardingLanguageChoice.heightFor(textScaler) +
      (showVersion ? versionGap + OnboardingVersion.heightFor(textScaler) : 0);

  /// The height it needs from the tile's top to "Next"'s area, the name
  /// being [nameHeight] tall.
  double needed({
    required double nameHeight,
    required double descriptionRoom,
    required TextScaler textScaler,
  }) =>
      tileSize * tileScale +
      tileGap +
      nameHeight +
      belowName(descriptionRoom, textScaler);

  IntroPhoneFit _copyWith({double? tileScale, bool? showVersion}) =>
      IntroPhoneFit(
        tileScale: tileScale ?? this.tileScale,
        tileGap: tileGap,
        descriptionGap: descriptionGap,
        pillGap: pillGap,
        versionGap: versionGap,
        showVersion: showVersion ?? this.showVersion,
      );

  /// The roomiest fit for [room], the height from the tile's highest top
  /// to "Next"'s area, with a [nameHeight] tall name and a description
  /// needing [descriptionRoom].
  static IntroPhoneFit of({
    required double room,
    required double nameHeight,
    required double descriptionRoom,
    required TextScaler textScaler,
  }) {
    bool fits(IntroPhoneFit fit) =>
        fit.needed(
          nameHeight: nameHeight,
          descriptionRoom: descriptionRoom,
          textScaler: textScaler,
        ) <=
        room;
    if (fits(roomy)) return roomy;
    if (fits(tight)) return tight;
    // The tile as large as the room left allows.
    IntroPhoneFit shrunk(IntroPhoneFit fit) {
      final rest =
          fit.needed(
            nameHeight: nameHeight,
            descriptionRoom: descriptionRoom,
            textScaler: textScaler,
          ) -
          tileSize * fit.tileScale;
      final scale = ((room - rest) / tileSize).clamp(minTileScale, 1.0);
      return fit._copyWith(tileScale: scale);
    }

    final smaller = shrunk(tight);
    if (fits(smaller)) return smaller;
    // No version line; and the description scrolls if it still lacks room.
    return shrunk(tight._copyWith(showVersion: false));
  }

  /// The roomiest fit for the column of a landscape window ([IntroColumn]),
  /// [room] tall from its top to "Next"'s area, the description needing
  /// [descriptionRoom]: the design's gaps, else the tight ones, else no
  /// version line, the description scrolling as a last resort. The tile
  /// (beside the column) keeps [tileScale] and [tileGap].
  static IntroPhoneFit ofColumn({
    required double room,
    required double descriptionRoom,
    required TextScaler textScaler,
    required double tileScale,
    required double tileGap,
  }) {
    for (final fit in [
      roomy._copyWith(tileScale: tileScale),
      tight._copyWith(tileScale: tileScale),
    ]) {
      final column = fit._inColumn(tileGap);
      if (column.belowName(descriptionRoom, textScaler) <= room) return column;
    }
    return tight
        ._copyWith(tileScale: tileScale, showVersion: false)
        ._inColumn(tileGap);
  }

  /// This fit in a landscape column: the description at the column's top
  /// (no gap under the name, which is beside it), the tile [tileGap] above
  /// the name.
  IntroPhoneFit _inColumn(double tileGap) => IntroPhoneFit(
    tileScale: tileScale,
    tileGap: tileGap,
    descriptionGap: 0,
    pillGap: pillGap,
    versionGap: versionGap,
    showVersion: showVersion,
  );

  @override
  bool operator ==(Object other) =>
      other is IntroPhoneFit &&
      other.tileScale == tileScale &&
      other.tileGap == tileGap &&
      other.descriptionGap == descriptionGap &&
      other.pillGap == pillGap &&
      other.versionGap == versionGap &&
      other.showVersion == showVersion;

  @override
  int get hashCode => Object.hash(
    tileScale,
    tileGap,
    descriptionGap,
    pillGap,
    versionGap,
    showVersion,
  );
}

/// Step 1, Intro, on a tablet: "First launch", the description and the
/// language pill, "Next" at the bottom right (the tile, the name and the
/// version are in the brand pane).
class OnboardingIntroTablet extends StatelessWidget {
  const OnboardingIntroTablet({
    super.key,
    required this.layout,
    required this.accent,
    required this.language,
    required this.onLanguage,
    required this.onNext,
  });

  final OnboardingStepLayout layout;
  final Color accent;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final padding = layout.padding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        final size = width >= 480 ? 40.0 : 32.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                // The language pill under the description, the pair in the
                // middle; when the description is too tall for the pane
                // (large text), it scrolls and the pill stays in view.
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    padding.top,
                    padding.right,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 20,
                            children: [
                              StepRise(
                                order: 1,
                                child: Text(
                                  context.l10n.onboardingIntroEyebrow
                                      .toUpperCase(),
                                  style: OnboardingType.eyebrow,
                                ),
                              ),
                              StepRise(
                                order: 2,
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    context.l10n.onboardingIntroDescription,
                                    style: TextStyle(
                                      fontFamily: OnsetTokens.displayFamily,
                                      fontSize: size,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.035 * size,
                                      height: 1.12,
                                      color: OnboardingColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      StepRise(
                        order: 5,
                        child: SizedBox(
                          width: math.min(
                            MediaQuery.textScalerOf(
                              context,
                            ).scale(OnboardingIntroPhone.languageWidth),
                            width,
                          ),
                          child: OnboardingLanguageChoice(
                            value: language,
                            onChanged: onLanguage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                0,
                padding.right,
                padding.bottom,
              ),
              child: OnboardingFooter(
                tablet: true,
                primary: StepRise(
                  order: 4,
                  child: OnboardingButton(
                    label: context.l10n.commonNext,
                    accent: accent,
                    trailing: OnboardingGlyphKind.arrowRight,
                    onPressed: onNext,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "v5.0.5 (68)": the app's version, in tabular figures.
class OnboardingVersion extends StatelessWidget {
  const OnboardingVersion({super.key, required this.version});

  final String? version;

  /// Its line's height with text scaled by [textScaler] (12 dp Inter).
  static double heightFor(TextScaler textScaler) =>
      (textScaler.scale(12) * 1.25).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    return Text(
      version ?? '',
      textAlign: TextAlign.center,
      style: OnsetType.tabular(
        const TextStyle(fontSize: 12, color: OnboardingColors.tertiary),
      ),
    );
  }
}

/// The brand mosaic: live pictures from Twitch's top channels (when they
/// can be had; quiet stand-ins otherwise, never bundled artwork), tilted
/// 8°, drifting slowly, under a fade to black.
///
/// [tablet] fills the brand pane ([landscape]: the left one, else the top
/// one); a phone's covers the top of the intro.
class OnboardingMosaic extends StatefulWidget {
  const OnboardingMosaic({
    super.key,
    required this.streams,
    required this.tablet,
    required this.landscape,
  });

  final List<StreamTwitch> streams;
  final bool tablet;
  final bool landscape;

  @override
  State<OnboardingMosaic> createState() => _OnboardingMosaicState();
}

class _OnboardingMosaicState extends State<OnboardingMosaic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = widget.tablet;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = constraints.biggest;
            final scale = tablet ? area.width / 560 : area.width / 390;
            final innerWidth = (tablet ? 780 : 540) * scale;
            final columns = innerWidth > 900 ? 4 : 3;
            final gap = tablet ? 12.0 : 10.0;
            final tileHeight = tablet ? 132.0 : 96.0;
            final rows = ((area.height + 160) / (tileHeight + gap)).ceil() + 1;
            final live = tablet ? 7 : 4;
            final tileWidth = (innerWidth - gap * (columns - 1)) / columns;
            final streams = widget.streams;

            final grid = Column(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: [
                for (var row = 0; row < rows; row++)
                  Row(
                    spacing: gap,
                    children: [
                      for (var column = 0; column < columns; column++)
                        SizedBox(
                          width: tileWidth,
                          height: tileHeight,
                          child: _MosaicTile(
                            stream: streams.isEmpty
                                ? null
                                : streams[(row * columns + column) %
                                      streams.length],
                            live: row * columns + column == live,
                            tablet: tablet,
                          ),
                        ),
                    ],
                  ),
              ],
            );

            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 0,
                    minHeight: 0,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Transform.translate(
                      offset: Offset(
                        (tablet ? -110 : -76) * scale,
                        tablet ? -70 : -36,
                      ),
                      child: SizedBox(
                        width: innerWidth,
                        child: Transform.rotate(
                          angle: -8 * math.pi / 180,
                          child: AnimatedBuilder(
                            animation: _drift,
                            child: RepaintBoundary(child: grid),
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                -44 * Curves.easeInOut.transform(_drift.value),
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._fades(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _fades() {
    const ground = OnboardingColors.ground;
    Color shade(double alpha) => ground.withValues(alpha: alpha);
    if (!widget.tablet) {
      return [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.20, 0.58, 0.96],
              colors: [ground, shade(0.30), shade(0.40), ground],
            ),
          ),
        ),
      ];
    }
    return [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.08),
            radius: 0.62,
            stops: const [0, 0.46, 1],
            colors: [shade(0.95), shade(0.78), shade(0.40)],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.18, 0.80, 1],
            colors: [ground, shade(0), shade(0), ground],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: widget.landscape
                ? Alignment.centerLeft
                : Alignment.topCenter,
            end: widget.landscape
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            stops: const [0.76, 1],
            colors: [shade(0), ground],
          ),
        ),
      ),
    ];
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.stream,
    required this.live,
    required this.tablet,
  });

  final StreamTwitch? stream;
  final bool live;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final stream = this.stream;
    final width = tablet ? 440 : 320;
    final height = width * 9 ~/ 16;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _MosaicStandIn(),
          if (stream != null)
            OnsetCachedNetworkImage(
              imageUrl: stream.thumbnailUrl.replaceFirst(
                '-{width}x{height}',
                '-${width}x$height',
              ),
              memCacheWidth: width,
              fit: BoxFit.cover,
              color: Colors.white.withValues(alpha: live ? 0.85 : 0.6),
              colorBlendMode: BlendMode.modulate,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          if (live && stream != null)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                // At least 20 dp, taller with large text.
                constraints: const BoxConstraints(minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: OnsetTokens.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  context.l10n.commonLiveBadge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: OnsetTokens.backgroundDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tile with no picture (none loaded yet, or none to be had): the
/// surface with a faint diagonal sheen.
class _MosaicStandIn extends StatelessWidget {
  const _MosaicStandIn();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: OnboardingColors.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
        ),
      ),
    );
  }
}
