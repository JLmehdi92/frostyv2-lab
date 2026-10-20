import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the active network costs data (mobile data, a metered hotspot),
/// asked of Android on the `frosty/network` channel, for settings like
/// Twitch's "Wi-Fi Only" autoplay. Elsewhere, or without an answer, it is
/// unknown (null).
class NetworkMetering {
  NetworkMetering({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('frosty/network'),
      _supported = supported ?? Platform.isAndroid;

  static final shared = NetworkMetering();

  final MethodChannel _channel;
  final bool _supported;

  Future<bool?> isMetered() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<bool>('isMetered');
    } catch (e) {
      debugPrint('Network metering unknown: ${e.runtimeType}');
      return null;
    }
  }
}
