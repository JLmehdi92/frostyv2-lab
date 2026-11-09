import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/cast_bridge.dart';
import 'package:onset/stores/cast_store.dart';
import 'package:onset/widgets/cast_button.dart';

import '../helpers/fake_cast_bridge.dart';
import '../helpers/l10n.dart';

const lot9aScreenNames = [
  'cast searching',
  'cast no devices',
  'cast devices',
  'cast connected',
  'cast unavailable',
];

const _media = CastMedia(url: 'https://a/b.m3u8', title: 'Live', live: true);

Widget _sheetScreen(CastStore store) => Scaffold(
  body: Align(
    alignment: Alignment.bottomCenter,
    child: CastSheet(
      store: store,
      media: () => _media,
      searchTimeout: const Duration(seconds: 1),
    ),
  ),
);

typedef Lot9aScreen = ({
  Widget screen,
  Future<void> Function(WidgetTester) settle,
});

Lot9aScreen lot9aScreen(String name) {
  final bridge = FakeCastBridge();
  final store = CastStore(bridge: bridge);
  if (name == 'cast unavailable') bridge.available = false;
  if (name == 'cast connected') {
    bridge.current = const CastStatus(
      CastConnection.connected,
      deviceName: 'Living room TV',
    );
  }
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    if (name == 'cast devices') {
      bridge.devices(const [
        CastDevice(id: 'a', name: 'Living room TV'),
        CastDevice(id: 'b', name: 'Bedroom speaker'),
      ]);
    }
    await tester.pump();
    if (name == 'cast no devices') {
      await tester.pump(const Duration(seconds: 2));
    }
  }

  return (screen: _sheetScreen(store), settle: settle);
}

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final name in lot9aScreenNames) {
        testWidgets('$name, $at', (tester) async {
          final screen = lot9aScreen(name);
          await pumpLocalized(
            tester,
            screen.screen,
            size: size,
            textScale: scale,
          );
          await screen.settle(tester);
          await expectFrenchThroughout(
            tester,
            '$name, $at',
            content: const ['Living room TV', 'Bedroom speaker'],
          );
        });
      }
    }
  }
}
