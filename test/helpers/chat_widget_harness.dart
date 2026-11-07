import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import 'chat_message_harness.dart';

class _MockAuthStore extends Mock implements AuthStore {}

MockChatStore chatWidgetStore({
  SettingsStore? settings,
  Stream<ChatUserCardRequest> userCards = const Stream.empty(),
}) {
  final chat = fakeChatStore(settings: settings ?? SettingsStore.fromJson({}));
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
  when(() => chat.userCardRequests).thenAnswer((_) => userCards);
  when(() => chat.showSharedChatBanner).thenReturn(false);
  when(() => chat.sharedChatStartedNow).thenReturn(false);
  return chat;
}
