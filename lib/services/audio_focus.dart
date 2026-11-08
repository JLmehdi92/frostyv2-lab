import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What happened to the app's hold on the sound.
enum AudioFocusChange {
  /// Another app (or a call) took the sound for good.
  loss,

  /// Taken for a while (a call, a voice note): it should come back.
  lossTransient,

  /// Given back after [lossTransient].
  gain,

  /// Headphones were unplugged: the sound would go to the speaker.
  noisy,
}

/// Android audio focus for the live player: holds it while the stream
/// plays, so a call or another app playing pauses the stream (and a call
/// ending resumes it), and unplugged headphones pause it.
///
/// One player holds it at a time (the last to call [request]). Native
/// failures are logged, never thrown: playback goes on without it.
class AudioFocus {
  AudioFocus({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('onset/audio-focus'),
      _supported = supported ?? Platform.isAndroid {
    if (_supported) _channel.setMethodCallHandler(_onCall);
  }

  static final shared = AudioFocus();

  final MethodChannel _channel;
  final bool _supported;

  Object? _owner;
  void Function(AudioFocusChange change)? _onChange;

  /// Takes the focus for [owner], whose [onChange] then hears its changes.
  /// False when Android refuses it for now (a call): [AudioFocusChange.gain]
  /// follows once it is given (Android 8+).
  Future<bool> request(
    Object owner,
    void Function(AudioFocusChange change) onChange,
  ) async {
    if (!_supported) return true;
    final held = _owner != null && _granted;
    _owner = owner;
    _onChange = onChange;
    if (held) return true;
    // A platform failure is not a refusal: play on without the focus.
    _granted = await _invoke('request') ?? true;
    return _granted;
  }

  /// Whether Android gave the focus (false while it is refused or lost).
  var _granted = false;

  /// Lets the focus go if [owner] holds it.
  Future<void> abandon(Object owner) async {
    if (!_supported || !identical(owner, _owner)) return;
    _owner = null;
    _onChange = null;
    _granted = false;
    await _invoke('abandon');
  }

  Future<bool?> headphonesConnected() async {
    if (!_supported) return null;
    return _invoke('headphonesConnected');
  }

  /// The platform's answer, or null when it failed (logged).
  Future<bool?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method);
    } catch (e) {
      debugPrint('AudioFocus $method failed: $e');
      return null;
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'change') return;
    final state = switch (call.arguments) {
      {'state': final String state} => state,
      _ => null,
    };
    final change = AudioFocusChange.values.where((c) => c.name == state);
    if (change.isEmpty) return;
    switch (change.first) {
      case AudioFocusChange.gain:
        _granted = true;
      case AudioFocusChange.loss:
        _granted = false;
      case AudioFocusChange.lossTransient || AudioFocusChange.noisy:
        break;
    }
    _onChange?.call(change.first);
  }
}
