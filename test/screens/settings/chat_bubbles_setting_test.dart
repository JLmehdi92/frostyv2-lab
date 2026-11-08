import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/chat_bubbles_setting.dart';

import '../../helpers/l10n.dart';

void main() {
  testWidgets('the row counts the types; the sheet toggles each', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({});
    await pumpLocalized(
      tester,
      Scaffold(body: ChatBubblesSetting(settingsStore: settings)),
      locale: en,
    );
    expect(find.text('Event bubbles'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.text('Event bubbles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raids'));
    await tester.pump();
    await tester.tap(find.text('Subs'));
    await tester.pump();
    expect(settings.chatBubbleEvents, ['subs', 'raids']);
    await tester.tap(find.text('Raids'));
    await tester.pump();
    expect(settings.chatBubbleEvents, ['subs']);

    Navigator.of(tester.element(find.byType(ChatBubblesSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text('1 type'), findsOneWidget);

    settings.resetChatSettings();
    await tester.pump();
    expect(settings.chatBubbleEvents, isEmpty);
  });
}
