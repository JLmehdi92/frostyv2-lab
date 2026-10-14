import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the media notification, the lock screen or headphones ask for.
enum MediaCommand { play, pause, stop }

/// The Android media notification that keeps a live stream's sound going
/// with the app in the background: a `mediaPlayback` foreground service
/// with a media session, so the lock screen and headphones control it.
///
/// One player shows it at a time (the last to call [show]); the others'
/// calls are ignored, so a replaced player cannot hide its successor's.
/// Native failures are logged, never thrown: playback goes on without it.
class BackgroundAudio {
  BackgroundAudio({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('frosty/background-audio'),
      _supported = supported ?? Platform.isAndroid {
    if (_supported) _channel.setMethodCallHandler(_onCall);
  }

  static final shared = BackgroundAudio();

  final MethodChannel _channel;
  final bool _supported;

  Object? _owner;
  void Function(MediaCommand command)? _onCommand;

  /// Shows (or updates) the notification for [owner]'s stream.
  Future<void> show({
    required Object owner,
    required String title,
    required String subtitle,
    required bool playing,
    required void Function(MediaCommand command) onCommand,
  }) async {
    if (!_supported) return;
    _owner = owner;
    _onCommand = onCommand;
    _title = title;
    _subtitle = subtitle;
    await _invoke('show', {
      'title': title,
      'subtitle': subtitle,
      'playing': playing,
    });
  }

  String _title = '';
  String _subtitle = '';

  /// Shows [owner]'s stream as playing or paused.
  Future<void> setPlaying(Object owner, {required bool playing}) async {
    if (!_supported || !identical(owner, _owner)) return;
    await _invoke('show', {
      'title': _title,
      'subtitle': _subtitle,
      'playing': playing,
    });
  }

  /// Removes the notification if [owner] is showing it.
  Future<void> hide(Object owner) async {
    if (!_supported || !identical(owner, _owner)) return;
    _owner = null;
    _onCommand = null;
    await _invoke('hide', null);
  }

  Future<void> _invoke(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      debugPrint('BackgroundAudio $method failed: $e');
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'command') return;
    final action = switch (call.arguments) {
      {'action': final String action} => action,
      _ => null,
    };
    final command = MediaCommand.values.where((c) => c.name == action);
    if (command.isEmpty) return;
    _onCommand?.call(command.first);
  }
}
