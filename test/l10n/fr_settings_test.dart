import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/account/blocked_users.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/notifications_settings.dart';
import 'package:onset/screens/settings/other_settings.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';
import 'package:onset/screens/settings/widgets/chat_filters_setting.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/widgets/onset_update_prompt.dart';
import 'package:provider/provider.dart';

import '../helpers/l10n.dart';
import '../screens/settings/settings_harness.dart';

class _MockUpdater extends Mock implements OnsetUpdater {}

const _release = OnsetRelease(
  build: 72,
  tag: 'build-72',
  notes: '- Chat waits as long as the video is behind live.',
  apkAssetId: 1,
  shaAssetId: 2,
  apkSize: 38 * 1024 * 1024,
);

/// Settings, the release notes and the update prompt in French, in the real
/// Inter font: nothing overflows and no English is left, at phone and
/// tablet sizes (frenchScreenSizes), with text at ×1 and ×1.3. Every scrolling list is gone
/// through, so what is below the fold is checked too.
void main() {
  final french = lookupAppLocalizations(fr);
  late SettingsStore settings;
  late _MockUpdater updater;

  setUpAll(() => registerFallbackValue(_release));

  setUp(() {
    // A string the asset bundle cached in an earlier test is a future of
    // that test's fake clock, which never completes in this one.
    rootBundle
      ..evict(ReleaseNotes.englishAsset)
      ..evict(ReleaseNotes.frenchAsset);
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({
      'languagePromptVersion': 1,
      // The manual delay slider and the celebrations choice are shown.
      'autoSyncChatDelay': false,
      'showCelebrations': true,
      'mutedWords': ['spoiler'],
      'hiddenContentLabels': ['Gambling', 'SexualThemes'],
    });
    updater = _MockUpdater();
    when(() => updater.enabled).thenReturn(true);
    when(() => updater.currentBuild()).thenAnswer((_) async => 68);
    when(() => updater.canInstall()).thenAnswer((_) async => true);
    when(() => updater.postpone(any())).thenAnswer((_) async {});
  });

  FakeAuthStore loggedIn() {
    final auth = FakeAuthStore(loggedIn: true);
    auth.blocked.add(const UserBlockedTwitch('9', 'spam', 'Spam'));
    return auth;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required AuthStore auth,
    required Size size,
    required double scale,
    Locale locale = fr,
  }) async {
    await pumpLocalized(
      tester,
      child,
      locale: locale,
      size: size,
      textScale: scale,
      wrap: (app) => MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<OnsetUpdater?>.value(value: updater),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A settings page as a phone pushes it: the header with its title.
  Widget pushed(SettingsPageId page, Widget body) => Builder(
    builder: (context) {
      return SettingsScaffold(
        title: page == SettingsPageId.chatFilters
            ? context.l10n.settingsPageChatFilters
            : context.l10n.settingsTitle,
        body: body,
      );
    },
  );

  final pages =
      <(String, Widget Function(AuthStore auth), AuthStore Function())>[
        (
          'Settings (first page / side column)',
          (_) => Settings(settingsStore: settings),
          loggedIn,
        ),
        (
          'Settings, logged out',
          (_) => Settings(settingsStore: settings),
          FakeAuthStore.new,
        ),
        (
          'Settings, Twitch unreachable',
          (_) => Settings(settingsStore: settings),
          () => FakeAuthStore(error: 'offline'),
        ),
        (
          'General',
          (_) => pushed(
            SettingsPageId.general,
            GeneralSettings(settingsStore: settings),
          ),
          loggedIn,
        ),
        (
          'Video (Android)',
          (_) => pushed(
            SettingsPageId.video,
            VideoSettings(
              settingsStore: settings,
              isAndroid: true,
              isIOS: false,
            ),
          ),
          loggedIn,
        ),
        (
          'Chat',
          (_) => pushed(
            SettingsPageId.chat,
            ChatSettings(settingsStore: settings),
          ),
          loggedIn,
        ),
        (
          'Chat filters',
          (_) => pushed(
            SettingsPageId.chatFilters,
            ChatFiltersSetting(settingsStore: settings),
          ),
          loggedIn,
        ),
        (
          'Notifications, logged in',
          (auth) => pushed(
            SettingsPageId.notifications,
            NotificationsSettings(settingsStore: settings, authStore: auth),
          ),
          loggedIn,
        ),
        (
          'Notifications, logged out',
          (auth) => pushed(
            SettingsPageId.notifications,
            NotificationsSettings(settingsStore: settings, authStore: auth),
          ),
          FakeAuthStore.new,
        ),
        (
          'Other',
          (_) => pushed(
            SettingsPageId.other,
            OtherSettings(settingsStore: settings),
          ),
          loggedIn,
        ),
        (
          'Account',
          (auth) =>
              pushed(SettingsPageId.account, AccountSettings(authStore: auth)),
          loggedIn,
        ),
        (
          'Blocked users',
          (auth) =>
              pushed(SettingsPageId.blocked, BlockedUsers(authStore: auth)),
          loggedIn,
        ),
        (
          'Blocked users, none',
          (auth) =>
              pushed(SettingsPageId.blocked, BlockedUsers(authStore: auth)),
          () => FakeAuthStore(loggedIn: true),
        ),
        (
          'Profile, logged in',
          (auth) => Scaffold(
            body: ProfileTab(settingsStore: settings, authStore: auth),
          ),
          loggedIn,
        ),
        (
          'Profile, logged out',
          (auth) => Scaffold(
            body: ProfileTab(settingsStore: settings, authStore: auth),
          ),
          FakeAuthStore.new,
        ),
        (
          'Profile, Twitch unreachable',
          (auth) => Scaffold(
            body: ProfileTab(settingsStore: settings, authStore: auth),
          ),
          () => FakeAuthStore(error: 'offline'),
        ),
      ];

  testWidgets('the leak check sees plural branches, not French look-alikes', (
    tester,
  ) async {
    final english = L10n.english;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text(english.mutedKeywordsCount(count: 3)),
            Text(english.settingsMessageDelayValue(seconds: 8)),
            Text(english.updateInstalledBuild(build: 68)),
            Text(french.settingsSpacingValue(pixels: 8)),
            Text(french.settingsScaleValue(scale: 1)),
            Text(french.mutedKeywordsCount(count: 3)),
            Text(french.settingsMessageDelayValue(seconds: 1)),
            Text(french.updateInstalledBuild(build: 68)),
          ],
        ),
      ),
    );
    expect(englishLeaks(tester), [
      english.mutedKeywordsCount(count: 3),
      english.settingsMessageDelayValue(seconds: 8),
      english.updateInstalledBuild(build: 68),
    ]);
  });

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      group('$sizeName, text ×$scale', () {
        // Every page, in French, then in English (sweepLocales).
        for (final locale in sweepLocales) {
          for (final (name, build, makeAuth) in pages) {
            testWidgets('$name${sweepName(locale)}', (tester) async {
              final auth = makeAuth();
              await pump(
                tester,
                build(auth),
                auth: auth,
                size: size,
                scale: scale,
                locale: locale,
              );
              await expectFrenchThroughout(tester, name);
            });
          }

          if (size.shortestSide >= 600) {
            for (final page in SettingsPageId.sections) {
              testWidgets('the tablet pane on ${page.name}'
                  '${sweepName(locale)}', (tester) async {
                final auth = loggedIn();
                await pump(
                  tester,
                  Settings(settingsStore: settings, initialPage: page),
                  auth: auth,
                  size: size,
                  scale: scale,
                  locale: locale,
                );
                await expectFrenchThroughout(tester, page.name);
              });
            }
          }
        }

        testWidgets('the sheets and dialogs of the settings', (tester) async {
          final auth = loggedIn();
          Future<void> open(Widget page, String row) async {
            await pump(tester, page, auth: auth, size: size, scale: scale);
            final target = find.text(row);
            // Lists build lazily: down the page's list until it is built.
            final list = tester
                .stateList<ScrollableState>(find.byType(Scrollable))
                .firstWhere(
                  (state) => state.axisDirection == AxisDirection.down,
                );
            list.position.jumpTo(0);
            await tester.pump();
            while (target.evaluate().isEmpty &&
                list.position.pixels < list.position.maxScrollExtent) {
              list.position.jumpTo(
                math.min(
                  list.position.maxScrollExtent,
                  list.position.pixels + list.position.viewportDimension / 2,
                ),
              );
              await tester.pump();
            }
            // In the middle, clear of the page's header.
            await tester.ensureVisible(target.first);
            await Scrollable.ensureVisible(
              tester.element(target.first),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(target.first);
            await tester.pumpAndSettle();
          }

          // Closes the sheet or dialog on top, as back does.
          Future<void> close(String what) async {
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator).first,
            );
            expect(navigator.canPop(), isTrue, reason: '$what did not open');
            navigator.pop();
            await tester.pumpAndSettle();
          }

          final general = pushed(
            SettingsPageId.general,
            GeneralSettings(settingsStore: settings),
          );
          await open(general, french.accentColorTitle);
          await expectFrenchThroughout(tester, 'accent picker');
          await close('accent picker');
          await open(general, french.settingsStreamLanguage);
          await expectFrenchThroughout(tester, 'stream language list');
          await close('stream language list');
          await open(general, french.settingsHideLabeled);
          await expectFrenchThroughout(tester, 'labels list');
          await close('labels list');

          final chat = pushed(
            SettingsPageId.chat,
            ChatSettings(settingsStore: settings),
          );
          await open(chat, french.settingsChatPreview);
          await expectFrenchThroughout(tester, 'chat preview open');
          await open(chat, french.mutedKeywordsTitle);
          await expectFrenchThroughout(tester, 'muted keywords');
          await close('muted keywords');

          await open(
            pushed(
              SettingsPageId.video,
              VideoSettings(
                settingsStore: settings,
                isAndroid: true,
                isIOS: false,
              ),
            ),
            french.webTokenTitle,
          );
          await expectFrenchThroughout(tester, 'web token dialog');
          await close('web token dialog');

          await open(
            pushed(
              SettingsPageId.other,
              OtherSettings(settingsStore: settings),
            ),
            french.settingsReset,
          );
          expect(find.text(french.settingsResetMessage), findsOneWidget);
          await expectFrenchThroughout(tester, 'reset dialog');
          await close('reset dialog');

          await open(
            pushed(SettingsPageId.account, AccountSettings(authStore: auth)),
            french.settingsLogOut,
          );
          expect(find.text(french.settingsLogOutMessage), findsOneWidget);
          await expectFrenchThroughout(tester, 'log out dialog');
          await close('log out dialog');

          await open(
            pushed(SettingsPageId.blocked, BlockedUsers(authStore: auth)),
            french.settingsUnblock,
          );
          expect(
            find.text(french.settingsUnblockMessage(name: 'Spam')),
            findsOneWidget,
          );
          await expectFrenchThroughout(tester, 'unblock dialog');
          await close('unblock dialog');
        });

        testWidgets('the release notes', (tester) async {
          await pump(
            tester,
            const ReleaseNotes(),
            auth: FakeAuthStore(),
            size: size,
            scale: scale,
          );
          // The bundled French notes, read in French: on a tablet, the
          // version list's date short, never cut.
          expect(find.text('29 octobre 2026'), findsWidgets);
          if (size.shortestSide >= 600) {
            final date = tester.renderObject<RenderParagraph>(
              find.text('29 oct. 2026'),
            );
            expect(date.didExceedMaxLines, isFalse);
          }
          await expectFrenchThroughout(tester, 'release notes');
        });

        testWidgets('the release notes after an update', (tester) async {
          await pump(
            tester,
            const ReleaseNotes(updatedTo: '1.0.0', updatedFrom: '0.9.2'),
            auth: FakeAuthStore(),
            size: size,
            scale: scale,
          );
          expect(
            find.text(french.releaseNotesUpdatedTo(version: '1.0.0')),
            findsOneWidget,
          );
          await expectFrenchThroughout(tester, 'release notes, fresh');
        });

        testWidgets('the update prompt', (tester) async {
          final installing = Completer<void>();
          when(
            () => updater.downloadAndInstall(
              any(),
              onProgress: any(named: 'onProgress'),
              cancelToken: any(named: 'cancelToken'),
              onInstall: any(named: 'onInstall'),
            ),
          ).thenAnswer((invocation) {
            final progress =
                invocation.namedArguments[#onProgress]
                    as void Function(int, int)?;
            progress?.call(12 * 1024 * 1024, 38 * 1024 * 1024);
            return installing.future;
          });
          await pump(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => offerUpdate(
                    context,
                    updater,
                    const UpdateAvailable(_release, 68),
                  ),
                  child: const Text('offer'),
                ),
              ),
            ),
            auth: FakeAuthStore(),
            size: size,
            scale: scale,
          );
          await tester.tap(find.text('offer'));
          await tester.pumpAndSettle();
          expect(find.text(french.updateAvailable), findsOneWidget);
          expect(find.text(french.updateReady(build: 72)), findsOneWidget);
          // The size in French: a decimal comma and « Mo ».
          expect(find.textContaining('38,0 Mo'), findsOneWidget);
          await expectFrenchThroughout(tester, 'update dialog');

          await tester.tap(find.text(french.updateNow));
          await tester.pump();
          await tester.pump();
          expect(find.text(french.updateDownloading), findsOneWidget);
          expect(
            find.text(french.updateProgress(received: 12, total: 38)),
            findsOneWidget,
          );
          await expectFrenchThroughout(tester, 'update progress');
          installing.complete();
          await tester.pumpAndSettle();
        });

        testWidgets('the prompt to allow updates', (tester) async {
          when(() => updater.canInstall()).thenAnswer((_) async => false);
          await pump(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => offerUpdate(
                    context,
                    updater,
                    const UpdateAvailable(_release, 68),
                  ),
                  child: const Text('offer'),
                ),
              ),
            ),
            auth: FakeAuthStore(),
            size: size,
            scale: scale,
          );
          await tester.tap(find.text('offer'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(french.updateNow));
          await tester.pumpAndSettle();
          expect(find.text(french.updateAllowMessage), findsOneWidget);
          await expectFrenchThroughout(tester, 'allow updates');
          await tester.tap(find.text(french.commonCancel));
          await tester.pumpAndSettle();
        });
      });
    }
  }
}
