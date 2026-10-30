import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  testWidgets('a switch under the notices collapses gift bombs of five or '
      'more', (tester) async {
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
        'Folds a gift bomb of five subs or more into its first line; tap '
        '"recipients" to see who got one.',
      ),
      findsOneWidget,
    );
    // Right under the switch that shows notices at all.
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(tester.getTopLeft(find.text('Show notices')).dy),
    );

    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(store.collapseGiftBombs, isTrue);
    await tester.tap(title);
    await tester.pump();

    expect(store.collapseGiftBombs, isFalse);
  });

  testWidgets('community highlights mention gift bombs', (tester) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatSettings(settingsStore: store)),
      ),
    );

    final subtitle = find.text(
      'Shows polls, predictions, pinned messages, gift bombs and raids '
      'above chat.',
    );
    await tester.scrollUntilVisible(
      subtitle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(subtitle, findsOneWidget);
  });
}
