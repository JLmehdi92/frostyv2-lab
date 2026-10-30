import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';

/// The native side clamps every playback rate it is sent: a live stream
/// only ever plays between 1.0x and the auto latency maximum, and VODs keep
/// their own 0.5–2x range. The Kotlin is not compiled by the Dart tests, so
/// its clamps are read from the source.
void main() {
  final core = File(
    'android/app/src/main/kotlin/app/onset/IvsPlayerCore.kt',
  ).readAsStringSync();

  test('a live rate is clamped to 1.0x .. the controller maximum', () {
    expect(core, contains('player.playbackRate = rate.coerceIn(1f, 1.1f)'));
    expect(LatencyController.maxLiveRate, 1.1);
    expect(LatencyController.catchUpRate, lessThan(1.1));
  });

  test('a VOD keeps its own rate range', () {
    expect(core, contains('player.playbackRate = rate.coerceIn(0.5f, 2f)'));
  });

  test('a refused live rate is reported, never thrown', () {
    expect(core, contains('result.error("rate_rejected"'));
  });
}
