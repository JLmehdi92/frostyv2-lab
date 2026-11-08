import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/not_interested_channels.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../helpers/l10n.dart';
import 'settings_harness.dart';

void main() {
  testWidgets('General opens the hidden channels, and each can come back', (
    tester,
  ) async {
    final settings = SettingsStore()
      ..markNotInterested('2', 'Zed')
      ..markNotInterested('1', 'alpha');
    await pumpSettings(
      tester,
      Scaffold(body: GeneralSettings(settingsStore: settings)),
      settings: settings,
      auth: FakeAuthStore(),
    );

    await tapVisible(tester, find.text('Not interested'));
    expect(find.text('2 HIDDEN CHANNELS'), findsOneWidget);
    final names = tester
        .widgetList<Text>(find.textContaining(RegExp(r'^(alpha|Zed)$')))
        .map((t) => t.data)
        .toList();
    expect(names, ['alpha', 'Zed']);

    await tester.tap(find.text('Show again').first);
    await tester.pumpAndSettle();
    expect(settings.notInterestedChannels, {'2': 'Zed'});
    expect(find.text('1 HIDDEN CHANNEL'), findsOneWidget);

    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    expect(find.text('No hidden channels'), findsOneWidget);
  });

  testWidgets('the hidden channels read in French', (tester) async {
    final settings = SettingsStore()..markNotInterested('1', 'Alpha');
    await pumpLocalized(
      tester,
      Scaffold(body: NotInterestedChannels(settingsStore: settings)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1\u00a0CHAÎNE MASQUÉE'), findsOneWidget);
    expect(englishLeaks(tester, content: ['Alpha']), isEmpty);
  });
}
