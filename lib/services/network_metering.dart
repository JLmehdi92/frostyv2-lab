import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the active network costs data (mobile data, a metered hotspot),
/// asked of Android on the `onset/network` channel, for settings like
/// Twitch's "Wi-Fi Only" autoplay. Elsewhere, or without an answer, it is
/// unknown (null).
class NetworkMetering {
  NetworkMetering({
    MethodChannel? channel,
    EventChannel? events,
    bool? supported,
  }) : _channel = channel ?? const MethodChannel('onset/network'),
       _events = events ?? const EventChannel('onset/network/metered'),
       _supported = supported ?? Platform.isAndroid;

  static final shared = NetworkMetering();

  final MethodChannel _channel;
  final EventChannel _events;
  final bool _supported;

  /// [isMetered]'s answer each time it changes (leaving Wi-Fi for mobile
  /// data), while listened to; the same answer twice in a row comes once.
  /// Nothing elsewhere. An error is logged and skipped: the answers after
  /// it still come.
  Stream<bool?> changes() {
    if (!_supported) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map((value) => value is bool ? value : null)
        .handleError((Object e) {
          debugPrint('Network changes unknown: ${e.runtimeType}');
        })
        .distinct();
  }

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
