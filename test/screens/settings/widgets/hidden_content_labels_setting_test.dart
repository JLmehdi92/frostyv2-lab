import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/hidden_content_labels_setting.dart';

void main() {
  testWidgets('picks the labels whose streams are hidden', (tester) async {
    final settings = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HiddenContentLabelsSetting(settingsStore: settings),
        ),
      ),
    );

    expect(find.text('Hide labeled streams'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.text('Hide labeled streams'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gambling'));
    await tester.pump();
    await tester.tap(find.text('Sexual Themes'));
    await tester.pump();

    expect(settings.hiddenContentLabels, ['Gambling', 'SexualThemes']);

    await tester.tap(find.text('Gambling'));
    await tester.pump();
    expect(settings.hiddenContentLabels, ['SexualThemes']);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Sexual Themes'), findsOneWidget, reason: 'subtitle');
  });

  testWidgets('several labels are counted', (tester) async {
    final settings = SettingsStore.fromJson({
      'hiddenContentLabels': ['Gambling', 'MatureGame'],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HiddenContentLabelsSetting(settingsStore: settings),
        ),
      ),
    );

    expect(find.text('2 labels'), findsOneWidget);
  });
}
