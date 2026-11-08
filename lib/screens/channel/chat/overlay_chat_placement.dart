import 'package:flutter/foundation.dart';

@immutable
class OverlayChatPlacement {
  const OverlayChatPlacement({required this.top, required this.height});

  static const minHeight = 0.3;
  static const full = OverlayChatPlacement(top: 0, height: 1);

  final double top;
  final double height;

  factory OverlayChatPlacement.clamped({
    required double top,
    required double height,
  }) {
    final safeHeight = height.isFinite
        ? height.clamp(minHeight, 1.0).toDouble()
        : 1.0;
    final safeTop = top.isFinite
        ? top.clamp(0.0, 1.0 - safeHeight).toDouble()
        : 0.0;
    return OverlayChatPlacement(top: safeTop, height: safeHeight);
  }

  OverlayChatPlacement movedBy(double fraction) =>
      OverlayChatPlacement.clamped(top: top + fraction, height: height);

  OverlayChatPlacement resizedBy(double fraction) =>
      OverlayChatPlacement.clamped(
        top: top,
        height: (height + fraction).clamp(minHeight, 1.0 - top).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is OverlayChatPlacement &&
      other.top == top &&
      other.height == height;

  @override
  int get hashCode => Object.hash(top, height);

  @override
  String toString() => 'OverlayChatPlacement($top, $height)';
}

bool overlayChatOnLeftAfterDrag({
  required double pointerX,
  required double screenWidth,
}) => pointerX < screenWidth / 2;
