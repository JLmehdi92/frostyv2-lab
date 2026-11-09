import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FloatingPlayer {
  FloatingPlayer({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('onset/floating-player'),
      supported = supported ?? Platform.isAndroid;

  static final shared = FloatingPlayer();

  final MethodChannel _channel;
  final bool supported;
  void Function(bool returned)? _onClosed;

  set onClosed(void Function(bool returned)? listener) {
    _onClosed = listener;
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'closed') return;
      final arguments = call.arguments;
      final returned = arguments is Map && arguments['returned'] == true;
      _onClosed?.call(returned);
    });
  }

  Future<bool> canDrawOverlays() async =>
      await _ask<bool>('canDrawOverlays') ?? false;

  Future<bool> openPermissionSettings() async =>
      await _ask<bool>('openPermissionSettings') ?? false;

  Future<bool> start({
    required String url,
    required String title,
    required String channelLabel,
    required String closeLabel,
  }) async =>
      await _ask<bool>('start', {
        'url': url,
        'title': title,
        'channelLabel': channelLabel,
        'closeLabel': closeLabel,
      }) ??
      false;

  Future<void> stop() => _ask<Object?>('stop');

  Future<T?> _ask<T>(String method, [Object? arguments]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      debugPrint('Floating player $method failed: ${e.runtimeType}');
      return null;
    }
  }
}
