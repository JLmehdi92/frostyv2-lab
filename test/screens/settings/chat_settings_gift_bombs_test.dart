import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/settings/chat_settings.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

void main() {
  testWidgets('a switch under the notices collapses gift bombs', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatSettings(settingsStore: store)),
      ),
    );

    final title = find.text('Collapse gift bombs');
    await tester.scrollUntilVisible(
      title,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Shows only the first message of a mass gift, without one line per '
        'recipient.',
      ),
      findsOneWidget,
    );
    // Right under the switch that shows notices at all.
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(tester.getTopLeft(find.text('Show notices')).dy),
    );

    await tester.tap(title);
    await tester.pump();

    expect(store.collapseGiftBombs, isTrue);
  });
}
