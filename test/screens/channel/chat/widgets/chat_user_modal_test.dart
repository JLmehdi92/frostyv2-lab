import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_moderation_bar.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockChatStore store;
  late MockTwitchApi api;
  late TextEditingController text;

  setUp(() {
    api = MockTwitchApi();
    when(() => api.getUser(id: any(named: 'id'))).thenAnswer(
      (_) async => UserTwitch(
        '33',
        'troll',
        'Troll',
        '',
        createdAt: DateTime(2019, 3, 4, 12),
      ),
    );
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => const UserTwitch('33', 'troll', 'Troll', ''));
    when(
      () => api.getFollowedAt(
        broadcasterId: any(named: 'broadcasterId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => DateTime(2023, 1, 12, 12));

    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => auth.user).thenReturn(user);
    when(
      () => user.details,
    ).thenReturn(const UserTwitch('1', 'mod', 'Mod', ''));

    text = TextEditingController();
    store = fakeChatStore();
    when(() => store.auth).thenReturn(auth);
    when(() => store.twitchApi).thenReturn(api);
    when(() => store.whispers).thenReturn(null);
    when(() => store.canModerate).thenReturn(true);
    when(() => store.textController).thenReturn(text);
    when(() => store.safeRequestFocus()).thenReturn(null);
    when(() => store.messages).thenReturn(
      ObservableList.of([
        IRCMessage.fromString(
          '@display-name=Troll;user-id=33;id=a :troll!troll@troll.tmi.twitch.tv '
          'PRIVMSG #channel :clip that',
        ),
      ]),
    );
  });

  Future<BuildContext> pump(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext inside;
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      Provider<TwitchApi>.value(
        value: api,
        child: MaterialApp(
          theme: brightness == Brightness.dark ? themes.dark : themes.light,
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(child: SizedBox.expand()),
                SizedBox(
                  width: size.width > size.height ? 400 : size.width,
                  child: PanelRegion(
                    child: Builder(
                      builder: (context) {
                        inside = context;
                        return const SizedBox.expand();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return inside;
  }

  Future<void> open(
    WidgetTester tester,
    BuildContext context, {
    Rect? anchor,
  }) async {
    showChatUserCard(
      context,
      chatStore: store,
      username: 'troll',
      userId: '33',
      displayName: 'Troll',
      anchor: anchor,
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('phone: the board sheet ($brightness)', (tester) async {
      final context = await pump(
        tester,
        const Size(390, 844),
        brightness: brightness,
      );
      await open(tester, context);
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.getSize(find.byType(ChatUserModal)).height,
        ChatUserModal.sheetHeight,
      );
      for (final tooltip in ['Reply', 'Profile', 'More']) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }
      // Logged in without whispers: no whisper button.
      expect(find.byTooltip('Whisper'), findsNothing);
      expect(find.text('Account created Mar 4, 2019'), findsOneWidget);
      expect(find.text('Following since Jan 12, 2023'), findsOneWidget);
      expect(find.byType(ChatModerationBar), findsOneWidget);
      expect(find.text('RECENT MESSAGES'), findsOneWidget);
    });
  }

  testWidgets('reply puts the @name in the input and closes', (tester) async {
    final context = await pump(tester, const Size(390, 844));
    await open(tester, context);
    await tester.tap(find.byTooltip('Reply'));
    await tester.pumpAndSettle();
    expect(text.text, '@troll ');
    expect(find.byType(ChatUserModal), findsNothing);
    verify(() => store.safeRequestFocus()).called(1);
  });

  testWidgets('More is a sheet over the card, in the panel tone', (
    tester,
  ) async {
    final context = await pump(tester, const Size(390, 844));
    await open(tester, context);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.byType(UserActionsModal), findsOneWidget);
    final sheets = tester.widgetList<BottomSheet>(find.byType(BottomSheet));
    expect(sheets.last.backgroundColor, SheetColors.dark.panel);
    expect(find.text('Report Troll'), findsOneWidget);
  });

  testWidgets('not a moderator: no moderation row', (tester) async {
    when(() => store.canModerate).thenReturn(false);
    final context = await pump(tester, const Size(390, 844));
    await open(tester, context);
    expect(find.byType(ChatModerationBar), findsNothing);
    expect(find.textContaining('Following since'), findsNothing);
  });

  testWidgets('landscape phone: the card scrolls instead of overflowing', (
    tester,
  ) async {
    final context = await pump(tester, const Size(844, 390));
    await open(tester, context);
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatUserModal), findsOneWidget);
  });

  testWidgets('tablet: a panel beside the chat, at the tapped message', (
    tester,
  ) async {
    final context = await pump(tester, const Size(1280, 854));
    await open(tester, context, anchor: const Rect.fromLTWH(880, 600, 400, 26));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    final panel = tester.getRect(find.byType(OnsetPanelSurface));
    expect(panel.size, ChatUserModal.panelSize);
    expect(panel.right, 880 - 12);
    // No "RECENT MESSAGES" label in the panel (board).
    expect(find.text('RECENT MESSAGES'), findsNothing);
    expect(
      tester.getSize(find.widgetWithText(ModerationPill, 'Timeout')).height,
      40,
    );
  });

  testWidgets('tablet portrait: a panel above the tapped message', (
    tester,
  ) async {
    final context = await pump(tester, const Size(854, 1280));
    await open(tester, context, anchor: const Rect.fromLTWH(0, 1000, 854, 26));
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byType(OnsetPanelSurface));
    expect(panel.bottom, lessThanOrEqualTo(1000 - 12));
  });
}
