import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('two switches under animated emotes control chat GIFs', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatSettings(settingsStore: store)),
      ),
    );

    final animated = find.text('Animated GIFs');
    final show = find.text('Show GIFs in chat');
    await scrollTo(tester, show);

    expect(animated, findsOneWidget);
    // Twitch's order: Animated Emotes, Animated GIFs, Show GIFs in chat.
    expect(
      tester.getTopLeft(animated).dy,
      greaterThan(tester.getTopLeft(find.text('Animate emotes')).dy),
    );
    expect(
      tester.getTopLeft(show).dy,
      greaterThan(tester.getTopLeft(animated).dy),
    );

    await tester.ensureVisible(animated);
    await tester.pumpAndSettle();
    await tester.tap(animated);
    await tester.pump();
    expect(store.animateGifs, isFalse);
    expect(store.showGifs, isTrue);

    await tester.ensureVisible(show);
    await tester.pumpAndSettle();
    await tester.tap(show);
    await tester.pump();
    expect(store.showGifs, isFalse);
  });
}
