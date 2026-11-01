import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';

/// The smallest share of the width the portrait video can take.
const kMinPortraitVideoScale = 0.4;

/// The narrowest the portrait video can be: its controls and the latency
/// still fit (on a phone this keeps most of the width).
const kMinPortraitVideoWidth = 300.0;

/// The smallest scale for a screen [width].
double minPortraitVideoScale(double width) => width <= kMinPortraitVideoWidth
    ? 1.0
    : max(kMinPortraitVideoScale, kMinPortraitVideoWidth / width);

/// [scale] kept between [minPortraitVideoScale] and full width.
double clampPortraitVideoScale(double scale, double width) =>
    scale.isFinite ? scale.clamp(minPortraitVideoScale(width), 1.0) : 1.0;

/// The video's height in portrait for a screen [width] at [scale].
double portraitVideoHeight(double width, double scale) =>
    width * 9 / 16 * clampPortraitVideoScale(scale, width);

/// The bar between the portrait video and chat: drag it to make the video
/// smaller (more chat) or bigger; a double tap restores full width.
class PortraitSplitHandle extends StatefulWidget {
  const PortraitSplitHandle({
    super.key,
    required this.width,
    required this.scale,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const height = 14.0;

  /// The screen width the video fills at scale 1.
  final double width;
  final double scale;

  /// Called while dragging, to follow the finger (not to be saved).
  final ValueChanged<double> onChanged;

  /// Called with the size to keep: at the end of a drag, or full width on a
  /// double tap.
  final ValueChanged<double> onChangeEnd;

  @override
  State<PortraitSplitHandle> createState() => _PortraitSplitHandleState();
}

class _PortraitSplitHandleState extends State<PortraitSplitHandle> {
  double? _dragHeight;
  double? _scale;

  double get _fullHeight => widget.width * 9 / 16;

  void _start(DragStartDetails _) {
    _dragHeight = portraitVideoHeight(widget.width, widget.scale);
    _scale = null;
  }

  void _update(DragUpdateDetails details) {
    final height = _dragHeight;
    if (height == null || widget.width <= 0) return;
    // Kept inside the limits, so dragging back answers at once.
    _dragHeight = (height + details.delta.dy).clamp(
      _fullHeight * minPortraitVideoScale(widget.width),
      _fullHeight,
    );
    final scale = clampPortraitVideoScale(
      _dragHeight! / _fullHeight,
      widget.width,
    );
    _scale = scale;
    widget.onChanged(scale);
  }

  void _end(DragEndDetails _) {
    final scale = _scale;
    _dragHeight = null;
    _scale = null;
    if (scale != null) widget.onChangeEnd(scale);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    widget.onChangeEnd(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.channelResizeVideo,
      hint: context.l10n.channelResizeVideoHint,
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
