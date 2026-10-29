import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/constants.dart';
import 'package:onset/screens/channel/video/captions.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/notifications_settings.dart';
import 'package:onset/screens/settings/other_settings.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

import 'settings_harness.dart';

/// Every switch of a page: its title, and the value it shows.
typedef SwitchRows = Map<String, bool Function(SettingsStore store)>;

final SwitchRows _general = {
  'Use large stream card': (s) => s.largeStreamCard,
  'Show thumbnail': (s) => s.showThumbnails,
  'Open links in external browser': (s) => s.launchUrlExternal,
};

final SwitchRows _video = {
  'Low-latency player (Twitch IVS)': (s) => s.playerEngine == PlayerEngine.ivs,
  'Enable video': (s) => s.showVideo,
  'Default to highest quality': (s) => s.defaultToHighestQuality,
  'Use fast video rendering': (s) => s.useTextureRendering,
  'Keep screen awake': (s) => s.keepScreenAwake,
  'Background audio': (s) => s.backgroundAudio,
  'Use custom video overlay': (s) => s.showOverlay,
  'Long-press player to toggle overlay': (s) => s.toggleableOverlay,
  'Show latency': (s) => s.showLatency,
  'Warn about mature content': (s) => s.warnMatureContent,
  'Closed Captions': (s) => s.showCaptions,
};

final SwitchRows _chat = {
  'Show deleted messages': (s) => s.showDeletedMessages,
  'Animate emotes': (s) => s.animateEmotes,
  'Animated GIFs': (s) => s.animateGifs,
  'Show GIFs in Chat': (s) => s.showGifs,
  'Preview clips and videos': (s) => s.showLinkPreviews,
  'Show timeouts and bans': (s) => s.showModerationNotices,
  'Show message dividers': (s) => s.showChatMessageDividers,
  'Sync message delay and stream latency': (s) => s.autoSyncChatDelay,
  'Move emote menu button left': (s) => s.emoteMenuButtonOnLeft,
  'Persist chat tabs': (s) => s.persistChatTabs,
  'Highlight first time chatters': (s) => s.highlightFirstTimeChatter,
  'Show notices': (s) => s.showUserNotices,
  'Collapse gift bombs': (s) => s.collapseGiftBombs,
  'Show Hype Trains': (s) => s.showHypeTrain,
  'Show community highlights': (s) => s.showCommunityHighlights,
  'Show celebrations': (s) => s.showCelebrations,
  'Show autocomplete bar': (s) => s.autocomplete,
  'Move chat left': (s) => s.landscapeChatLeftSide,
  'Force vertical chat': (s) => s.landscapeForceVerticalChat,
  'Match whole words': (s) => s.matchWholeWord,
  'Show Twitch emotes': (s) => s.showTwitchEmotes,
  'Show Twitch badges': (s) => s.showTwitchBadges,
  'Show 7TV emotes': (s) => s.show7TVEmotes,
  'Show BTTV emotes': (s) => s.showBTTVEmotes,
  'Show BTTV badges': (s) => s.showBTTVBadges,
  'Show FFZ emotes': (s) => s.showFFZEmotes,
  'Show FFZ badges': (s) => s.showFFZBadges,
  'Show historical recent messages': (s) => s.showRecentMessages,
};

void main() {
  late SettingsStore settings;
  late FakeAuthStore auth;

  setUp(() {
    mockSettingsPlatform();
    settings = SettingsStore.fromJson({});
    auth = FakeAuthStore(loggedIn: true);
  });

  /// Each switch of [rows] is on [page], shows its stored value, flips it
  /// when tapped, and the change survives a restart.
  Future<void> checkSwitches(
    WidgetTester tester,
    Widget page,
    SwitchRows rows,
  ) async {
    await pumpSettings(tester, page, settings: settings, auth: auth);
    for (final MapEntry(key: title, value: read) in rows.entries) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(SettingsListSwitch),
      );
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final before = read(settings);
      expect(
        tester.widget<SettingsListSwitch>(row).value,
        before,
        reason: title,
      );
      await tapVisible(tester, find.text(title));
      expect(read(settings), !before, reason: title);
      final restored = SettingsStore.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(read(restored), !before, reason: '$title after a restart');
      expect(tester.takeException(), isNull, reason: title);
    }
  }

  testWidgets('General: every switch writes its setting', (tester) async {
    await checkSwitches(
      tester,
      GeneralSettings(settingsStore: settings),
      _general,
    );
  });

  testWidgets('General: theme, accent, start tab, language, labels', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      GeneralSettings(settingsStore: settings),
      settings: settings,
      auth: auth,
    );
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(settings.themeType, ThemeType.light);

    // "Open the app on": the shell's places, never the old Top / Search.
    for (final tab in HomeTab.values) {
      expect(find.text(tab.label), findsOneWidget);
    }
    await tapVisible(tester, find.text('Browse'));
    expect(settings.startTab, HomeTab.browse);
    expect(SettingsStore.fromJson(settings.toJson()).startTab, HomeTab.browse);

    expect(find.text('All languages'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    // The accent picker applies at once; Random picks another colour.
    final before = settings.accentColor;
    await tapVisible(tester, find.text('Accent color'));
    expect(find.text('Applies everywhere as you pick'), findsOneWidget);
    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();
    expect(settings.accentColor, isNot(before));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Applies everywhere as you pick'), findsNothing);
  });

  testWidgets('Video (Android): every switch writes its setting', (
    tester,
  ) async {
    await checkSwitches(
      tester,
      VideoSettings(settingsStore: settings, isAndroid: true, isIOS: false),
      _video,
    );
  });

  testWidgets('Video: catch-up, buffer and web token follow the IVS engine', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      VideoSettings(settingsStore: settings, isAndroid: true, isIOS: false),
      settings: settings,
      auth: auth,
    );
    expect(find.text('Live catch-up'), findsOneWidget);
    await tester.tap(find.text('Jump to live'));
    await tester.pumpAndSettle();
    expect(settings.liveCatchUpMode, LiveCatchUpMode.jumpToLive);
    await tester.tap(find.text('Ultra'));
    await tester.pumpAndSettle();
    expect(settings.bufferProfile, BufferProfile.ultra);
    expect(find.text('Twitch web token (2K)'), findsOneWidget);

    // The WebView fallback: IVS's own settings go.
    await tester.tap(find.text('Low-latency player (Twitch IVS)'));
    await tester.pumpAndSettle();
    expect(settings.playerEngine, PlayerEngine.twitchWeb);
    expect(find.text('Live catch-up'), findsNothing);
    expect(find.text('Buffer profile'), findsNothing);
    expect(find.text('Twitch web token (2K)'), findsNothing);

    await tapVisible(tester, find.text('Large'));
    expect(settings.captionSize, CaptionSize.large);
    await tapVisible(tester, find.text('Translucent'));
    expect(settings.captionBackground, CaptionBackground.translucent);
  });

  testWidgets('Video elsewhere than Android: no Android-only setting', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      VideoSettings(settingsStore: settings, isAndroid: false, isIOS: false),
      settings: settings,
      auth: auth,
    );
    for (final title in [
      'Low-latency player (Twitch IVS)',
      'Use fast video rendering',
      'Background audio',
      'Closed Captions',
    ]) {
      expect(find.text(title), findsNothing, reason: title);
    }
    expect(find.text('Enable video'), findsOneWidget);
  });

  testWidgets('Chat: every switch writes its setting', (tester) async {
    await checkSwitches(tester, ChatSettings(settingsStore: settings), _chat);
  });

  testWidgets('Chat: timestamps, notch, manual delay, sizing', (tester) async {
    await pumpSettings(
      tester,
      ChatSettings(settingsStore: settings),
      settings: settings,
      auth: auth,
    );
    // The sizes and their ranges, unchanged.
    for (final (title, value, min, max, divisions) in [
      ('Badge scale', settings.badgeScale, 0.25, 3.0, 11),
      ('Emote scale', settings.emoteScale, 0.25, 3.0, 11),
      ('Message scale', settings.messageScale, 0.5, 2.0, 6),
      ('Message spacing', settings.messageSpacing, 0.0, 30.0, 15),
      ('Font size', settings.fontSize, 5.0, 20.0, 15),
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final slider = tester.widget<Slider>(
        find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Column))
              .first,
          matching: find.byType(Slider),
        ),
      );
      expect(
        (slider.value, slider.min, slider.max, slider.divisions),
        (value, min, max, divisions),
        reason: title,
      );
    }

    await tapVisible(tester, find.text('24-hour'));
    expect(settings.timestampType, TimestampType.twentyFour);
    await tapVisible(tester, find.text('Both'));
    expect(settings.landscapeCutout, LandscapeCutoutType.both);

    // The manual delay shows once the sync is off.
    expect(find.text('Message delay'), findsNothing);
    await tapVisible(
      tester,
      find.text('Sync message delay and stream latency'),
    );
    expect(find.text('Message delay'), findsOneWidget);

    // Persist chat tabs off forgets the tabs.
    await tapVisible(tester, find.text('Persist chat tabs'));
    expect(settings.persistChatTabs, isFalse);
    expect(settings.secondaryTabs, isEmpty);
  });

  testWidgets('Chat: muted keywords are added, removed and restored', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      ChatSettings(settingsStore: settings),
      settings: settings,
      auth: auth,
    );
    await tapVisible(tester, find.text('Muted keywords'));
    expect(find.text('No muted keywords'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'spoiler');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.mutedWords, ['spoiler']);

    // An empty keyword is not added.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.mutedWords, ['spoiler']);

    await tester.tap(find.byTooltip('Remove spoiler'));
    await tester.pumpAndSettle();
    expect(settings.mutedWords, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(settings.mutedWords, ['spoiler']);
  });

  testWidgets('Notifications: logged out, both say why and stay off', (
    tester,
  ) async {
    auth.setLoggedIn(false);
    await pumpSettings(
      tester,
      NotificationsSettings(settingsStore: settings, authStore: auth),
      settings: settings,
      auth: auth,
    );
    expect(find.text('Go-live notifications'), findsOneWidget);
    expect(find.text('Chat mention notifications'), findsOneWidget);
    for (final row in tester.widgetList<SettingsListSwitch>(
      find.byType(SettingsListSwitch),
    )) {
      expect(row.onChanged, isNull, reason: row.title);
      expect(row.value, isFalse, reason: row.title);
    }
    expect(
      find.text('Log in to be told when someone mentions you in chat.'),
      findsOneWidget,
    );
  });

  testWidgets('Other: reset asks first, cache, privacy, about', (tester) async {
    settings.showVideo = false;
    await pumpSettings(
      tester,
      OtherSettings(settingsStore: settings),
      settings: settings,
      auth: auth,
    );
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text('Clear image cache'), findsOneWidget);
    expect(find.text('Share crash logs and analytics'), findsOneWidget);
    // About: ONSET's own source code only, no third-party links.
    expect(find.text('Source code'), findsOneWidget);
    expect(find.textContaining('Support'), findsNothing);
    expect(find.text('View source on GitHub'), findsNothing);
    expect(find.textContaining('Made by'), findsNothing);

    // Without a Firebase config (as in this test build) the switch still
    // keeps the choice, and turning collection on or off does not throw.
    final shared = settings.shareCrashLogsAndAnalytics;
    await tapVisible(tester, find.text('Share crash logs and analytics'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(settings.shareCrashLogsAndAnalytics, !shared);
    await tapVisible(tester, find.text('Share crash logs and analytics'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(settings.shareCrashLogsAndAnalytics, shared);

    await tester.tap(find.text('Reset settings'));
    await tester.pumpAndSettle();
    expect(find.text('Reset all settings'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(settings.showVideo, isFalse);

    await tester.tap(find.text('Reset settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(settings.showVideo, isTrue);
    expect(find.text('All settings reset'), findsOneWidget);
  });

  testWidgets('Other: no source code row without a repository', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      OtherSettings(settingsStore: settings, sourceUrl: ''),
      settings: settings,
      auth: auth,
    );
    expect(find.text('Share crash logs and analytics'), findsOneWidget);
    expect(find.text('Source code'), findsNothing);
    expect(find.text('About'), findsNothing);
  });

  test('the source code link is ONSET\'s repository', () {
    expect(onsetRepoUrl, 'https://github.com/JLmehdi92/onset');
  });

  testWidgets('Account: the twitch.tv pages and log out leaving the page', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  Scaffold(body: AccountSettings(authStore: auth)),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      settings: settings,
      auth: auth,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('@jltomy · Joined March 2019'), findsOneWidget);
    expect(find.text('My channel'), findsOneWidget);
    expect(find.text('Blocked users'), findsOneWidget);
    expect(find.text('Security and privacy'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);

    await tapVisible(tester, find.text('Log out'));
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsButton),
        matching: find.text('Log out'),
      ),
    );
    await tester.pumpAndSettle();
    verify(() => auth.logout()).called(1);
    expect(find.byType(AccountSettings), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the phone settings page: account, sections, Other, version', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      Settings(settingsStore: settings),
      settings: settings,
      auth: auth,
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('JLTomy'), findsOneWidget);
    for (final section in ['General', 'Video', 'Chat', 'Notifications']) {
      expect(find.text(section), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('ONSET v5.0.5 (68)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reset settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back to the top (the header floats over the list's first rows).
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 4000),
      4000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('JLTomy'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettings), findsOneWidget);
  });

  testWidgets('a settings dialog fits a phone and a tablet', (tester) async {
    for (final size in const [Size(390, 844), Size(1280, 854)]) {
      await pumpSettings(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmSettingsAction(
              context,
              title: 'Reset all settings',
              message: 'Are you sure you want to reset all settings?',
              confirm: 'Reset',
            ),
            child: const Text('ask'),
          ),
        ),
        settings: settings,
        auth: auth,
        size: size,
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
