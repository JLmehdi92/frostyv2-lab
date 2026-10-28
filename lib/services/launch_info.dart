import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the app was launched, as the platform saw it: what the launch intro
/// needs to decide whether to play, and from which frame.
class LaunchInfo {
  /// A fresh process with nothing to restore. A warm start (the process was
  /// kept and only the screen is recreated) or a state restore must not
  /// replay the intro.
  final bool coldStart;

  /// The native splash showed the launch tile in the middle of the ONSET
  /// ground (Android), so the intro starts from that tile instead of from
  /// the dot.
  final bool nativeTile;

  const LaunchInfo({required this.coldStart, required this.nativeTile});

  /// No intro.
  static const none = LaunchInfo(coldStart: false, nativeTile: false);

  @visibleForTesting
  static const channel = MethodChannel('onset/launch');

  /// Asks the platform. Never holds the launch: an answer that does not come
  /// within [timeout], or an error, means no intro.
  static Future<LaunchInfo> load({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    try {
      final info = await channel
          .invokeMapMethod<String, Object?>('info')
          .timeout(timeout);
      return LaunchInfo(
        coldStart: info?['coldStart'] == true,
        nativeTile: info?['nativeTile'] == true,
      );
    } on MissingPluginException {
      // iOS has no such channel: each process start runs main() once, behind
      // a plain launch screen.
      return const LaunchInfo(coldStart: true, nativeTile: false);
    } catch (e) {
      debugPrint('Launch info unavailable: $e');
      return none;
    }
  }
}
