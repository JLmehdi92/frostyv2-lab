import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';

class _MockAuthStore extends Mock implements AuthStore {}

MockChatStore _chat(Stream<ChatUserCardRequest> requests) {
  final chat = fakeChatStore(settings: SettingsStore.fromJson({}));
  final auth = _MockAuthStore();
  when(() => auth.isLoggedIn).thenReturn(true);
  when(() => chat.auth).thenReturn(auth);
  final assets = chat.assetsStore;
  when(() => assets.recentEmotes).thenReturn(ObservableList<Emote>());
  when(() => assets.userEmoteToObject).thenReturn({});
  when(() => assets.userEmoteSectionToEmotes).thenReturn({});
  when(() => assets.sevenTVEmotes).thenReturn(const []);
  when(() => assets.bttvEmotes).thenReturn(const []);
  when(() => assets.ffzEmotes).thenReturn(const []);
  when(() => chat.userState).thenReturn(const USERSTATE());
  when(() => chat.renderMessages).thenReturn(const []);
  when(() => chat.messageBuffer).thenReturn(ObservableList<IRCMessage>());
  when(() => chat.autoScroll).thenReturn(true);
  when(() => chat.scrollController).thenReturn(ScrollController());
  when(() => chat.bottomBarHeight).thenReturn(68);
  when(() => chat.chatRules).thenReturn(null);
  when(() => chat.matchingEmotes).thenReturn(const []);
  when(() => chat.matchingChatters).thenReturn(const []);
  when(() => chat.matchingCommands).thenReturn(const []);
  when(() => chat.showEmoteAutocomplete).thenReturn(false);
  when(() => chat.showMentionAutocomplete).thenReturn(false);
  when(() => chat.expandChat).thenReturn(false);
  when(() => chat.restriction).thenReturn(null);
  when(() => chat.replyingToMessage).thenReturn(null);
  when(() => chat.isWaitingForAck).thenReturn(false);
  when(() => chat.isConnected).thenReturn(true);
  when(() => chat.hasConnected).thenReturn(true);
  when(() => chat.textFieldFocusNode).thenReturn(FocusNode());
  when(() => chat.textController).thenReturn(TextEditingController());
  when(() => chat.showSendButton).thenReturn(false);
  when(() => chat.userCardRequests).thenAnswer((_) => requests);
  return chat;
}

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
