import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';
import '../../../helpers/chat_widget_harness.dart';

MockChatStore _chat(Stream<ChatUserCardRequest> requests) =>
    chatWidgetStore(userCards: requests);

void main() {
  testWidgets('a /user request opens that user’s card, from the shown chat', (
    tester,
  ) async {
    final first = StreamController<ChatUserCardRequest>.broadcast();
    final second = StreamController<ChatUserCardRequest>.broadcast();
    addTearDown(first.close);
    addTearDown(second.close);
    final opened = <(ChatStore, String)>[];
    Widget app(ChatStore store) => Provider<ChannelEventsStore?>.value(
      value: null,
      child: MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Scaffold(
          body: Chat(
            chatStore: store,
            onAddChat: () {},
            openUserCard: (context, {required chatStore, required user}) =>
                opened.add((chatStore, user.login)),
          ),
        ),
      ),
    );

    final one = _chat(first.stream);
    await tester.pumpWidget(app(one));
    first.add((login: 'friend', id: '9', displayName: 'Friend'));
    await tester.pump();
    expect(opened, [(one, 'friend')]);

    final two = _chat(second.stream);
    await tester.pumpWidget(app(two));
    first.add((login: 'stale', id: '1', displayName: 'Stale'));
    second.add((login: 'other', id: '2', displayName: 'Other'));
    await tester.pump();
    expect(opened, [(one, 'friend'), (two, 'other')]);
  });
}
