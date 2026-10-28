import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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

  /// Opened from the launcher. A notification or a link goes straight to
  /// what it opens (and Android 13+ may show its splash without the tile).
  final bool fromLauncher;

  const LaunchInfo({
    required this.coldStart,
    required this.nativeTile,
    this.fromLauncher = true,
  });

  /// No intro.
  static const none = LaunchInfo(coldStart: false, nativeTile: false);

  /// Whether the launch intro plays.
  bool get playsIntro => coldStart && fromLauncher;

  @visibleForTesting
  static const channel = MethodChannel('onset/launch');

  /// Where the Android 12+ splash drew its tile, in the Flutter view's
  /// logical pixels, once the platform hands the splash over (null before,
  /// and on other platforms). The intro puts its tile exactly there, so the
  /// handover cannot jump whatever the navigation bar, the device or the
  /// splash icon size.
  static final splashTile = ValueNotifier<Rect?>(null);

  /// Asks the platform. Never holds the launch: an answer that does not come
  /// within [timeout], or an error, means no intro.
  static Future<LaunchInfo> load({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    channel.setMethodCallHandler(_onPlatformCall);
    try {
      final info = await channel
          .invokeMapMethod<String, Object?>('info')
          .timeout(timeout);
      return LaunchInfo(
        coldStart: info?['coldStart'] == true,
        nativeTile: info?['nativeTile'] == true,
        fromLauncher: info?['fromLauncher'] != false,
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

  /// The splash's tile position. Answered once a frame with the tile there
  /// has been produced: the platform removes its splash on the answer.
  static Future<Object?> _onPlatformCall(MethodCall call) async {
    if (call.method != 'splashTile') throw MissingPluginException();
    final arguments = call.arguments;
    if (arguments is! Map) return false;
    double? read(String key) {
      final value = arguments[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    final x = read('x');
    final y = read('y');
    final size = read('size');
    if (x == null || y == null || size == null || size <= 0) return false;

    splashTile.value = Rect.fromCenter(
      center: Offset(x, y),
      width: size,
      height: size,
    );
    // The frame showing the tile there, then one more so it is on screen
    // (not only built) when the splash goes.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    return true;
  }
}
