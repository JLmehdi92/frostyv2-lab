import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';
import '../../../helpers/keyboard_animation.dart';

class MockAuthStore extends Mock implements AuthStore {}

String _line(int i) =>
    '@badge-info=;badges=;color=#FF0000;display-name=User$i;emotes=;'
    'id=msg-$i;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=${1000 + i};user-type= '
    ':user$i!user$i@user$i.tmi.twitch.tv PRIVMSG #channel :Hello there $i';

/// The channel screen's shape around its chat: the screen reads the
/// orientation above its `Scaffold` (as `VideoChat` does), the video sits
/// over the chat, and the chat fills the rest of the body.
class _ChannelLikeScreen extends StatelessWidget {
  const _ChannelLikeScreen({required this.chat});

  final Widget Function() chat;

  @override
  Widget build(BuildContext context) {
    final landscape = context.isLandscape;
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: landscape ? 0 : 220),
          Expanded(child: chat()),
        ],
      ),
    );
  }
}

void main() {
  late MockChatStore chat;
  late SettingsStore settings;
  late TextEditingController text;
  late FocusNode focus;
  late ScrollController scroll;
  late Observable<double> barHeight;
  late Observable<bool> autoScroll;

  setUp(() {
    settings = SettingsStore.fromJson({});
    chat = fakeChatStore(settings: settings);
    text = TextEditingController();
    focus = FocusNode();
    scroll = ScrollController();
    final auth = MockAuthStore();
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
    when(() => chat.renderMessages).thenReturn([
      for (var i = 0; i < 60; i++) IRCMessage.fromString(_line(i)),
    ]);
    when(() => chat.messageBuffer).thenReturn(ObservableList<IRCMessage>());
    autoScroll = Observable(true);
    when(() => chat.autoScroll).thenAnswer((_) => autoScroll.value);
    when(() => chat.resumeScroll()).thenReturn(null);
    when(() => chat.scrollController).thenReturn(scroll);
    barHeight = Observable(68.0);
    when(() => chat.bottomBarHeight).thenAnswer((_) => barHeight.value);
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

  Future<void> pump(
    WidgetTester tester,
    Size screen, {
    double navBar = 24,
  }) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1
      ..viewPadding = FakeViewPadding(bottom: navBar)
      ..padding = FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: _ChannelLikeScreen(
            chat: () => Chat(chatStore: chat, onAddChat: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, screen) in [
    ('phone portrait', const Size(412, 915)),
    ('tablet portrait', const Size(1600, 2560) / 2),
    ('tablet landscape', const Size(2560, 1600) / 2),
  ]) {
    testWidgets('$name: opening the keyboard rebuilds no chat message', (
      tester,
    ) async {
      await pump(tester, screen);
      expect(find.byType(ChatMessage), findsWidgets);
      // The input rides up with the keyboard, frame by frame.
      final inputBottoms = <double>[];
      final counts = await countRebuilds(
        () => animateKeyboard(
          tester,
          onFrame: (_) => inputBottoms.add(
            tester.getBottomLeft(find.byType(ChatBottomBar)).dy,
          ),
        ),
      );
      for (var i = 1; i < inputBottoms.length; i++) {
        expect(inputBottoms[i], lessThan(inputBottoms[i - 1]));
      }
      expect(inputBottoms.last, closeTo(screen.height - 320, 0.5));
      // Before: every message on screen was built again on every frame
      // (~40 x 20 here), with the whole screen above them.
      expect(counts.of<ChatMessage>(), 0, reason: '$counts');
      expect(counts.of<ChatBottomBar>(), 0, reason: '$counts');
      expect(tester.takeException(), isNull);
    });
  }

  // Reply while scrolled up: the reply bar grows the chat input as the
  // keyboard slides in. Without a bottom padding to change (no navigation
  // bar inset, or the side chat of a landscape screen), nothing but the
  // input's height tells the resume button and the scrollbar to move.
  for (final (name, screen) in [
    ('no navigation bar inset', const Size(412, 915)),
    ('landscape side chat', const Size(1280, 800)),
  ]) {
    testWidgets('$name: after Reply, the resume button and the scrollbar '
        'clear the reply bar', (tester) async {
      runInAction(() => autoScroll.value = false);
      await pump(tester, screen, navBar: 0);
      final button = find.text('Resume scroll');
      expect(button, findsOneWidget);
      final before = tester.getBottomLeft(button).dy;

      runInAction(() => barHeight.value = 68 + 41);
      await animateKeyboard(tester, navBar: 0);
      await tester.pumpAndSettle();

      // Before: 320, the reply bar's 41 dp missing (drawn over it).
      expect(before - tester.getBottomLeft(button).dy, 320 + 41);
      final scrollbar = tester.widget<OnsetScrollbar>(
        find.byType(OnsetScrollbar),
      );
      expect(scrollbar.padding!.bottom, 68 + 41);
    });
  }
}
