import 'dart:async';

import 'package:flutter/gestures.dart';

class VideoTaps {
  VideoTaps({required this.onSingle, required this.onDouble});

  final void Function() onSingle;
  final void Function() onDouble;

  Timer? _pending;
  Offset? _position;

  void tap(Offset position) {
    final previous = _position;
    if (_pending?.isActive ?? false) {
      cancel();
      if (previous != null &&
          (position - previous).distance <= kDoubleTapSlop) {
        onDouble();
        return;
      }
      onSingle();
    }
    _position = position;
    _pending = Timer(kDoubleTapTimeout, () {
      _pending = null;
      _position = null;
      onSingle();
    });
  }

  void cancel() {
    _pending?.cancel();
    _pending = null;
    _position = null;
  }
}
