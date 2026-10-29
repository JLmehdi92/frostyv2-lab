import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// The intro's text (the app's own description).
const onboardingDescription =
    'A mobile Twitch client with 7TV, BetterTTV (BTTV), and FrankerFaceZ '
    '(FFZ) support.';

/// Step 1, Intro, on a phone (board Onboarding): the description under the
/// tile and the name (the flow draws those), the version, "Next".
///
/// [nameBottom] is where the name's underline ends, in the step's
/// coordinates: the description sits 31 dp under it, as on the board.
class OnboardingIntroPhone extends StatelessWidget {
  const OnboardingIntroPhone({
    super.key,
    required this.nameBottom,
    required this.version,
    required this.accent,
    required this.bottomInset,
    required this.onNext,
  });

  final double nameBottom;
  final String? version;
  final Color accent;
  final double bottomInset;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 36,
          right: 36,
          top: nameBottom + 31,
          child: const StepRise(
            order: 2,
            child: Text(
              onboardingDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: OnboardingColors.secondary,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + 92,
          child: StepRise(order: 3, child: OnboardingVersion(version: version)),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomInset + 24,
          child: StepRise(
            order: 4,
            child: OnboardingButton(
              label: 'Next',
              accent: accent,
              trailing: OnboardingGlyphKind.arrowRight,
              onPressed: onNext,
            ),
          ),
        ),
      ],
    );
  }

  /// The height the intro needs under the name: the description (up to
  /// three lines), the version and the button.
  static const neededBelowName = 31 + 70 + 24 + 15 + 92;
}

/// Step 1, Intro, on a tablet (board OnboardingTablette): "First launch"
/// and the description, "Next" at the bottom right (the tile, the name and
/// the version are in the brand pane).
class OnboardingIntroTablet extends StatelessWidget {
  const OnboardingIntroTablet({
    super.key,
    required this.layout,
    required this.accent,
    required this.onNext,
  });

  final OnboardingStepLayout layout;
  final Color accent;
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    padding.top,
                    padding.right,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 20,
                    children: [
                      StepRise(
                        order: 1,
                        child: Text(
                          'First launch'.toUpperCase(),
                          style: OnboardingType.eyebrow,
                        ),
                      ),
                      StepRise(
                        order: 2,
                        child: Semantics(
                          header: true,
                          child: Text(
                            onboardingDescription,
                            style: TextStyle(
                              fontFamily: FrostyTokens.displayFamily,
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
                    label: 'Next',
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

  @override
  Widget build(BuildContext context) {
    return Text(
      version ?? '',
      textAlign: TextAlign.center,
      style: FrostyType.tabular(
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
                            child: grid,
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
            FrostyCachedNetworkImage(
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
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: FrostyTokens.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FrostyTokens.backgroundDark,
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
