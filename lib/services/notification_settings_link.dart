import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationSettingsLink {
  NotificationSettingsLink({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('onset/notification-settings'),
      _supported = supported ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _supported;

  Future<void> listen(void Function() onOpen) async {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') onOpen();
    });
    try {
      if (await _channel.invokeMethod<bool>('consumeLaunch') == true) onOpen();
    } catch (e) {
      debugPrint('Notification settings link unavailable: ${e.runtimeType}');
    }
  }
}
