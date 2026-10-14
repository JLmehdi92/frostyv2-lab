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
/// pointers, so it never takes a gesture from the video's other ones
/// (tap, double tap, swipe down to picture-in-picture).
class PinchToFill extends StatefulWidget {
  const PinchToFill({super.key, required this.onPinch, required this.child});

  /// Called once per pinch, with true to fill and false to fit.
  final ValueChanged<bool> onPinch;
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
    if (_pointers.length == 2) {
      _startDistance = _distance;
      _decided = false;
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
    if (_pointers.length < 2) _startDistance = null;
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
