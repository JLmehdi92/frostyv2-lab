import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_notification.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';
import '../../../helpers/chat_widget_harness.dart';

const _guest = UserTwitch('777', 'guest', 'Guest', '');

void main() {
  Future<void> pump(WidgetTester tester, MockChatStore chat) =>
      tester.pumpWidget(
        Provider<ChannelEventsStore?>.value(
          value: null,
          child: MaterialApp(
            theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
            home: Scaffold(
              body: Chat(chatStore: chat, onAddChat: () {}),
            ),
          ),
        ),
      );

  testWidgets('the shared chat banner names the other channels', (
    tester,
  ) async {
    final chat = chatWidgetStore();
    final shown = Observable(true);
    when(() => chat.showSharedChatBanner).thenAnswer((_) => shown.value);
    when(() => chat.sharedChatPartners).thenReturn(const [_guest]);
    when(() => chat.sharedChatStartedNow).thenReturn(true);
    when(
      () => chat.dismissSharedChatBanner(),
    ).thenAnswer((_) => runInAction(() => shown.value = false));
    await pump(tester, chat);
    await tester.pumpAndSettle();
    expect(find.text('Shared chat started'), findsOneWidget);
    expect(
      find.text('Messages from another channel show here too.'),
      findsOneWidget,
    );
    expect(find.text('Guest'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pumpAndSettle();
    verify(chat.dismissSharedChatBanner).called(1);
    expect(find.text('Shared chat started'), findsNothing);
  });

  testWidgets('joining a chat already shared says it is shared', (
    tester,
  ) async {
    final chat = chatWidgetStore();
    when(() => chat.showSharedChatBanner).thenReturn(true);
    when(() => chat.sharedChatPartners).thenReturn(const [_guest]);
    await pump(tester, chat);
    await tester.pumpAndSettle();
    expect(find.text('This chat is shared'), findsOneWidget);
    expect(find.text('Shared chat started'), findsNothing);
  });

  testWidgets('a screen reader hears the chat expand and collapse', (
    tester,
  ) async {
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') {
          announced.add((map['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final chat = chatWidgetStore();
    final expanded = Observable(false);
    when(() => chat.expandChat).thenAnswer((_) => expanded.value);
    await pump(tester, chat);
    runInAction(() => expanded.value = true);
    await tester.pump();
    runInAction(() => expanded.value = false);
    await tester.pump();
    expect(announced, ['Chat expanded', 'Chat collapsed']);
  });

  testWidgets('chat notifications are read as they appear', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnsetNotification(message: 'Copied')),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
      findsOneWidget,
    );
  });
}
