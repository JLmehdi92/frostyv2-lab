import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/cast_bridge.dart';
import 'package:onset/stores/cast_store.dart';

import '../helpers/fake_cast_bridge.dart';

const _tv = CastDevice(id: 'tv', name: 'Living room');
const _media = CastMedia(url: 'https://a/b.m3u8', title: 'Live', live: true);

void main() {
  late FakeCastBridge bridge;
  late CastStore store;

  setUp(() {
    bridge = FakeCastBridge();
    store = CastStore(bridge: bridge);
  });

  test('discovery reports whether casting is available', () async {
    bridge.available = false;
    await store.beginDiscovery();
    expect(store.available, isFalse);
  });

  test('lists the devices the system finds', () {
    bridge.devices(const [_tv]);
    expect(store.devices, const [_tv]);
  });

  test('loads the media once the session is connected', () async {
    var started = 0;
    await store.castTo(_tv, _media, onLoaded: () => started++);
    expect(bridge.connected, const [_tv]);
    expect(bridge.loaded, isEmpty);

    bridge.pushStatus(const CastStatus(CastConnection.connecting));
    expect(bridge.loaded, isEmpty);

    bridge.pushStatus(
      const CastStatus(
        CastConnection.connected,
        deviceName: 'Living room',
        deviceId: 'tv',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bridge.loaded, const [_media]);
    expect(store.casting, _media);
    expect(started, 1);
  });

  test('casts straight away to the device already connected', () async {
    bridge.pushStatus(
      const CastStatus(
        CastConnection.connected,
        deviceName: 'Living room',
        deviceId: 'tv',
      ),
    );

    expect(await store.castTo(_tv, _media), isTrue);

    expect(bridge.connected, isEmpty);
    expect(bridge.loaded, const [_media]);
  });

  test('a refused load is reported and nothing is casting', () async {
    bridge.loadAccepted = false;
    bridge.pushStatus(
      const CastStatus(
        CastConnection.connected,
        deviceName: 'Living room',
        deviceId: 'tv',
      ),
    );

    expect(await store.castTo(_tv, _media), isFalse);

    expect(store.loadFailed, isTrue);
    expect(store.casting, isNull);
  });

  test('a session that ends drops what was waiting for it', () async {
    await store.castTo(_tv, _media);
    bridge.pushStatus(CastStatus.disconnected);
    bridge.pushStatus(
      const CastStatus(
        CastConnection.connected,
        deviceName: 'Living room',
        deviceId: 'tv',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bridge.loaded, isEmpty);
  });

  test('a session that fails to start is reported', () async {
    await store.castTo(_tv, _media);
    bridge.pushStatus(const CastStatus(CastConnection.connecting));
    bridge.pushStatus(CastStatus.disconnected);
    expect(store.loadFailed, isTrue);
  });

  test('another device with the same name gets its own session', () async {
    bridge.pushStatus(
      const CastStatus(
        CastConnection.connected,
        deviceName: 'Living room',
        deviceId: 'other',
      ),
    );
    await store.castTo(_tv, _media);
    expect(bridge.connected, const [_tv]);
  });

  test('stopping ends the session', () async {
    await store.stopCasting();
    expect(bridge.disconnects, 1);
    expect(store.casting, isNull);
  });
}
