import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/stream_language_setting.dart';

void main() {
  testWidgets('shows the language and picks another one', (tester) async {
    final settings = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StreamLanguageSetting(settingsStore: settings)),
      ),
    );

    expect(find.text('Stream language'), findsOneWidget);
    expect(find.text('All languages'), findsOneWidget);

    await tester.tap(find.text('Stream language'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Français'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(settings.streamLanguage, 'fr');
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('All languages'), findsNothing);
  });

  testWidgets('an unknown saved language reads as every language', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({'streamLanguage': 'xx'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StreamLanguageSetting(settingsStore: settings)),
      ),
    );

    expect(find.text('All languages'), findsOneWidget);
  });
}
