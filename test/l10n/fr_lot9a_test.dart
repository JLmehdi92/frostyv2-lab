import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/pop_out.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/cast_bridge.dart';
import 'package:onset/stores/cast_store.dart';
import 'package:onset/widgets/cast_button.dart';
import 'package:onset/widgets/coach_mark.dart';
import 'package:onset/widgets/new_feature_pill.dart';

import '../helpers/fake_cast_bridge.dart';
import '../helpers/l10n.dart';

const lot9aScreenNames = [
  'cast searching',
  'cast no devices',
  'cast devices',
  'cast connected',
  'cast unavailable',
  'floating permission',
  'coach mark cast',
  'coach mark floating',
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
  if (name.startsWith('coach mark')) {
    final floating = name.endsWith('floating');
    final settings = SettingsStore.fromJson({});
    if (floating) settings.markFeatureSeen(NewFeature.cast.name);
    return (
      screen: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Align(
            alignment: floating ? Alignment.bottomRight : Alignment.topRight,
            child: Builder(
              builder: (context) => CoachMark(
                feature: floating ? NewFeature.floatingPlayer : NewFeature.cast,
                after: floating ? NewFeature.cast : null,
                message: floating
                    ? context.l10n.coachMarkPopOut
                    : context.l10n.coachMarkCast,
                settings: settings,
                child: const SizedBox.square(dimension: 44),
              ),
            ),
          ),
        ),
      ),
      settle: (tester) async {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }
  if (name == 'floating permission') {
    return (
      screen: const Scaffold(body: SizedBox.expand()),
      settle: (tester) async {
        unawaited(
          explainOverlayPermission(tester.element(find.byType(Scaffold))),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }
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
