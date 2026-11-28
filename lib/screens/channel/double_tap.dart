import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class VideoTaps {
  VideoTaps({required this.onSingle, required this.onDouble});

  final void Function() onSingle;
  final void Function() onDouble;

  final open = ValueNotifier(false);

  Timer? _window;
  Offset? _position;

  void tap(Offset position) {
    final previous = _position;
    final wasOpen = _window?.isActive ?? false;
    cancel();
    if (wasOpen &&
        previous != null &&
        (position - previous).distance <= kDoubleTapSlop) {
      onDouble();
      return;
    }
    _position = position;
    _window = Timer(kDoubleTapTimeout, cancel);
    open.value = true;
    onSingle();
  }

  void cancel() {
    _window?.cancel();
    _window = null;
    _position = null;
    open.value = false;
  }

  void dispose() {
    _window?.cancel();
    open.dispose();
  }
}
