import 'package:flutter/widgets.dart';

/// How far two fingers must spread (or close) before a pinch counts.
const kPinchThreshold = 1.15;

/// What a two-finger pinch asks for: true to fill the screen (spread),
/// false to fit the video (close), null while it is too small to tell.
bool? pinchVerdict(double startDistance, double distance) {
  if (startDistance <= 0) return null;
  final ratio = distance / startDistance;
  if (ratio >= kPinchThreshold) return true;
  if (ratio <= 1 / kPinchThreshold) return false;
  return null;
}

/// Pinch to fill or fit the video, like Twitch's player. It reads raw
/// pointers, so it never takes a gesture away from the others; they read
/// [pinching] instead to stand down (no swipe to picture-in-picture, no
/// tap) while two fingers are on the video.
class PinchToFill extends StatefulWidget {
  const PinchToFill({
    super.key,
    required this.onPinch,
    required this.pinching,
    required this.child,
  });

  /// Called once per pinch, with true to fill and false to fit.
  final ValueChanged<bool> onPinch;

  /// True from a second finger down until the next gesture starts with one
  /// finger: a tap or swipe that ends a pinch still reads it as a pinch.
  final ValueNotifier<bool> pinching;
  final Widget child;

  @override
  State<PinchToFill> createState() => _PinchToFillState();
}

class _PinchToFillState extends State<PinchToFill> {
  final _pointers = <int, Offset>{};
  double? _startDistance;
  var _decided = false;

  double get _distance {
    final points = _pointers.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    switch (_pointers.length) {
      case 1:
        // A new gesture.
        widget.pinching.value = false;
      case 2:
        widget.pinching.value = true;
        _startDistance = _distance;
        _decided = false;
      default:
        // Three fingers or more: not a pinch until back to two.
        _startDistance = null;
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _startDistance;
    if (_pointers.length != 2 || start == null || _decided) return;
    final fill = pinchVerdict(start, _distance);
    if (fill == null) return;
    _decided = true;
    widget.onPinch(fill);
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    // Back to two fingers: measure from where they are now.
    _startDistance = _pointers.length == 2 ? _distance : null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
