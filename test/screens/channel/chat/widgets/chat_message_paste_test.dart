import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_message_harness.dart';

const _line =
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=msg-1;room-id=12345;user-id=55555 '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :hello there';

void main() {
  Future<TextEditingController> pasteWith(
    WidgetTester tester,
    SettingsStore settings,
  ) async {
    captureClipboard(tester);
    final store = fakeChatStore(settings: settings);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    when(() => store.textController).thenReturn(controller);
    when(() => store.safeRequestFocus()).thenReturn(null);
    await pumpChatMessage(tester, IRCMessage.fromString(_line), store);

    await tester.longPress(find.byType(ChatMessage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy message and paste'));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('pastes while chat is synced with the stream latency', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({})
      ..showVideo = true
      ..autoSyncChatDelay = true
      ..syncedChatDelay = 3;

    final controller = await pasteWith(tester, settings);

    expect(controller.text, 'hello there');
    expect(find.textContaining('Chatting is disabled'), findsNothing);
  });

  testWidgets('pastes with a manual message delay too', (tester) async {
    final settings = SettingsStore.fromJson({})
      ..showVideo = true
      ..autoSyncChatDelay = false
      ..chatDelay = 5;

    final controller = await pasteWith(tester, settings);

    expect(controller.text, 'hello there');
  });
}
