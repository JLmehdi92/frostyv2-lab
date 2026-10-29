import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/chat.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../helpers/chat_message_harness.dart';

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  late MockChatStore chat;
  late SettingsStore settings;
  late TextEditingController text;
  late FocusNode focus;
  late ScrollController scroll;

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
    when(() => assets.showEmoteMenu).thenReturn(true);
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

  Future<void> pump(WidgetTester tester, {required Size screen}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: null,
        child: MaterialApp(
          theme: const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: screen.width > screen.height ? 400 : screen.width,
                height: screen.height,
                child: Chat(chatStore: chat, onAddChat: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tablet, open from the start: settles on the panel', (
    tester,
  ) async {
    await pump(tester, screen: const Size(1280, 854));
    expect(tester.takeException(), isNull);
    expect(find.byType(OnsetPanelSurface), findsOneWidget);
    // Only the panel's menu: none under the input.
    expect(find.byType(EmoteMenu), findsOneWidget);
    final panel = tester.getRect(find.byType(OnsetPanelSurface));
    expect(panel.size, EmoteMenu.panelSize);
    expect(panel.bottom, lessThanOrEqualTo(854 - 68));
  });

  testWidgets('phone: under the input, never a panel', (tester) async {
    await pump(tester, screen: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(OnsetPanelSurface), findsNothing);
    expect(find.byType(EmoteMenu), findsOneWidget);
  });
}
