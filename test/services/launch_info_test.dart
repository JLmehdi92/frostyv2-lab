import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/launch_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(LaunchInfo.channel, null));

  test('reads a cold start under the native launch tile (Android)', () async {
    messenger.setMockMethodCallHandler(LaunchInfo.channel, (call) async {
      expect(call.method, 'info');
      return {'coldStart': true, 'nativeTile': true};
    });
    final info = await LaunchInfo.load();
    expect(info.coldStart, isTrue);
    expect(info.nativeTile, isTrue);
  });

  test('a warm start (process kept, activity recreated)', () async {
    messenger.setMockMethodCallHandler(
      LaunchInfo.channel,
      (call) async => {'coldStart': false, 'nativeTile': true},
    );
    expect((await LaunchInfo.load()).coldStart, isFalse);
  });

  test('without the channel (iOS): a cold start on a plain screen', () async {
    final info = await LaunchInfo.load();
    expect(info.coldStart, isTrue);
    expect(info.nativeTile, isFalse);
  });

  test('a failing channel skips the intro rather than risk it', () async {
    messenger.setMockMethodCallHandler(
      LaunchInfo.channel,
      (call) async => throw PlatformException(code: 'boom'),
    );
    final info = await LaunchInfo.load();
    expect(info.coldStart, isFalse);
  });

  test('a channel that never answers does not hold the launch', () async {
    final never = Completer<Object?>();
    messenger.setMockMethodCallHandler(
      LaunchInfo.channel,
      (call) => never.future,
    );
    final info = await LaunchInfo.load(
      timeout: const Duration(milliseconds: 10),
    );
    expect(info.coldStart, isFalse);
  });
}
