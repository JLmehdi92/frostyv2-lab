import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

void main() {
  late SettingsStore store;

  setUp(() => store = SettingsStore.fromJson({}));

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ChatSettings(settingsStore: store)),
    ),
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  SettingsListSwitch row(WidgetTester tester, String title) =>
      tester.widget<SettingsListSwitch>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SettingsListSwitch),
        ),
      );

  testWidgets('chat height in portrait picks a preset', (tester) async {
    await pump(tester);
    await reveal(tester, find.text('Chat height in portrait'));
    expect(
      find.text('You can also drag the bar under the video.'),
      findsOneWidget,
    );
    await tester.tap(find.text('High'));
    await tester.pump();
    expect(store.portraitChatHeight, PortraitChatHeight.high);
    await tester.tap(find.text('Medium'));
    await tester.pump();
    expect(store.portraitChatHeight, PortraitChatHeight.medium);
  });

  testWidgets('a dragged height selects no preset', (tester) async {
    store.portraitChatHeight = PortraitChatHeight.custom;
    await pump(tester);
    await reveal(tester, find.text('Chat height in portrait'));
    expect(find.text('Custom'), findsNothing);
    await tester.tap(find.text('Low'));
    await tester.pump();
    expect(store.portraitChatHeight, PortraitChatHeight.low);
  });

  testWidgets('the double-tap layouts keep at least two on', (tester) async {
    await pump(tester);
    await reveal(tester, find.text('No chat'));
    expect(
      find.text('Double-tap the video in landscape'.toUpperCase()),
      findsOneWidget,
    );
    expect(row(tester, 'Chat over the video').value, isTrue);
    expect(row(tester, 'Chat beside the video').value, isTrue);
    expect(row(tester, 'No chat').value, isTrue);

    await tester.tap(find.text('No chat'));
    await tester.pump();
    expect(store.switchableLandscapeChatModes, [
      LandscapeChatMode.overlay,
      LandscapeChatMode.column,
    ]);
    expect(row(tester, 'No chat').value, isFalse);
    expect(row(tester, 'Chat over the video').onChanged, isNull);
    expect(row(tester, 'Chat beside the video').onChanged, isNull);
    expect(row(tester, 'No chat').onChanged, isNotNull);

    await tester.tap(find.text('Chat beside the video'));
    await tester.pump();
    expect(store.switchableLandscapeChatModes, hasLength(2));
  });
}
