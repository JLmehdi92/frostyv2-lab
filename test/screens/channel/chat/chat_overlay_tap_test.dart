import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_widget_harness.dart';

void main() {
  late SettingsStore settings;

  setUp(() {
    settings = SettingsStore.fromJson({})
      ..fullScreen = true
      ..fullScreenChatOverlay = true;
  });

  Future<void> pump(WidgetTester tester, {required bool overlay}) async {
    final chat = Chat(
      chatStore: chatWidgetStore(settings: settings),
      onAddChat: () {},
    );
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: Scaffold(body: overlay ? OverlayChatScope(child: chat) : chat),
        ),
      ),
    );
  }

  Future<void> tapMessages(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 120));
    await tester.pump();
  }

  testWidgets('with the setting on, a tap on the overlay chat hides it', (
    tester,
  ) async {
    settings.tapToCloseOverlayChat = true;
    await pump(tester, overlay: true);
    await tapMessages(tester);
    expect(settings.fullScreenChatOverlay, isFalse);
    expect(settings.fullScreen, isTrue);
  });

  testWidgets('with the setting off, the overlay chat stays', (tester) async {
    await pump(tester, overlay: true);
    await tapMessages(tester);
    expect(settings.fullScreenChatOverlay, isTrue);
  });

  testWidgets('a chat beside the video never closes on a tap', (tester) async {
    settings.tapToCloseOverlayChat = true;
    await pump(tester, overlay: false);
    await tapMessages(tester);
    expect(settings.fullScreenChatOverlay, isTrue);
  });
}
