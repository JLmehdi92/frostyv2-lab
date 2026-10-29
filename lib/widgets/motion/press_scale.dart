import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// Sinks [child] to [FrostyMotion.pressScale] the moment a finger touches it,
/// and springs it back when the finger lifts.
///
/// It only listens to raw pointers (a [Listener]), so it never takes part in
/// the gesture arena: wrap any tappable card (an [InkWell], a
/// [GestureDetector]) and its taps, long presses and scrolling behave exactly
/// as before. A finger that starts scrolling lets go of the press.
///
/// The release is a spring that starts from wherever the press got to, so a
/// quick tap never jumps. Nothing moves under reduce motion.
class PressScale extends StatefulWidget {
  final Widget child;

  /// How far the child sinks.
  final double scale;

  /// When false, the child does not react (a disabled card).
  final bool enabled;

  const PressScale({
    super.key,
    required this.child,
    this.scale = FrostyMotion.pressScale,
    this.enabled = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  // Unbounded: the release spring may overshoot 1 by a hair.
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);

  int? _pointer;
  Offset? _downAt;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null || !widget.enabled || reduceMotionOf(context)) {
      return;
    }
    _pointer = event.pointer;
    _downAt = event.position;
    _controller.animateTo(
      widget.scale,
      duration: FrostyMotion.pressDuration,
      curve: FrostyMotion.standard,
    );
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _downAt == null) return;
    if ((event.position - _downAt!).distance > kTouchSlop) _release();
  }

  void _onUp(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() {
    _pointer = null;
    _downAt = null;
    _controller.animateWith(
      SpringSimulation(
        FrostyMotion.springMomentum,
        _controller.value,
        1,
        _controller.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pointer != null) _release();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
