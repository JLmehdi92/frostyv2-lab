import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/account/blocked_users.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/notifications_settings.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';
import 'package:onset/screens/settings/widgets/chat_filters_setting.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/widgets/motion/press_scale.dart';

import 'settings_harness.dart';

void main() {
  late SettingsStore settings;

  setUp(() {
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({});
  });

  Future<void> pumpProfile(
    WidgetTester tester,
    FakeAuthStore auth, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
  }) => pumpSettings(
    tester,
    ProfileTab(settingsStore: settings, authStore: auth),
    settings: settings,
    auth: auth,
    size: size,
    mode: mode,
    reduceMotion: reduceMotion,
  );

  group('phone', () {
    testWidgets('logged in: the viewer, the account, the sections, log out', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      auth.blocked.add(const UserBlockedTwitch('9', 'spam', 'Spam'));
      await pumpProfile(tester, auth);

      expect(find.text('JLTomy'), findsOneWidget);
      expect(find.text('@jltomy'), findsOneWidget);
      expect(find.text('Joined March 2019'), findsOneWidget);
      expect(find.text('My channel'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Blocked users'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'the blocked count');
      expect(find.text('Security and privacy'), findsOneWidget);
      expect(find.text('Connections'), findsOneWidget);
      for (final section in ['General', 'Video', 'Chat', 'Other']) {
        expect(find.text(section), findsOneWidget);
      }
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mentions on'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Log out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('ONSET v5.0.5 (68)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('log out asks first, and Cancel keeps the session', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth);

      await tapVisible(tester, find.text('Log out'));
      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => auth.logout());
      expect(auth.isLoggedIn, isTrue);

      await tapVisible(tester, find.text('Log out'));
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsButton),
          matching: find.text('Log out'),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => auth.logout()).called(1);
      // Logged out, Profile becomes the logged-out page.
      expect(find.text('Log in with Twitch'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('logged out: the login card, the sections, no account', (
      tester,
    ) async {
      final auth = FakeAuthStore();
      await pumpProfile(tester, auth);

      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('Watching without an account'), findsOneWidget);
      expect(find.text('Log in with Twitch'), findsOneWidget);
      expect(
        find.text(
          'Have a token copied? Long-press this card to log in with it.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Log in to get go-live and mention notifications'),
        findsOneWidget,
      );
      expect(find.text('Blocked users'), findsNothing);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets(
      'a long press on the login card logs in with the copied token',
      (tester) async {
        final auth = FakeAuthStore();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? <String, dynamic>{'text': 'copied-token'}
              : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpProfile(tester, auth);

        await tester.longPress(find.text('Watching without an account'));
        await tester.pumpAndSettle();
        // The viewer's own token: whatever app it was made for.
        verify(
          () => auth.login(token: 'copied-token', acceptAnyApp: true),
        ).called(1);
      },
    );

    testWidgets('a connection problem offers to reconnect', (tester) async {
      final auth = FakeAuthStore(loggedIn: true, error: 'offline');
      await pumpProfile(tester, auth);

      expect(find.text('Couldn’t connect to Twitch.'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
      await tester.tap(find.text('Reconnect'));
      await tester.pump();
      verify(() => auth.init()).called(1);
    });

    testWidgets('each section opens its page, with a way back', (tester) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth);

      final pages = {
        'General': GeneralSettings,
        'Video': VideoSettings,
        'Chat': ChatSettings,
        'Notifications': NotificationsSettings,
      };
      for (final MapEntry(key: title, value: type) in pages.entries) {
        await tapVisible(tester, find.text(title));
        expect(find.byType(type), findsOneWidget, reason: title);
        expect(tester.takeException(), isNull, reason: title);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }

      await tapVisible(tester, find.text('Other'));
      expect(find.text('Reset settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Blocked users'));
      expect(find.byType(BlockedUsers), findsOneWidget);
      expect(find.text('No blocked users'), findsOneWidget);
    });

    testWidgets('"Settings" opens the settings page', (tester) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth);

      await tester.tap(
        find.descendant(
          of: find.byType(SettingsButton),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Settings), findsOneWidget);
      expect(find.text('Customize'.toUpperCase()), findsOneWidget);
      expect(find.text('Blocked users, twitch.tv, log out'), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mode.name} theme and reduce motion: no error', (
        tester,
      ) async {
        await pumpProfile(
          tester,
          FakeAuthStore(loggedIn: true),
          mode: mode,
          reduceMotion: true,
        );
        expect(find.text('JLTomy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('tablet', () {
    testWidgets('the side column and the page beside it', (tester) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));

      // The side column: the viewer, the sections, the account.
      expect(find.text('JLTomy'), findsOneWidget);
      expect(find.text('@jltomy · Joined March 2019'), findsOneWidget);
      for (final section in ['Video', 'Chat', 'Notifications', 'Other']) {
        expect(find.text(section), findsOneWidget);
      }
      expect(find.text('Account'), findsWidgets);
      expect(find.text('Log out'), findsOneWidget);
      // General opens first, with its groups in the pane.
      expect(find.byType(GeneralSettings), findsOneWidget);
      expect(find.text('THEME'), findsOneWidget);
      expect(find.text('Theme, stream cards, browsing, and links'), findsOne);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatSettings), findsOneWidget);
      expect(find.byType(GeneralSettings), findsNothing);
      // More than two groups: chips jump to them.
      expect(find.bySemanticsLabel('Jump to a group'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the jump chips hug their labels and share a row', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));

      final jump = find.bySemanticsLabel('Jump to a group');
      expect(jump, findsOneWidget);
      final chips = find.descendant(
        of: jump,
        matching: find.byType(PressScale),
      );
      expect(chips, findsAtLeast(3));
      final pane = tester.getSize(jump).width;
      final rows = <double>{};
      for (final chip in chips.evaluate()) {
        final box = chip.renderObject! as RenderBox;
        expect(box.size.width, lessThan(pane / 3), reason: 'a pill, not a bar');
        rows.add(box.localToGlobal(Offset.zero).dy);
      }
      expect(rows, hasLength(1), reason: 'the chips sit side by side');
    });

    testWidgets('a page inside a section opens over it, back returns', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Edit chat filters'));
      expect(find.byType(ChatFiltersSetting), findsOneWidget);
      expect(find.text('Enable filtering in chat'), findsOneWidget);
      // No new route: it is in the pane.
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(
        find.ancestor(
          of: find.text('Chat').last,
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatFiltersSetting), findsNothing);
      expect(find.byType(ChatSettings), findsOneWidget);
    });

    testWidgets('the page survives a change to a phone size and back', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoSettings), findsOneWidget);

      useWindow(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.text('@jltomy'), findsOneWidget, reason: 'phone profile');
      expect(find.byType(VideoSettings), findsNothing);

      useWindow(tester, const Size(1280, 854));
      await tester.pumpAndSettle();
      expect(find.byType(VideoSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait: one column, nothing overflows', (tester) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(854, 1280));
      for (final section in ['Video', 'Chat', 'Notifications', 'Other']) {
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section);
      }
      await tester.tap(find.text('Blocked users'));
      await tester.pumpAndSettle();
      expect(find.byType(BlockedUsers), findsOneWidget);
    });

    testWidgets('blocked users: unblock asks first, then unblocks', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      runInAction(
        () => auth.blocked.add(const UserBlockedTwitch('9', 'spam', 'Spam')),
      );
      await pumpProfile(tester, auth, size: const Size(1280, 854));
      await tester.tap(find.text('Blocked users'));
      await tester.pumpAndSettle();
      expect(find.text('1 BLOCKED'), findsOneWidget);

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to unblock Spam?'), findsOne);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      verify(() => auth.user.unblock(targetId: '9')).called(1);
      expect(find.text('No blocked users'), findsOneWidget);
    });

    testWidgets('logged out on an account page: General shows instead', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));
      await tester.tap(find.text('Blocked users'));
      await tester.pumpAndSettle();

      auth.setLoggedIn(false);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettings), findsOneWidget);
      expect(find.text('Log in with Twitch'), findsOneWidget);
      expect(find.text('Blocked users'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Twitch unreachable: no account rows, General shows', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pumpProfile(tester, auth, size: const Size(1280, 854));
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      auth.setError('offline');
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t connect to Twitch.'), findsOneWidget);
      expect(find.text('Blocked users'), findsNothing);
      expect(find.text('Log out'), findsNothing);
      expect(find.byType(GeneralSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mode.name} theme, reduce motion: every page', (
        tester,
      ) async {
        await pumpProfile(
          tester,
          FakeAuthStore(loggedIn: true),
          size: const Size(1280, 854),
          mode: mode,
          reduceMotion: true,
        );
        for (final section in [
          'Video',
          'Chat',
          'Notifications',
          'Other',
          'Account',
        ]) {
          await tester.tap(find.text(section).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: section);
        }
      });
    }
  });
}
