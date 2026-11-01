import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockChannelEventsStore extends Mock implements ChannelEventsStore {}

void main() {
  late MockChatStore chat;
  late TextEditingController text;
  late FocusNode focus;

  setUp(() {
    chat = fakeChatStore();
    text = TextEditingController();
    focus = FocusNode();
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => chat.auth).thenReturn(auth);
    final assets = chat.assetsStore;
    when(() => assets.userEmoteToObject).thenReturn({});
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
  });

  Future<void> pump(
    WidgetTester tester, {
    Size screen = const Size(390, 844),
    bool header = false,
    bool dark = true,
    double? width,
    ChannelEventsStore? events,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    Widget bar = ChatBottomBar(chatStore: chat, onAddChat: () {});
    if (header) bar = ChatMoreInHeader(child: bar);
    if (width != null) bar = SizedBox(width: width, child: bar);
    await tester.pumpWidget(
      Provider<ChannelEventsStore?>.value(
        value: events,
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: bar),
          ),
        ),
      ),
    );
  }

  /// The input row with its padding, which must fit in the 68 dp the chat
  /// list keeps free for the bar (ChatStore.bottomBarHeight).
  double inputRowHeight(WidgetTester tester) => tester
      .getSize(
        find
            .ancestor(
              of: find.byType(ChatMoreButton),
              matching: find.byType(Padding),
            )
            .first,
      )
      .height;

  testWidgets('the message pill, then "⋯" for the chat details', (
    tester,
  ) async {
    for (final dark in [true, false]) {
      await pump(tester, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.byTooltip('Emote menu'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      final more = tester.getRect(find.byTooltip('More'));
      expect(more.size, const Size(44, 44));
      // On the right of the message box.
      expect(more.right, closeTo(390 - 12, 0.5));
      final field = tester.getRect(find.byType(ExtendedTextField));
      // No points here (signed out of them): no empty gap for them.
      expect(more.left - field.right, closeTo(8, 0.5));
      expect(field.height, closeTo(44, 1));
      expect(inputRowHeight(tester), lessThanOrEqualTo(68));
    }
  });

  testWidgets('send sits inside the pill once there is text', (tester) async {
    when(() => chat.showSendButton).thenReturn(true);
    await pump(tester);
    final send = tester.getRect(find.byTooltip('Send'));
    final field = tester.getRect(find.byType(ExtendedTextField));
    expect(field.contains(send.center), isTrue);
    // The details stay one tap away.
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets("a header's \"⋯\" replaces the input row's", (tester) async {
    await pump(tester, screen: const Size(1280, 854), header: true);
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('a tablet in portrait has the larger input', (tester) async {
    await pump(tester, screen: const Size(854, 1280));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byTooltip('More')), const Size(48, 48));
    expect(
      tester.getRect(find.byType(ExtendedTextField)).height,
      closeTo(48, 1),
    );
    // Within the room the chat list keeps free for the bar.
    expect(inputRowHeight(tester), 68);
  });

  testWidgets('the narrowest side chat shrinks its controls, no overflow', (
    tester,
  ) async {
    chat.settings.chatWidth = 0.2;
    final events = MockChannelEventsStore();
    when(() => events.channelId).thenReturn('12345');
    when(
      () => events.points,
    ).thenReturn(const CommunityPointsContext(balance: 1250000));
    // 20 % of a small landscape phone.
    await pump(
      tester,
      screen: const Size(640, 360),
      width: 128,
      events: events,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1.3M'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Send a message'), findsOneWidget);
  });

  testWidgets('a narrow landscape side chat keeps its pencil', (tester) async {
    chat.settings.chatWidth = 0.2;
    await pump(tester, screen: const Size(844, 390));
    expect(find.byTooltip('Send a message'), findsOneWidget);
    expect(find.byType(ExtendedTextField), findsNothing);
    expect(find.byTooltip('More'), findsOneWidget);
  });
}
