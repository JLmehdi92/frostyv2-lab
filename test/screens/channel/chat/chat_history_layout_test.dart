import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/chat_history.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';

class _MockAuthStore extends Mock implements AuthStore {}

IRCMessage _live(int n) => IRCMessage.fromString(
  '@color=#00FF00;display-name=Viewer;id=live-$n;room-id=12345;'
  'tmi-sent-ts=${DateTime.utc(2026, 10, 30, 13, n).millisecondsSinceEpoch} '
  ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :live line $n',
);

List<IRCMessage> _history(int count) => chatHistoryLines(
  [
    for (var i = 0; i < count; i++)
      ChatHistoryMessage(
        id: 'old-$i',
        sentAt: DateTime.utc(2026, 10, 30, 12, i),
        sender: const ChatHistoryUser(
          id: '9',
          login: 'chatter',
          displayName: 'Chatter',
        ),
        fragments: [ChatHistoryFragment(text: 'old line $i')],
      ),
  ],
  channelId: '12345',
  channelLogin: 'channel',
);

/// Where chat shows: the screen, the width of the chat column in it, the
/// theme, and whether it is drawn over the video.
typedef _Place = ({
  String name,
  Size screen,
  double chatWidth,
  bool dark,
  bool overlay,
});

const _places = <_Place>[
  (
    name: 'phone portrait, chat under the video',
    screen: Size(390, 844),
    chatWidth: 390,
    dark: true,
    overlay: false,
  ),
  (
    name: 'phone portrait, light theme',
    screen: Size(390, 844),
    chatWidth: 390,
    dark: false,
    overlay: false,
  ),
  (
    name: 'phone landscape, side chat',
    screen: Size(844, 390),
    chatWidth: 300,
    dark: true,
    overlay: false,
  ),
  (
    name: 'phone landscape, overlay chat',
    screen: Size(844, 390),
    chatWidth: 340,
    dark: true,
    overlay: true,
  ),
  (
    name: 'tablet portrait',
    screen: Size(834, 1194),
    chatWidth: 834,
    dark: false,
    overlay: false,
  ),
  (
    name: 'tablet landscape, side chat',
    screen: Size(1366, 1024),
    chatWidth: 400,
    dark: true,
    overlay: false,
  ),
  (
    name: 'chat only, tablet landscape',
    screen: Size(1366, 1024),
    chatWidth: 1366,
    dark: true,
    overlay: false,
  ),
];

void main() {
  late MockChatStore chat;
  late ObservableList<IRCMessage> messages;
  late TextEditingController text;
  late FocusNode focus;
  late ScrollController scroll;

  setUp(() {
    final settings = SettingsStore.fromJson({});
    chat = fakeChatStore(settings: settings);
    messages = ObservableList<IRCMessage>();
    text = TextEditingController();
    focus = FocusNode();
    scroll = ScrollController();
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

  Future<void> pump(WidgetTester tester, _Place place) async {
    tester.view.physicalSize = place.screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    Widget chatWidget = Chat(chatStore: chat, onAddChat: () {});
    if (place.overlay) chatWidget = OverlayChatScope(child: chatWidget);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: place.dark ? themes.dark : themes.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: place.chatWidth,
                height: place.screen.height,
                child: chatWidget,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder line(String text) =>
      find.textContaining(text, findRichText: true, skipOffstage: false);

  for (final place in _places) {
    testWidgets('${place.name}: history lands above, the view stays put', (
      tester,
    ) async {
      messages.addAll([_live(1), _live(2), _live(3)]);
      await pump(tester, place);
      expect(tester.takeException(), isNull);
      final before = tester.getRect(line('live line 3'));
      expect(scroll.offset, 0);

      // History arrives after a few live lines, in one insert.
      runInAction(() => insertHistory(messages, _history(60)));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Still pinned to the newest line, which has not moved: no jump, and
      // the live lines never left the screen (no empty flash).
      expect(scroll.offset, 0);
      expect(tester.getRect(line('live line 3')), before);
      for (final n in [1, 2, 3]) {
        expect(line('live line $n'), findsOneWidget);
      }
      // The newest history line sits right above the first live line.
      final newestOld = tester.getRect(line('old line 59'));
      expect(
        newestOld.bottom,
        lessThanOrEqualTo(tester.getRect(line('live line 1')).top + 0.5),
      );
      expect(messages.map((m) => m.tags['id']).take(2), ['old-0', 'old-1']);
      expect(messages.last.tags['id'], 'live-3');

      // A new live line still lands at the bottom, followed by the view.
      runInAction(() => messages.add(_live(4)));
      await tester.pump();
      expect(scroll.offset, 0);
      final newest = tester.getRect(line('live line 4'));
      expect(
        newest.bottom,
        greaterThan(tester.getRect(line('live line 3')).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('history inserted while scrolled up does not move the view', (
    tester,
  ) async {
    messages.addAll([for (var n = 1; n <= 40; n++) _live(n)]);
    await pump(tester, _places.first);
    scroll.jumpTo(200);
    await tester.pump();
    final before = tester.getRect(line('live line 20'));

    runInAction(() => insertHistory(messages, _history(30)));
    await tester.pump();

    expect(scroll.offset, 200);
    expect(tester.getRect(line('live line 20')), before);
  });
}
