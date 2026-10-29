import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// The live dot: a signal-coloured dot that sends out a ripple, like a radio
/// signal (the "Signal" card of the micro-animation board).
///
/// - It ripples in short bursts ([ripples], then [rest] with no ticker at
///   all): a screen left idle with live dots on it stops drawing frames
///   most of the time (each frame also redraws the shell's glass).
/// - The ripple stops in the background, off-screen ([TickerMode]) and
///   scrolled out of its list (checked before each burst); a live dot left
///   on a channel for hours costs nothing while it is not seen.
/// - Reduce motion: a still dot.
/// - It keeps its [size]: the ripple paints outside the box, inside its own
///   [RepaintBoundary], so it never shifts or repaints the row around it.
class SignalPing extends StatefulWidget {
  /// Diameter of the dot.
  final double size;

  /// Defaults to the theme's live colour (the accent).
  final Color? color;

  /// How far the ripple grows, as a multiple of [size].
  final double maxScale;

  /// One ripple.
  final Duration period;

  /// Ripples in a burst.
  final int ripples;

  /// The pause between two bursts.
  final Duration rest;

  const SignalPing({
    super.key,
    this.size = 8,
    this.color,
    this.maxScale = 2.6,
    this.period = const Duration(milliseconds: 1200),
    this.ripples = 2,
    this.rest = const Duration(seconds: 5),
  });

  @override
  State<SignalPing> createState() => _SignalPingState();
}

class _SignalPingState extends State<SignalPing>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  bool _reduced = false;

  /// The rest between two bursts (no ticker meanwhile).
  Timer? _resting;

  /// Ripples left in the burst under way.
  var _ripplesLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = reduceMotionOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(SignalPing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  bool get _inFront {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _sync() {
    if (_reduced) {
      _stop();
      _controller.value = 0;
    } else if (!_inFront) {
      _stop();
    } else if (!_controller.isAnimating && _resting == null) {
      _burst();
    }
  }

  void _stop() {
    _resting?.cancel();
    _resting = null;
    _controller.stop();
  }

  /// Starts a burst, unless the dot cannot be seen: then it looks again
  /// after a rest (a timer, no frame).
  void _burst() {
    _resting = null;
    if (!mounted || _reduced || !_inFront) return;
    if (!_inViewport()) {
      _resting = Timer(widget.rest, _burst);
      return;
    }
    _ripplesLeft = widget.ripples;
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (--_ripplesLeft > 0) {
      _controller.forward(from: 0);
    } else {
      _resting = Timer(widget.rest, _burst);
    }
  }

  /// Whether the dot is inside every scrolling viewport around it (a card
  /// scrolled out of its list is not, even while it stays built).
  bool _inViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    RenderObject? from = box;
    while (true) {
      final viewport = RenderAbstractViewport.maybeOf(from);
      if (viewport == null) return true;
      final RenderObject view = viewport;
      if (view is RenderBox && view.hasSize) {
        final area = MatrixUtils.transformRect(
          view.getTransformTo(null),
          Offset.zero & view.size,
        );
        if (!area.overlaps(rect)) return false;
      }
      from = view.parent;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resting?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: SignalPingPainter(
            progress: _controller,
            color: widget.color ?? context.frostyColors.live,
            maxScale: widget.maxScale,
          ),
        ),
      ),
    );
  }
}

/// Paints the dot and, while [progress] runs, its ripple.
class SignalPingPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final double maxScale;

  SignalPingPainter({
    required this.progress,
    required this.color,
    required this.maxScale,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final t = progress.value;
    if (t > 0 && t < 1) {
      final eased = FrostyMotion.standard.transform(t);
      canvas.drawCircle(
        center,
        radius * (1 + (maxScale - 1) * eased),
        Paint()..color = color.withValues(alpha: 0.7 * (1 - eased)),
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SignalPingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.maxScale != maxScale;
}
