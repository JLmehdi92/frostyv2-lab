import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/cast_bridge.dart';
import 'package:onset/stores/cast_store.dart';
import 'package:onset/widgets/cast_button.dart';

import '../helpers/fake_cast_bridge.dart';
import '../helpers/l10n.dart';

const _tv = CastDevice(id: 'tv', name: 'Living room');
const _media = CastMedia(url: 'https://a/b.m3u8', title: 'Live', live: true);

Widget _sheet(
  CastStore store, {
  CastMediaSource? media,
  VoidCallback? started,
}) => Scaffold(
  body: CastSheet(
    store: store,
    media: media ?? () => _media,
    onCastStarted: started,
    searchTimeout: const Duration(seconds: 1),
  ),
);

void main() {
  late FakeCastBridge bridge;
  late CastStore store;

  setUp(() {
    bridge = FakeCastBridge();
    store = CastStore(bridge: bridge);
  });

  testWidgets('hidden where casting is not supported', (tester) async {
    final unsupported = CastStore(bridge: CastBridge(supported: false));
    await pumpLocalized(
      tester,
      Scaffold(
        body: CastButton(media: () => _media, store: unsupported),
      ),
      locale: en,
    );
    expect(find.byKey(const ValueKey('cast-button')), findsNothing);
  });

  testWidgets('says when no device answers', (tester) async {
    await pumpLocalized(tester, _sheet(store), locale: en);
    await tester.pump();
    expect(find.text('Looking for Cast devices on this network…'), findsOne);

    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text(
        'No Cast devices found. Check that your TV or speaker is on the same '
        'Wi-Fi network.',
      ),
      findsOne,
    );
  });

  testWidgets('says when the phone cannot cast', (tester) async {
    bridge.available = false;
    await pumpLocalized(tester, _sheet(store), locale: en);
    await tester.pump();
    expect(find.text('Casting isn’t available on this device.'), findsOne);
  });

  testWidgets('casts to the device picked, then pauses here', (tester) async {
    var started = 0;
    await pumpLocalized(
      tester,
      _sheet(store, started: () => started++),
      locale: en,
    );
    await tester.pump();
    bridge.devices(const [_tv]);
    await tester.pump();

    await tester.tap(find.text('Living room'));
    await tester.pump();
    expect(bridge.connected, const [_tv]);
    expect(find.byType(CircularProgressIndicator), findsOne);

    bridge.pushStatus(
      const CastStatus(CastConnection.connected, deviceName: 'Living room'),
    );
    await tester.pump();
    await tester.pump();
    expect(bridge.loaded, const [_media]);
    expect(started, 1);
  });

  testWidgets('a video not ready yet is not sent', (tester) async {
    await pumpLocalized(tester, _sheet(store, media: () => null), locale: en);
    await tester.pump();
    bridge.devices(const [_tv]);
    await tester.pump();

    await tester.tap(find.text('Living room'));
    await tester.pump();

    expect(bridge.connected, isEmpty);
    expect(find.text('Couldn’t cast: the video isn’t ready yet.'), findsOne);
  });

  testWidgets('a connected session offers to stop', (tester) async {
    bridge.current = const CastStatus(
      CastConnection.connected,
      deviceName: 'Living room',
    );
    await pumpLocalized(tester, _sheet(store), locale: en);
    await tester.pump();
    await tester.pump();

    expect(find.text('CASTING TO LIVING ROOM'), findsOne);
    await tester.tap(find.text('Stop casting'));
    await tester.pump();
    expect(bridge.disconnects, 1);
  });

  testWidgets('the button lights up while connected', (tester) async {
    bridge.pushStatus(
      const CastStatus(CastConnection.connected, deviceName: 'Living room'),
    );
    await pumpLocalized(
      tester,
      Scaffold(
        body: CastButton(media: () => _media, store: store),
      ),
      locale: en,
    );
    expect(find.byIcon(Icons.cast_connected_rounded), findsOne);
    expect(find.byTooltip('Casting to Living room'), findsOne);
  });
}
