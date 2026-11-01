import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/l10n/l10n.dart';

/// What the media notification, the lock screen or headphones ask for.
enum MediaCommand { play, pause, stop }

/// The media notification's words: its channel's name in the system's
/// settings and its buttons.
typedef MediaLabels = ({
  String channel,
  String play,
  String pause,
  String stop,
});

/// The media notification's words in [l]'s language.
MediaLabels mediaLabelsOf(AppLocalizations l) => (
  channel: l.mediaChannel,
  play: l.mediaPlay,
  pause: l.mediaPause,
  stop: l.mediaStop,
);

/// The Android media notification that keeps a live stream's sound going
/// with the app in the background: a `mediaPlayback` foreground service
/// with a media session, so the lock screen and headphones control it.
///
/// One player shows it at a time (the last to call [show]); the others'
/// calls are ignored, so a replaced player cannot hide its successor's.
/// Native failures are logged, never thrown: playback goes on without it.
class BackgroundAudio {
  BackgroundAudio({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('onset/background-audio'),
      _supported = supported ?? Platform.isAndroid {
    if (_supported) _channel.setMethodCallHandler(_onCall);
  }

  /// Android 12+ refuses to start the service from the background (a
  /// stream that only starts playing behind a locked screen): the show is
  /// sent again when the app comes back to the front.
  @visibleForTesting
  Future<void> retryShow() async {
    if (!_supported || _owner == null || !_showFailed) return;
    await _sendShow();
  }

  AppLifecycleListener? _lifecycle;

  static final shared = BackgroundAudio();

  final MethodChannel _channel;
  final bool _supported;

  Object? _owner;
  void Function(MediaCommand command)? _onCommand;

  MediaLabels? _labels;

  /// The notification's words in the language the app shows now: sent
  /// with each show, and at once to a notification already up (a
  /// [LocaleSync] listener).
  Future<void> setLabels(MediaLabels labels) async {
    if (!_supported || labels == _labels) return;
    _labels = labels;
    if (_owner != null) await _invoke('labels', _labelsMap(labels));
  }

  static Map<String, String> _labelsMap(MediaLabels labels) => {
    'channel': labels.channel,
    'play': labels.play,
    'pause': labels.pause,
    'stop': labels.stop,
  };

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
    _shown = (title: title, subtitle: subtitle, playing: playing);
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(retryShow()));
    await _sendShow();
  }

  ({String title, String subtitle, bool playing})? _shown;
  var _showFailed = false;

  /// Whether a stream plays with the media notification up, which keeps
  /// the app running in the background.
  bool get playing => _owner != null && (_shown?.playing ?? false);

  Future<void> _sendShow() async {
    final shown = _shown;
    if (shown == null) return;
    _showFailed = !await _invoke('show', {
      'title': shown.title,
      'subtitle': shown.subtitle,
      'playing': shown.playing,
      // The language on screen unless told since ([setLabels]).
      'labels': _labelsMap(_labels ?? mediaLabelsOf(L10n.current)),
    });
  }

  /// Removes the notification if [owner] is showing it.
  Future<void> hide(Object owner) async {
    if (!_supported || !identical(owner, _owner)) return;
    _owner = null;
    _onCommand = null;
    _shown = null;
    _showFailed = false;
    await _invoke('hide', null);
  }

  /// False when the native side failed (logged, never thrown).
  Future<bool> _invoke(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } catch (e) {
      debugPrint('BackgroundAudio $method failed: $e');
      return false;
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
