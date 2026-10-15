import 'package:flutter/widgets.dart';

/// Marks a chat drawn over the video (the full-screen chat overlay), so its
/// rows can take their translucent overlay look.
class OverlayChatScope extends InheritedWidget {
  const OverlayChatScope({super.key, required super.child});

  /// Whether [context] is inside a chat drawn over the video.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OverlayChatScope>() != null;

  @override
  bool updateShouldNotify(OverlayChatScope oldWidget) => false;
}
