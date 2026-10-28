import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/launch_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(LaunchInfo.channel, null);
    LaunchInfo.splashTile.value = null;
  });

  test('reads a cold start under the native launch tile (Android)', () async {
    messenger.setMockMethodCallHandler(LaunchInfo.channel, (call) async {
      expect(call.method, 'info');
      return {'coldStart': true, 'nativeTile': true, 'fromLauncher': true};
    });
    final info = await LaunchInfo.load();
    expect(info.coldStart, isTrue);
    expect(info.nativeTile, isTrue);
    expect(info.playsIntro, isTrue);
  });

  test('opened from a notification or a link: no intro', () async {
    messenger.setMockMethodCallHandler(
      LaunchInfo.channel,
      (call) async => {
        'coldStart': true,
        'nativeTile': true,
        'fromLauncher': false,
      },
    );
    final info = await LaunchInfo.load();
    expect(info.coldStart, isTrue);
    expect(info.playsIntro, isFalse);
  });

  test('a warm start (process kept, activity recreated)', () async {
    messenger.setMockMethodCallHandler(
      LaunchInfo.channel,
      (call) async => {'coldStart': false, 'nativeTile': true},
    );
    final info = await LaunchInfo.load();
    expect(info.coldStart, isFalse);
    expect(info.playsIntro, isFalse);
  });

  test('without the channel (iOS): a cold start on a plain screen', () async {
    final info = await LaunchInfo.load();
    expect(info.coldStart, isTrue);
    expect(info.nativeTile, isFalse);
    expect(info.playsIntro, isTrue);
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

  group('splash handover (Android 12+)', () {
    Future<Object?> send(String method, Object? arguments) {
      final reply = Completer<Object?>();
      messenger.handlePlatformMessage(
        LaunchInfo.channel.name,
        LaunchInfo.channel.codec.encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (data) => reply.complete(
          data == null ? null : LaunchInfo.channel.codec.decodeEnvelope(data),
        ),
      );
      return reply.future;
    }

    testWidgets('takes the tile where the splash drew it, then lets it go', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(
        LaunchInfo.channel,
        (call) async => {'coldStart': true},
      );
      await LaunchInfo.load();
      // Not answered until a frame with the tile there has been drawn.
      var answered = false;
      final reply = send('splashTile', {'x': 195.0, 'y': 434.0, 'size': 60.0})
        ..then((_) => answered = true);
      await tester.pump();
      expect(
        LaunchInfo.splashTile.value,
        Rect.fromCenter(center: const Offset(195, 434), width: 60, height: 60),
      );
      expect(answered, isFalse);
      await tester.pump();
      await tester.pump();
      expect(answered, isTrue);
      expect(await reply, isTrue);
    });

    testWidgets('ignores a malformed position', (tester) async {
      messenger.setMockMethodCallHandler(
        LaunchInfo.channel,
        (call) async => {'coldStart': true},
      );
      await LaunchInfo.load();
      final reply = send('splashTile', {
        'x': double.nan,
        'y': 1.0,
        'size': 60.0,
      });
      await tester.pump();
      await tester.pump();
      expect(LaunchInfo.splashTile.value, isNull);
      expect(await reply, isFalse);
    });
  });
}
