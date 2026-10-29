import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/chat_filters_setting.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

void main() {
  testWidgets("Twitch's chat filters, under Edit Chat Filters in Chat", (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatSettings(settingsStore: store)),
      ),
    );

    final entry = find.text('Edit Chat Filters');
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(ChatFiltersSetting), findsOneWidget);
  });

  testWidgets('the master switch, then the four categories it enables', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatFiltersSetting(settingsStore: store)),
      ),
    );

    expect(store.chatFiltersEnabled, isFalse);
    for (final title in [
      'Discrimination',
      'Sexually Explicit Language',
      'Harassment',
      'Profanity',
    ]) {
      final tile = tester.widget<SettingsListSwitch>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SettingsListSwitch),
        ),
      );
      expect(tile.onChanged, isNull, reason: '$title is off with the master');
    }
    expect(
      find.text(
        'Select the filters you would like to block in chat across all '
        'channels. In channels you moderate, you will still see all messages.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Enable filtering in chat'));
    await tester.pump();
    expect(store.chatFiltersEnabled, isTrue);

    await tester.tap(find.text('Profanity'));
    await tester.pump();
    expect(store.chatFilterProfanity, isFalse);
    expect(store.chatFilterHarassment, isTrue);

    await tester.tap(find.text('Discrimination'));
    await tester.tap(find.text('Sexually Explicit Language'));
    await tester.tap(find.text('Harassment'));
    await tester.pump();
    expect(store.chatFilterDiscrimination, isFalse);
    expect(store.chatFilterSexual, isFalse);
    expect(store.chatFilterHarassment, isFalse);
  });

  test('resetting chat settings turns the filters back off', () {
    final store = SettingsStore.fromJson({})
      ..chatFiltersEnabled = true
      ..chatFilterProfanity = false;
    store.resetChatSettings();
    expect(store.chatFiltersEnabled, isFalse);
    expect(store.chatFilterProfanity, isTrue);
  });
}
