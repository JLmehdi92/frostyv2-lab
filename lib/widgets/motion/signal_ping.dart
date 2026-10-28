import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// The live dot: a signal-coloured dot that sends out a ripple, like a radio
/// signal (the "Signal" card of the micro-animation board).
///
/// - The ripple stops in the background and off-screen ([TickerMode]); a
///   live dot left on a channel for hours costs nothing while it is not seen.
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

  const SignalPing({
    super.key,
    this.size = 8,
    this.color,
    this.maxScale = 2.6,
    this.period = const Duration(milliseconds: 1200),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      if (_controller.isAnimating) _controller.repeat();
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
      _controller.stop();
      _controller.value = 0;
    } else if (!_inFront) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
