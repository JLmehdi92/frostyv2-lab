import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// A placeholder in the exact shape of what is loading, with a discreet
/// sheen sweeping across it (the "Chargement" card of the micro-animation
/// board).
///
/// - Dark theme: the board's greys (#161616 with a #232323 highlight), a
///   100° band sweeping every 1.6 s. Every skeleton on screen reads its phase
///   off the frame clock, so a whole loading list sweeps as one.
/// - The sheen is painted with a shader (no layer, no `saveLayer`); every
///   skeleton repaints in step, so they share their list's repaint boundary
///   rather than each adding a layer. Its ticker stops off-screen
///   ([TickerMode]).
/// - Reduce motion: a still block.
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({super.key, this.width, this.height, this.borderRadius});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  // Only drives repaints; the sweep's position comes from the frame clock.
  late final _ticker = AnimationController(
    vsync: this,
    duration: SkeletonSheenPainter.period,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = reduceMotionOf(context);
    if (_reduced) {
      _ticker.stop();
    } else if (!_ticker.isAnimating) {
      _ticker.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark
        ? SkeletonSheenPainter.baseDark
        : colorScheme.surfaceContainer;
    final highlight = dark
        ? SkeletonSheenPainter.highlightDark
        : Color.lerp(base, Colors.white, 0.6)!;

    // Sized exactly like the decorated Container it replaces: fills bounded
    // constraints, collapses to nothing where they are unbounded.
    Widget box = LimitedBox(
      maxWidth: 0,
      maxHeight: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: CustomPaint(
          painter: SkeletonSheenPainter(
            repaint: _ticker,
            base: base,
            highlight: highlight,
            borderRadius:
                widget.borderRadius ??
                BorderRadius.circular(FrostyTokens.radiusSmall),
            sheen: !_reduced,
          ),
        ),
      ),
    );
    if (widget.width != null || widget.height != null) {
      box = ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: widget.width,
          height: widget.height,
        ),
        child: box,
      );
    }
    return box;
  }
}

/// Paints a skeleton block and, unless [sheen] is off, the sweeping band.
class SkeletonSheenPainter extends CustomPainter {
  static const baseDark = FrostyTokens.skeletonDark;
  static const highlightDark = FrostyTokens.skeletonSheenDark;

  /// One sweep.
  static const period = Duration(milliseconds: 1600);

  /// One repeat of the gradient, along the band's direction. Each [period]
  /// moves it by exactly one repeat, so the loop has no visible seam.
  static const bandWidth = 300.0;
  static const _from = -150.0;

  /// The band's direction: CSS 100°, a hair below horizontal.
  static final _direction = Offset(sin(100 * pi / 180), -cos(100 * pi / 180));

  final Color base;
  final Color highlight;
  final BorderRadius borderRadius;
  final bool sheen;

  SkeletonSheenPainter({
    required Listenable repaint,
    required this.base,
    required this.highlight,
    required this.borderRadius,
    required this.sheen,
  }) : super(repaint: repaint);

  /// Where the band is at the frame [timestamp], in logical pixels.
  double offsetAt(Duration timestamp) {
    final phase =
        (timestamp.inMicroseconds % period.inMicroseconds) /
        period.inMicroseconds;
    return _from + bandWidth * Curves.easeInOut.transform(phase);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final paint = Paint()..color = base;
    if (sheen) {
      final start =
          _direction *
          offsetAt(SchedulerBinding.instance.currentSystemFrameTimeStamp);
      paint.shader = ui.Gradient.linear(
        start,
        start + _direction * bandWidth,
        [base, highlight, base],
        const [0.3, 0.5, 0.7],
        TileMode.repeated,
      );
    }
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(SkeletonSheenPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.sheen != sheen;
}

/// A skeleton loader with random width for text placeholders
class SkeletonText extends StatelessWidget {
  final double height;
  final double? minWidth;
  final double? maxWidth;
  final BorderRadius? borderRadius;

  const SkeletonText({
    super.key,
    required this.height,
    this.minWidth,
    this.maxWidth,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final random = Random();
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate random width based on provided constraints or reasonable defaults
    final min = minWidth ?? screenWidth * 0.3;
    final max = maxWidth ?? screenWidth * 0.8;
    final randomWidth = min + random.nextDouble() * (max - min);

    return SkeletonLoader(
      width: randomWidth,
      height: height,
      borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(4)),
    );
  }
}

/// A skeleton loader for channel list items
class ChannelSkeletonLoader extends StatelessWidget {
  final bool showSubtitle;
  final int index;

  const ChannelSkeletonLoader({
    super.key,
    this.showSubtitle = true,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Show subtitle for first 3-4 items (simulating live channels at top)
    // then single line for the rest
    final shouldShowSubtitle = showSubtitle && index < 4;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const SkeletonLoader(
        width: 32,
        height: 32,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      title: SkeletonText(height: 16, minWidth: 60, maxWidth: 140),
      subtitle: shouldShowSubtitle
          ? SkeletonText(height: 14, minWidth: 30, maxWidth: 80)
          : null,
    );
  }
}

/// A skeleton loader for category list items
class CategorySkeletonLoader extends StatelessWidget {
  const CategorySkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: 16 + MediaQuery.of(context).padding.left,
        right: 16 + MediaQuery.of(context).padding.right,
      ),
      child: Row(
        spacing: 16,
        children: [
          // Category box art skeleton (3:4 aspect ratio, 80px wide)
          SizedBox(
            width: 80,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: const SkeletonLoader(
                borderRadius: kCardBorderRadius,
              ),
            ),
          ),
          // Category name skeleton with random width (matches bodyLarge text)
          Flexible(
            child: SkeletonText(height: 18, minWidth: 80, maxWidth: 180),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for stream cards with thumbnail
class StreamCardSkeletonLoader extends StatelessWidget {
  final bool showThumbnail;
  final bool showCategory;

  const StreamCardSkeletonLoader({
    super.key,
    this.showThumbnail = true,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: showThumbnail
            ? 16 + MediaQuery.of(context).padding.left
            : 4 + MediaQuery.of(context).padding.left,
        right: showThumbnail
            ? 16 + MediaQuery.of(context).padding.right
            : 4 + MediaQuery.of(context).padding.right,
      ),
      child: Row(
        children: [
          if (showThumbnail) ...[
            // Thumbnail skeleton (16:9 aspect ratio)
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: const SkeletonLoader(
                  borderRadius: kCardBorderRadius,
                ),
              ),
            ),
          ],
          // Stream info skeleton
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  // Streamer name row
                  Row(
                    spacing: 4,
                    children: [
                      const SkeletonLoader(
                        width: 20,
                        height: 20,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      Expanded(
                        child: SkeletonText(
                          height: 16,
                          minWidth: 60,
                          maxWidth: 120,
                        ),
                      ),
                    ],
                  ),
                  // Stream title skeleton with random width
                  SkeletonText(height: 14, minWidth: 100, maxWidth: 200),
                  if (showCategory) ...[
                    // Category skeleton with random width
                    SkeletonText(height: 14, minWidth: 60, maxWidth: 120),
                  ],
                  // Viewer count skeleton with random width
                  SkeletonText(height: 14, minWidth: 50, maxWidth: 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for StreamInfoBar component
class StreamInfoBarSkeletonLoader extends StatelessWidget {
  final bool showCategory;
  final bool showUptime;
  final bool showViewerCount;
  final EdgeInsets padding;

  const StreamInfoBarSkeletonLoader({
    super.key,
    this.showCategory = true,
    this.showUptime = true,
    this.showViewerCount = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    // Show bottom row if any of the conditional elements should be displayed
    final showBottomRow = showUptime || showViewerCount || showCategory;

    return Padding(
      padding: padding,
      child: Row(
        spacing: 12,
        children: [
          // ProfilePicture skeleton (radius 16)
          const SkeletonLoader(
            width: 32,
            height: 32,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                // Top row: Streamer name + stream title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 8,
                  children: [
                    // Streamer name skeleton
                    SkeletonText(height: 14, minWidth: 60, maxWidth: 120),
                    // Stream title skeleton (flexible)
                    Flexible(
                      child: SkeletonText(
                        height: 14,
                        minWidth: 80,
                        maxWidth: 200,
                      ),
                    ),
                  ],
                ),
                // Bottom row: Live indicator, uptime, viewer count, game name
                if (showBottomRow) ...[
                  Row(
                    children: [
                      if (showUptime || showViewerCount) ...[
                        // Live indicator skeleton (matches LiveIndicator default size)
                        const SkeletonLoader(
                          width: 8.0,
                          height: 8.0,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (showUptime) ...[
                        // Uptime skeleton
                        SkeletonText(height: 14, minWidth: 40, maxWidth: 70),
                        if (showViewerCount) const SizedBox(width: 8),
                      ],
                      if (showViewerCount) ...[
                        // Viewer count icon skeleton
                        const SkeletonLoader(
                          width: 14,
                          height: 14,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                        const SizedBox(width: 4),
                        // Viewer count text skeleton
                        SkeletonText(height: 14, minWidth: 30, maxWidth: 80),
                      ],
                      if (showCategory && (showUptime || showViewerCount)) ...[
                        const SizedBox(width: 8),
                      ],
                      if (showCategory) ...[
                        // Category icon skeleton (gamepad)
                        const SkeletonLoader(
                          width: 14,
                          height: 14,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                        const SizedBox(width: 4),
                        // Category text skeleton (flexible)
                        Flexible(
                          child: SkeletonText(
                            height: 14,
                            minWidth: 60,
                            maxWidth: 140,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for large stream cards (grid layout)
class LargeStreamCardSkeletonLoader extends StatelessWidget {
  final bool showThumbnail;
  final bool showCategory;

  const LargeStreamCardSkeletonLoader({
    super.key,
    this.showThumbnail = true,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: showThumbnail ? 12 : 4,
        bottom: showThumbnail ? 12 : 4,
        left: 16 + MediaQuery.of(context).padding.left,
        right: 16 + MediaQuery.of(context).padding.right,
      ),
      child: Column(
        children: [
          if (showThumbnail) ...[
            // Thumbnail skeleton (16:9 aspect ratio)
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: kCardBorderRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: const SkeletonLoader(
                    borderRadius: kCardBorderRadius,
                  ),
                ),
              ),
            ),
          ],
          // Stream info bar skeleton - matches the actual StreamInfoBar usage
          StreamInfoBarSkeletonLoader(
            showCategory: showCategory,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for offline channel cards
class OfflineChannelCardSkeletonLoader extends StatelessWidget {
  const OfflineChannelCardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16 + MediaQuery.of(context).padding.left,
        vertical: 8,
      ),
      child: Row(
        spacing: 12,
        children: [
          // Profile picture skeleton (radius 24 = 48px diameter)
          const SkeletonLoader(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          // Channel info skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                // Channel name skeleton
                SkeletonText(height: 16, minWidth: 80, maxWidth: 160),
                // Following duration skeleton
                SkeletonText(height: 14, minWidth: 100, maxWidth: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
