import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The smallest the portrait video can be made, as a share of full width.
const kMinPortraitVideoScale = 0.4;

/// [scale] kept between [kMinPortraitVideoScale] and full width.
double clampPortraitVideoScale(double scale) =>
    scale.isFinite ? scale.clamp(kMinPortraitVideoScale, 1.0) : 1.0;

/// The video's height in portrait for a screen [width] at [scale].
double portraitVideoHeight(double width, double scale) =>
    width * 9 / 16 * clampPortraitVideoScale(scale);

/// The bar between the portrait video and chat: drag it to make the video
/// smaller (more chat) or bigger; a double tap restores full width.
class PortraitSplitHandle extends StatefulWidget {
  const PortraitSplitHandle({
    super.key,
    required this.width,
    required this.scale,
    required this.onChanged,
  });

  static const height = 14.0;

  /// The screen width the video fills at scale 1.
  final double width;
  final double scale;

  /// Called while dragging and on a double tap.
  final ValueChanged<double> onChanged;

  @override
  State<PortraitSplitHandle> createState() => _PortraitSplitHandleState();
}

class _PortraitSplitHandleState extends State<PortraitSplitHandle> {
  double? _dragHeight;

  void _start(DragStartDetails _) =>
      _dragHeight = portraitVideoHeight(widget.width, widget.scale);

  void _update(DragUpdateDetails details) {
    final height = _dragHeight;
    if (height == null || widget.width <= 0) return;
    _dragHeight = height + details.delta.dy;
    widget.onChanged(
      clampPortraitVideoScale(_dragHeight! / (widget.width * 9 / 16)),
    );
  }

  void _end(DragEndDetails _) => _dragHeight = null;

  void _reset() {
    HapticFeedback.lightImpact();
    widget.onChanged(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Resize video',
      hint: 'Drag to change the video size, double tap for full width',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _start,
        onVerticalDragUpdate: _update,
        onVerticalDragEnd: _end,
        onDoubleTap: _reset,
        child: SizedBox(
          height: PortraitSplitHandle.height,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
