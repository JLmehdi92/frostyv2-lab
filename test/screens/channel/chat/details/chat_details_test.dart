import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_chat_rules_service.dart';
import 'package:onset/models/chat_rules.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/details/chat_details.dart';
import 'package:onset/screens/channel/chat/details/stores/chat_details_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/chat_message_harness.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockChatRulesService extends Mock implements TwitchChatRulesService {}

void main() {
  late MockChatStore store;
  late MockTwitchApi api;
  late SettingsStore settings;
  late ChatDetailsStore details;
  late MockAuthStore auth;
  var added = 0;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(() {});
  });

  setUp(() {
    added = 0;
    api = MockTwitchApi();
    when(
      () => api.getUserChatColor(userId: any(named: 'userId')),
    ).thenAnswer((_) async => '#FF7F50');
    when(
      () => api.updateUserChatColor(
        userId: any(named: 'userId'),
        color: any(named: 'color'),
      ),
    ).thenAnswer((_) async => true);
    auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => auth.user).thenReturn(user);
    when(
      () => user.details,
    ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
    settings = SettingsStore.fromJson({});
    details = ChatDetailsStore(twitchApi: api, channelName: 'channel');
    store = fakeChatStore(settings: settings);
    when(() => store.auth).thenReturn(auth);
    when(() => store.twitchApi).thenReturn(api);
    when(() => store.chatDetailsStore).thenReturn(details);
    when(() => store.chatRules).thenReturn(null);
    when(() => store.timeRemaining).thenReturn(Duration.zero);
    when(() => store.sleepTimer).thenReturn(null);
    when(() => store.userState).thenReturn(const USERSTATE());
    when(
      () => store.updateSleepTimer(
        duration: any(named: 'duration'),
        onTimerFinished: any(named: 'onTimerFinished'),
      ),
    ).thenReturn(null);
  });

  Future<void> scrollTo(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(ListView).first,
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? themes.dark : themes.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChatDetails(
                context,
                chatStore: store,
                onAddChat: () => added++,
              ),
              child: const Text('more'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(1280, 854), Size(854, 1280)]) {
    for (final brightness in Brightness.values) {
      testWidgets('the menu at $size ($brightness)', (tester) async {
        await open(tester, size: size, brightness: brightness);
        expect(tester.takeException(), isNull);
        for (final label in [
          'Chat only',
          'Refresh emotes and badges',
          'Reconnect',
          'Name color',
          'Channel points, polls, and predictions',
          'Subscribe',
          'Gift a sub',
          'Chatters',
          'Add chat',
          'Sleep timer',
          'Settings',
        ]) {
          await tester.dragUntilVisible(
            find.text(label),
            find.byType(ListView).first,
            const Offset(0, -80),
          );
          expect(find.text(label), findsOneWidget, reason: label);
        }
        // Not a moderator: no chat modes.
        expect(find.text('Chat modes'), findsNothing);
        expect(
          tester.getSize(find.byType(ChatDetails)).height,
          lessThanOrEqualTo(ChatDetails.maxHeight),
        );
      });
    }
  }

  testWidgets('a moderator gets chat modes, with the active ones on top', (
    tester,
  ) async {
    when(() => store.canModerate).thenReturn(true);
    details.roomState = const ROOMSTATE(slowMode: '30', followersOnly: '10');
    await open(tester);
    expect(find.text('Slow mode'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('Followers-only'), findsOneWidget);
    expect(find.text('10m'), findsOneWidget);
    await scrollTo(tester, 'Chat modes');
    await tester.tap(find.text('Chat modes'));
    await tester.pumpAndSettle();
    expect(find.text('Moderator'), findsOneWidget);
  });

  testWidgets('logged out: no colour, points or subscribe entries', (
    tester,
  ) async {
    when(() => auth.isLoggedIn).thenReturn(false);
    await open(tester);
    expect(find.text('Name color'), findsNothing);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Channel points, polls, and predictions'), findsNothing);
  });

  testWidgets('chat only flips the video and closes', (tester) async {
    settings.showVideo = true;
    await open(tester);
    await tester.tap(find.text('Chat only'));
    await tester.pumpAndSettle();
    expect(settings.showVideo, isFalse);
    expect(find.byType(ChatDetails), findsNothing);
  });

  testWidgets('the sleep timer opens in place and comes back', (tester) async {
    await open(tester);
    await scrollTo(tester, 'Sleep timer');
    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    // One sheet: the timer replaces the menu.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    final duration =
        verify(
              () => store.updateSleepTimer(
                duration: captureAny(named: 'duration'),
                onTimerFinished: any(named: 'onTimerFinished'),
              ),
            ).captured.single
            as Duration;
    expect(duration, const Duration(minutes: 5));
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('back from a sub-view returns to the menu, then closes', (
    tester,
  ) async {
    await open(tester);
    await scrollTo(tester, 'Sleep timer');
    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Reconnect'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ChatDetails), findsNothing);
  });

  testWidgets('username colour: current one ticked, Save sends the new one', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Name color'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('How it will look in chat', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    // The current colour is ticked.
    expect(
      find.descendant(
        of: find.widgetWithText(SheetRow, 'Coral'),
        matching: find.byWidgetPredicate(
          (w) => w is AnimatedOpacity && w.opacity == 1,
        ),
      ),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.text('Hot pink'),
      find.byType(ListView).last,
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hot pink'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    verify(
      () => api.updateUserChatColor(userId: '1', color: 'hot_pink'),
    ).called(1);
    expect(find.text('Name color updated'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('a save that throws keeps the pick and frees Save', (
    tester,
  ) async {
    when(
      () => api.updateUserChatColor(
        userId: any(named: 'userId'),
        color: any(named: 'color'),
      ),
    ).thenThrow(StateError('offline'));
    await open(tester);
    await tester.tap(find.text('Name color'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Hot pink'),
      find.byType(ListView).last,
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hot pink'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t update your name color. Try again.'),
      findsOneWidget,
    );
    // Still on the colours, Save usable again.
    expect(
      find.textContaining('How it will look in chat', findRichText: true),
      findsOneWidget,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('the rules open in place, with a way back like the others', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = MockChatRulesService();
    when(() => service.getRules(any())).thenAnswer(
      (_) async => const ChatRules(
        channelId: '12345',
        channelName: 'channel',
        rules: ['Be kind'],
      ),
    );
    final rules = ChatRulesStore(
      service: service,
      channelId: '12345',
      viewerId: () => '1',
    );
    addTearDown(rules.dispose);
    await tester.runAsync(rules.load);
    when(() => store.chatRules).thenReturn(rules);
    await open(tester);
    await scrollTo(tester, 'Chat rules');
    await tester.tap(find.text('Chat rules'));
    await tester.pumpAndSettle();
    expect(find.text('Be kind'), findsOneWidget);
    expect(find.widgetWithText(SheetBackHeader, 'Chat rules'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Be kind'), findsNothing);
    expect(find.text('Chat rules'), findsOneWidget);
  });

  testWidgets('add chat runs the callback', (tester) async {
    await open(tester);
    await scrollTo(tester, 'Add chat');
    await tester.tap(find.text('Add chat'));
    expect(added, 1);
  });

  testWidgets('reduce motion: views cross-fade', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    await scrollTo(tester, 'Sleep timer');
    await tester.tap(find.text('Sleep timer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(
        of: find.byType(ChatDetails),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.text('5 minutes'), findsOneWidget);
    expect(SheetColors.dark.sheet, isNotNull);
  });
}
