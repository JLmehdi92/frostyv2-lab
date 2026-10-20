import 'dart:async';

import 'package:flutter/widgets.dart';

/// How often followed channels are checked while the app is alive.
const kGoLiveAppInterval = Duration(seconds: 90);

/// Checks for go-lives while the app is alive: in front, in
/// picture-in-picture (inactive), or in the background while a stream
/// plays there (the media notification keeps the app running). The
/// background task keeps its 15-minute rhythm for the rest of the time.
///
/// Nothing runs once the app is gone: the timer dies with it.
class GoLivePoller {
  GoLivePoller({
    required this.check,
    required this.playingInBackground,
    this.interval = kGoLiveAppInterval,
  });

  /// One check; its failures are its own (logged, never thrown here).
  final Future<void> Function() check;

  /// Whether a stream plays with the app in the background.
  final bool Function() playingInBackground;

  final Duration interval;

  Timer? _timer;
  var _state = AppLifecycleState.resumed;
  var _checking = false;
  var _disposed = false;

  /// Whether the checks are scheduled.
  bool get running => _timer != null;

  bool get _inFront =>
      _state == AppLifecycleState.resumed ||
      _state == AppLifecycleState.inactive;

  bool get _alive =>
      !_disposed &&
      _state != AppLifecycleState.detached &&
      (_inFront || playingInBackground());

  /// Starts with the app (in front): a check now, then on schedule.
  void start() {
    _state = AppLifecycleState.resumed;
    _resume();
  }

  void onLifecycle(AppLifecycleState state) {
    _state = state;
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (!_alive) {
      _stop();
    }
  }

  void _resume() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => _tick());
    _run();
  }

  void _tick() {
    if (!_alive) {
      _stop();
      return;
    }
    _run();
  }

  void _run() {
    if (_checking) return;
    _checking = true;
    check()
        .catchError((Object e) => debugPrint('Go-live check failed: $e'))
        .whenComplete(() => _checking = false);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _stop();
  }
}
