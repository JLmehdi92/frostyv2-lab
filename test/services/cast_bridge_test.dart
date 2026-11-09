import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/cast_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('onset/cast-test');
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call);
        });
  }

  setUp(calls.clear);

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('does nothing where casting is not supported', () async {
    answer((_) => true);
    final bridge = CastBridge(channel: channel, supported: false);

    expect(await bridge.startDiscovery(), isFalse);
    expect(await bridge.load(_media), isFalse);
    expect(calls, isEmpty);
  });

  test('sends the media with its stream type and start', () async {
    answer((_) => true);
    final bridge = CastBridge(channel: channel, supported: true);

    expect(await bridge.load(_media), isTrue);

    expect(calls.single.method, 'load');
    expect(calls.single.arguments, {
      'url': 'https://usher.ttvnw.net/vod/1.m3u8',
      'title': 'Title',
      'subtitle': 'Channel',
      'imageUrl': null,
      'live': false,
      'startMs': 90000,
    });
  });

  test('a native failure reads as unavailable, never throws', () async {
    answer((_) => throw PlatformException(code: 'boom'));
    final bridge = CastBridge(channel: channel, supported: true);

    expect(await bridge.startDiscovery(), isFalse);
    expect(
      await bridge.connect(const CastDevice(id: 'a', name: 'TV')),
      isFalse,
    );
    expect((await bridge.status()).connection, CastConnection.disconnected);
  });

  test('reads the session state', () {
    expect(
      CastStatus.fromMap({
        'state': 'connected',
        'device': 'Living room',
        'deviceId': 'tv',
      }),
      isA<CastStatus>()
          .having((s) => s.deviceId, 'id', 'tv')
          .having((s) => s.connection, 'connection', CastConnection.connected)
          .having((s) => s.deviceName, 'device', 'Living room'),
    );
    expect(
      CastStatus.fromMap({'state': 'odd'}).connection,
      CastConnection.disconnected,
    );
    expect(CastStatus.fromMap(null).connection, CastConnection.disconnected);
  });
}

const _media = CastMedia(
  url: 'https://usher.ttvnw.net/vod/1.m3u8',
  title: 'Title',
  subtitle: 'Channel',
  live: false,
  start: Duration(seconds: 90),
);
