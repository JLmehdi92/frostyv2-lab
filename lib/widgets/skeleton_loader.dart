import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// A placeholder in the exact shape of what is loading, with a discreet
/// sheen sweeping across it (the "Chargement" card of the micro-animation
/// board).
///
/// - Dark theme: [FrostyTokens.skeletonDark] with a subtle
///   [FrostyTokens.skeletonSheenDark] band, at 100°, sweeping every 1.6 s.
/// - One band for the whole screen: each skeleton places the gradient by the
///   frame clock and by its own position on screen, so a thumbnail and the
///   text lines beside it show the same band crossing them.
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
    duration: SkeletonSheen.period,
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
        ? FrostyTokens.skeletonDark
        : colorScheme.surfaceContainer;
    final highlight = dark
        ? FrostyTokens.skeletonSheenDark
        : Color.lerp(base, Colors.white, 0.6)!;

    // Sized exactly like the decorated Container it replaces: fills bounded
    // constraints, collapses to nothing where they are unbounded.
    Widget box = LimitedBox(
      maxWidth: 0,
      maxHeight: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: SkeletonSheenBox(
          ticker: _ticker,
          base: base,
          highlight: highlight,
          borderRadius:
              widget.borderRadius ??
              BorderRadius.circular(FrostyTokens.radiusSmall),
          sheen: !_reduced,
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

/// The sweep shared by every skeleton on screen.
abstract final class SkeletonSheen {
  /// One sweep.
  static const period = Duration(milliseconds: 1600);

  /// One repeat of the gradient, along the band's direction. Each [period]
  /// moves it by exactly one repeat, so the loop has no visible seam.
  static const bandWidth = 300.0;
  static const _from = -150.0;

  /// The band's direction: CSS 100°, a hair below horizontal.
  static final direction = Offset(sin(100 * pi / 180), -cos(100 * pi / 180));

  /// Where the gradient starts on screen (logical pixels, from the top-left
  /// of the view) at the frame [timestamp].
  static Offset originAt(Duration timestamp) {
    final phase =
        (timestamp.inMicroseconds % period.inMicroseconds) /
        period.inMicroseconds;
    return direction * (_from + bandWidth * Curves.easeInOut.transform(phase));
  }
}

/// Paints one skeleton block with the screen-wide band (see [SkeletonSheen]).
class SkeletonSheenBox extends LeafRenderObjectWidget {
  /// Drives the repaints; the band's position comes from the frame clock.
  final Listenable ticker;
  final Color base;
  final Color highlight;
  final BorderRadius borderRadius;
  final bool sheen;

  const SkeletonSheenBox({
    super.key,
    required this.ticker,
    required this.base,
    required this.highlight,
    required this.borderRadius,
    required this.sheen,
  });

  @override
  RenderSkeletonSheen createRenderObject(BuildContext context) =>
      RenderSkeletonSheen(
        ticker: ticker,
        base: base,
        highlight: highlight,
        borderRadius: borderRadius,
        sheen: sheen,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSkeletonSheen renderObject,
  ) {
    renderObject
      ..ticker = ticker
      ..base = base
      ..highlight = highlight
      ..borderRadius = borderRadius
      ..sheen = sheen;
  }
}

class RenderSkeletonSheen extends RenderBox {
  RenderSkeletonSheen({
    required Listenable ticker,
    required Color base,
    required Color highlight,
    required BorderRadius borderRadius,
    required bool sheen,
  }) : _ticker = ticker,
       _base = base,
       _highlight = highlight,
       _borderRadius = borderRadius,
       _sheen = sheen;

  Listenable _ticker;
  set ticker(Listenable value) {
    if (value == _ticker) return;
    if (attached) _ticker.removeListener(markNeedsPaint);
    _ticker = value;
    if (attached) _ticker.addListener(markNeedsPaint);
  }

  Color _base;
  Color get base => _base;
  set base(Color value) {
    if (value == _base) return;
    _base = value;
    markNeedsPaint();
  }

  Color _highlight;
  Color get highlight => _highlight;
  set highlight(Color value) {
    if (value == _highlight) return;
    _highlight = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  bool _sheen;
  bool get sheen => _sheen;
  set sheen(bool value) {
    if (value == _sheen) return;
    _sheen = value;
    markNeedsPaint();
  }

  /// Where the last frame put the gradient's start, on screen; null when no
  /// sheen was painted.
  @visibleForTesting
  Offset? debugLastSheenOrigin;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _ticker.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _ticker.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = _base;
    debugLastSheenOrigin = null;
    if (_sheen) {
      final onScreen = SkeletonSheen.originAt(
        SchedulerBinding.instance.currentSystemFrameTimeStamp,
      );
      // The screen point, in this box's canvas coordinates.
      final start = offset + onScreen - localToGlobal(Offset.zero);
      paint.shader = ui.Gradient.linear(
        start,
        start + SkeletonSheen.direction * SkeletonSheen.bandWidth,
        [_base, _highlight, _base],
        const [0.3, 0.5, 0.7],
        TileMode.repeated,
      );
      debugLastSheenOrigin = localToGlobal(start - offset);
    }
    context.canvas.drawRRect(_borderRadius.toRRect(offset & size), paint);
  }
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
                child: const SkeletonLoader(borderRadius: kCardBorderRadius),
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
