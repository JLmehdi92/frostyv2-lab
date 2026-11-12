import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';

class _MockAuthStore extends Mock implements AuthStore {}

IRCMessage _line(int n) => IRCMessage.fromString(
  '@color=#00FF00;display-name=Viewer$n;id=line-$n;room-id=12345;'
  'tmi-sent-ts=${DateTime.utc(2026, 10, 30, 13, n).millisecondsSinceEpoch} '
  ':viewer$n!viewer$n@viewer$n.tmi.twitch.tv PRIVMSG #channel :line $n',
);

void main() {
  late MockChatStore chat;
  late SettingsStore settings;
  late ObservableList<IRCMessage> messages;
  late Observable<Map<String, Emote>> emotes;
  late TextEditingController text;
  late FocusNode focus;
  late ScrollController scroll;

  setUp(() {
    settings = SettingsStore.fromJson({});
    chat = fakeChatStore(settings: settings);
    messages = ObservableList<IRCMessage>();
    emotes = Observable<Map<String, Emote>>({});
    text = TextEditingController();
    focus = FocusNode();
    scroll = ScrollController();
    final auth = _MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => chat.auth).thenReturn(auth);
    final assets = chat.assetsStore;
    when(() => assets.emoteToObject).thenAnswer((_) => emotes.value);
    when(() => assets.recentEmotes).thenReturn(ObservableList<Emote>());
    when(() => assets.userEmoteToObject).thenReturn({});
    when(() => assets.userEmoteSectionToEmotes).thenReturn({});
    when(() => assets.sevenTVEmotes).thenReturn(const []);
    when(() => assets.bttvEmotes).thenReturn(const []);
    when(() => assets.ffzEmotes).thenReturn(const []);
    when(() => chat.userState).thenReturn(const USERSTATE());
    when(() => chat.renderMessages).thenAnswer((_) => messages);
    when(() => chat.messages).thenAnswer((_) => messages);
    when(() => chat.messageBuffer).thenReturn(ObservableList<IRCMessage>());
    when(() => chat.autoScroll).thenReturn(true);
    when(() => chat.scrollController).thenReturn(scroll);
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
    when(() => chat.textFieldFocusNode).thenReturn(focus);
    when(() => chat.textController).thenReturn(text);
    when(() => chat.showSendButton).thenReturn(false);
  });

  tearDown(() {
    text.dispose();
    focus.dispose();
    scroll.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: themes.dark,
          home: Scaffold(
            body: Chat(chatStore: chat, onAddChat: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChatMessage row(WidgetTester tester, IRCMessage message) =>
      tester.widget<ChatMessage>(find.byKey(ObjectKey(message)));

  Future<void> addLine(WidgetTester tester, int n) async {
    runInAction(() => messages.add(_line(n)));
    await tester.pump();
  }

  testWidgets('an unchanged row is reused when a new line arrives', (
    tester,
  ) async {
    final first = _line(1);
    messages.add(first);
    await pump(tester);
    final before = row(tester, first);

    await addLine(tester, 2);

    expect(row(tester, first), same(before));
  });

  testWidgets('a deleted line redraws as deleted', (tester) async {
    final first = _line(1);
    messages.add(first);
    await pump(tester);
    final before = row(tester, first);
    expect(find.text('Message deleted'), findsNothing);

    first.command = Command.clearMessage;
    await addLine(tester, 2);

    expect(row(tester, first), isNot(same(before)));
    expect(find.text('Message deleted'), findsOneWidget);
  });

  testWidgets('a ban, then a longer timeout, each redraw the row', (
    tester,
  ) async {
    final first = _line(1);
    messages.add(first);
    await pump(tester);
    final before = row(tester, first);

    first.command = Command.clearChat;
    await addLine(tester, 2);
    final banned = row(tester, first);
    expect(banned, isNot(same(before)));

    first.tags['ban-duration'] = '600';
    await addLine(tester, 3);
    expect(row(tester, first), isNot(same(banned)));
  });

  testWidgets('a late emote set redraws the row', (tester) async {
    final first = _line(1);
    messages.add(first);
    await pump(tester);
    final before = row(tester, first);

    runInAction(() => emotes.value = <String, Emote>{});
    await tester.pump();

    expect(row(tester, first), isNot(same(before)));
  });

  testWidgets('a settings change redraws the row', (tester) async {
    final first = _line(1);
    messages.add(first);
    await pump(tester);
    final before = row(tester, first);

    runInAction(() => settings.badgeScale = settings.badgeScale + 0.25);
    await tester.pump();

    expect(row(tester, first), isNot(same(before)));
  });
}
