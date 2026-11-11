import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/activity/activity_screen.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/clips/clips_feed_screen.dart';
import 'package:onset/screens/home/home.dart';
import 'package:onset/screens/home/live_feed/live_feed.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/categories/categories.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/settings_master_detail.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '../../helpers/fake_vod_controller.dart';
import '../../helpers/keyboard_animation.dart';
import '../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockClipService extends Mock implements TwitchClipService {}

class MockVodService extends Mock implements TwitchVodService {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

class MockChatTabsStore extends Mock implements ChatTabsStore {}

class MockUserStore extends Mock implements UserStore {}

class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore({bool loggedIn = false}) : _loggedIn = Observable(loggedIn) {
    when(
      () => _user.details,
    ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(() => _user.blockedUsers).thenReturn(ObservableList());
  }

  final Observable<bool> _loggedIn;
  final _user = MockUserStore();

  @override
  bool get isLoggedIn => _loggedIn.value;

  @override
  UserStore get user => _user;

  @override
  String? get twitchWebToken => null;

  void setLoggedIn(bool value) => runInAction(() => _loggedIn.value = value);
}

void main() {
  late MockTwitchApi api;
  late MockClipService clips;
  late MockVodService vods;
  late SettingsStore settings;
  late ActivityStore activity;
  late WhisperStore whispers;
  late MiniPlayerStore mini;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '1.0.0'});
    PackageInfo.setMockInitialValues(
      appName: 'ONSET',
      packageName: 'onset',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    api = MockTwitchApi();
    clips = MockClipService();
    vods = MockVodService();
    when(
      () => vods.searchVideos(any(), cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const VodSearchPage(items: []));
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
    when(
      () => api.getTopCategories(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const CategoriesTwitch([], {}));
    when(
      () => clips.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async => const ClipFeedPage(items: []));
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
        first: any(named: 'first'),
      ),
    ).thenAnswer((_) async => const StreamsTwitch([], {}));
    when(
      () => api.getFollowedChannels(
        userId: any(named: 'userId'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => const FollowedChannels(data: [], pagination: {}, total: 0),
    );
    // The avatar's picture: none, it keeps its placeholder.
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    // The language question is answered (it has its own tests below).
    settings = SettingsStore.fromJson({'languagePromptVersion': 1})
      ..keepScreenAwake = false;
    activity = ActivityStore(log: await ActivityLog.load());
    whispers = WhisperStore(
      twitchApi: api,
      currentUserId: () => null,
      listen: (topic) =>
          EventSubHandle.forTesting(topic, const Stream.empty(), () {}),
    );
    mini = MiniPlayerStore();
  });

  tearDown(() => whispers.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.light,
    AuthStore? auth,
    bool reduceMotion = false,
    Locale? locale,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await localizedApp(
      tester,
      locale: locale,
      textScale: textScale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    );
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth ?? FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
          Provider<ActivityStore>.value(value: activity),
          Provider<WhisperStore>.value(value: whispers),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          locale: app.locale,
          supportedLocales: app.supportedLocales,
          localizationsDelegates: app.delegates,
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: app.builder,
          navigatorObservers: [OnsetShell.routeObserver],
          home: const Home(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Finder nav(String name) => find.byKey(ValueKey('nav-$name'));

  testWidgets('logged out: Home opens on Live; every section is reachable', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('No live streams right now'), findsOneWidget);

    // Clips: the feed, built only while it is on screen.
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen), findsOneWidget);
    expect(find.text('No clips right now'), findsOneWidget);

    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    expect(find.byType(Categories), findsOneWidget);

    await tester.tap(nav('activity'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('Hooray! You’re up to date'), findsOneWidget);

    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    // Profile inside the shell: no back button of its
    // own, the login card, the settings' sections, the header's settings.
    expect(find.byType(ProfileTab), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Log in with Twitch'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Profile: the header opens the settings; on a tablet the '
      'settings are the page itself', (tester) async {
    await pump(tester, auth: FakeAuthStore(loggedIn: true));
    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    expect(find.text('Viewer'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(Settings), findsOneWidget);
    expect(find.text('Twitch session, blocked users, twitch.tv, log out'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(Settings), findsNothing);
    await close(tester);

    await pump(
      tester,
      size: const Size(1280, 854),
      auth: FakeAuthStore(loggedIn: true),
    );
    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsMasterDetail), findsOneWidget);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.byType(GeneralSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('search opens over the shell, and back returns', (tester) async {
    await pump(tester);
    // From Live's video header (no blur, light glyphs over the video).
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search channels, categories, or videos'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('search keeps its query and results between opens', (
    tester,
  ) async {
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], {}));
    await pump(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chess');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // The result tabs show for a query; pick one.
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // From Browse's field this time: the same search.
    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search channels, categories, or videos'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'chess',
    );
    final tabs = tester.widget<ShellTabs>(find.byType(ShellTabs).last);
    expect(tabs.index, 2);
    verify(() => api.searchChannels(query: 'chess')).called(1);
    await close(tester);
  });

  testWidgets('search keeps where its results were scrolled between opens', (
    tester,
  ) async {
    when(() => api.searchChannels(query: any(named: 'query'))).thenAnswer(
      (_) async => [
        for (var i = 0; i < 40; i++)
          ChannelQuery(
            broadcasterLogin: 'chess$i',
            displayName: 'Chess $i',
            id: '${100 + i}',
            isLive: false,
            startedAt: '',
          ),
      ],
    );
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], {}));
    await pump(tester);
    ScrollController results() => tester
        .widget<CustomScrollView>(
          find.descendant(
            of: find.byType(SearchScreen),
            matching: find.byType(CustomScrollView),
          ),
        )
        .controller!;

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chess');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Channels').last);
    await tester.pumpAndSettle();
    results().jumpTo(600);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(results().offset, 600);
    await close(tester);
  });

  testWidgets('a kept search: no keyboard, and Videos follow a query that '
      'landed while it was closed', (tester) async {
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], {}));
    await pump(tester);
    FocusNode focus() =>
        tester.widget<TextField>(find.byType(TextField)).focusNode!;

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    // A new search: the keyboard is up.
    expect(focus().hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'chess');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Videos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Videos').last);
    await tester.pumpAndSettle();
    verify(() => vods.searchVideos('chess')).called(1);

    // Typing, then leaving before the search starts (300 ms later): the
    // query lands once the page is gone.
    await tester.enterText(find.byType(TextField), 'go');
    final page = tester.element(find.byType(SearchScreen));
    Navigator.of(page).removeRoute(ModalRoute.of(page)!);
    await tester.pump();
    expect(find.byType(SearchScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    verifyNever(() => vods.searchVideos('go'));

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    // A kept search shows its results, not the keyboard.
    expect(focus().hasFocus, isFalse);
    expect(tester.widget<ShellTabs>(find.byType(ShellTabs).last).index, 3);
    verify(() => vods.searchVideos('go')).called(1);
    await close(tester);
  });

  testWidgets("Android's back: to Home, to its start tab, then out", (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();

    // Back from Clips: Live, the start tab when logged out.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    expect(find.text('No live streams right now'), findsOneWidget);

    // Back from Profile: Home.
    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('No live streams right now'), findsOneWidget);
    expect(find.byType(ProfileTab), findsNothing);

    // Then the app may close: nothing handles back any more.
    expect(await tester.binding.handlePopRoute(), isFalse);
    await close(tester);
  });

  testWidgets('leaving Clips stops them, coming back does not restart them', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen), findsOneWidget);
    await tester.tap(nav('activity'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    await tester.tap(nav('home'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    expect(find.text('No live streams right now'), findsOneWidget);
    await close(tester);
  });

  group('the clips play only while their feed is in front', () {
    late Map<String, FakeVodController> players;
    late List<(String, bool)> built;

    Clip feedClip(String slug) => Clip(
      id: slug,
      slug: slug,
      title: 'Clip $slug',
      viewCount: 1,
      createdAt: DateTime.utc(2026, 10, 2),
      durationSeconds: 30,
      broadcasterId: '42',
      broadcasterLogin: 'streamer',
      broadcasterDisplayName: 'Streamer',
    );

    setUp(() {
      players = {};
      built = [];
      when(
        () => clips.getTopClips(language: any(named: 'language')),
      ).thenAnswer(
        (_) async =>
            ClipFeedPage(items: [feedClip('a'), feedClip('b'), feedClip('c')]),
      );
      ClipsFeedScreen.debugPlayerFactory = (clip, {required focused}) {
        built.add((clip.slug, focused));
        return players[clip.slug] = FakeVodController();
      };
    });

    tearDown(() => ClipsFeedScreen.debugPlayerFactory = null);

    bool feedActive(WidgetTester tester) =>
        tester.widget<ClipsFeedScreen>(find.byType(ClipsFeedScreen)).active;

    testWidgets('a page pushed over Home pauses the clip; closing it plays '
        'the clip on', (tester) async {
      await pump(tester, reduceMotion: true);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      final current = players['a']!..status = VodPlaybackStatus.playing;
      expect(feedActive(tester), isTrue);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        tester
            .widget<ClipsFeedScreen>(
              find.byType(ClipsFeedScreen, skipOffstage: false),
            )
            .active,
        isFalse,
      );
      expect(current.calls, containsAllInOrder(['focused false', 'pause']));
      current
        ..status = VodPlaybackStatus.paused
        ..calls.clear();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(feedActive(tester), isTrue);
      expect(current.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });

    testWidgets('switching to Live stops the clip in that very frame', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      final current = players['a']!..status = VodPlaybackStatus.playing;
      current.calls.clear();

      await tester.tap(find.text('Live'));
      await tester.pump();
      // Still fading out, already silent: before any Live preview starts.
      expect(find.byType(ClipsFeedScreen), findsOneWidget);
      expect(feedActive(tester), isFalse);
      expect(current.calls, containsAllInOrder(['focused false', 'pause']));
      await tester.pumpAndSettle();
      expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
      expect(current.calls, contains('dispose'));
      await close(tester);
    });

    testWidgets('back on Clips: the same clip, the list not loaded again', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(0, -600), 2000);
      await tester.pumpAndSettle();
      expect(built.last, ('c', false));

      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      built.clear();
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();

      expect(find.text('Clip b'), findsOneWidget);
      expect(built, [('b', true), ('c', false)]);
      verify(
        () => clips.getTopClips(language: any(named: 'language')),
      ).called(1);
      await close(tester);
    });

    testWidgets('opened on Clips: nothing plays under the launch intro', (
      tester,
    ) async {
      settings.startTab = HomeTab.clips;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: FakeAuthStore()),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchClipService>.value(value: clips),
            Provider<TwitchVodService>.value(value: vods),
            Provider<TwitchHypeTrainService>.value(
              value: MockHypeTrainService(),
            ),
            Provider<ActivityStore>.value(value: activity),
            Provider<WhisperStore>.value(value: whispers),
            Provider<MiniPlayerStore>.value(value: mini),
          ],
          child: MaterialApp(
            theme: themes.light,
            navigatorObservers: [
              LaunchIntro.navigatorObserver,
              OnsetShell.routeObserver,
            ],
            builder: (context, child) => LaunchIntro(
              play: true,
              slotKey: OnsetShell.markKey,
              child: child!,
            ),
            home: const Home(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(LaunchIntro.duration * 0.3);
      expect(LaunchIntro.running.value, isTrue);
      expect(feedActive(tester), isFalse);
      expect(built, [('a', false), ('b', false)]);
      expect(players['a']!.calls, isNot(contains('play')));

      await tester.pump(LaunchIntro.duration);
      await tester.pump(const Duration(seconds: 1));
      expect(LaunchIntro.running.value, isFalse);
      expect(feedActive(tester), isTrue);
      expect(players['a']!.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });
  });

  testWidgets('the mini player keeps under the header and above the bar', (
    tester,
  ) async {
    await pump(tester);
    // Live's video header (its tabs, 56) and the floating bar (14 + 64).
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));

    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));

    // A sheet leaves the shell on screen.
    showModalBottomSheet<void>(
      context: tester.element(find.byType(Home)),
      builder: (_) => const SizedBox(height: 100),
    );
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();

    // Another page covers the shell: its chrome no longer counts.
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(mini.shellChrome, isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    await close(tester);
  });

  testWidgets('a page opened from a sheet still covers the shell', (
    tester,
  ) async {
    await pump(tester);
    expect(mini.shellChrome, isNotNull);
    late BuildContext sheet;
    showModalBottomSheet<void>(
      context: tester.element(find.byType(Home)),
      builder: (context) {
        sheet = context;
        return const SizedBox(height: 100);
      },
    );
    await tester.pumpAndSettle();
    // "Report" in a channel's actions opens a page over its own sheet.
    Navigator.of(sheet).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page'), findsOneWidget);
    expect(mini.shellChrome, isNull);

    Navigator.of(tester.element(find.text('Page'))).pop();
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    Navigator.of(sheet).pop();
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    await close(tester);
  });

  testWidgets('a page pushed and popped within one locked frame does not '
      'leave the shell covered', (tester) async {
    await pump(tester);
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    var once = true;
    // Both land while the frame builds, when Home must defer its change.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!once) return;
      once = false;
      OnsetShell.routeObserver
        ..didPush(page, null)
        ..didPop(page, null);
    });
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(mini.shellChrome, const EdgeInsets.only(top: 56, bottom: 78));
    await close(tester);
  });

  testWidgets('the keyboard of a page over Home does not rebuild Home', (
    tester,
  ) async {
    await pump(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: TextField())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiveFeed, skipOffstage: false), findsOneWidget);
    final counts = await countRebuilds(
      () => animateKeyboard(tester),
      where: (element) =>
          element.widget is Home ||
          element.findAncestorWidgetOfExactType<Home>() != null,
    );
    // Home stays mounted under the page: before, its whole shell and every
    // kept page were built again on each frame of the keyboard.
    expect(counts.of<Home>(), 0, reason: '$counts');
    expect(counts.of<OnsetShell>(), 0, reason: '$counts');
    expect(counts.of<LiveFeed>(), 0, reason: '$counts');
    await animateKeyboard(tester, open: false);
    navigator.pop();
    await tester.pumpAndSettle();
    await close(tester);
  });

  testWidgets('a count changing does not rebuild the pages', (tester) async {
    await pump(tester);
    final list = tester.widget(find.byType(LiveFeed));
    await activity.addAll([
      ActivityEntry(
        id: 'a',
        kind: ActivityKind.live,
        title: 'Live now',
        body: '',
        at: DateTime.now(),
      ),
    ]);
    await tester.pump();
    expect(find.bySemanticsLabel('Activity, 1 new'), findsOneWidget);
    // The very same page: Flutter skipped it.
    expect(identical(tester.widget(find.byType(LiveFeed)), list), isTrue);
    await close(tester);
  });

  testWidgets('snack bars float above the bar, not over it', (tester) async {
    await pump(tester);
    final context = tester.element(find.byType(Home));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hello')));
    await tester.pumpAndSettle();
    final snack = tester.getRect(find.byType(SnackBar));
    final bar = tester.getRect(find.byKey(const ValueKey('shell-nav')));
    expect(snack.bottom, lessThanOrEqualTo(bar.top));
    // The bar still takes taps.
    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    expect(find.byType(Categories), findsOneWidget);
    await close(tester);
  });

  group('Clips in picture-in-picture', () {
    const channel = MethodChannel('puntito.simple_pip_mode');
    var pipActive = false;

    /// Answers the plugin's calls; returns a way to send it events.
    Future<void> Function(String) pipPlatform(WidgetTester tester) {
      ClipsFeedScreen.debugPipSupported = true;
      addTearDown(() => ClipsFeedScreen.debugPipSupported = null);
      pipActive = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isPipActivated' ? pipActive : true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      return (method) async {
        pipActive = method == 'onPipEntered';
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
          (_) {},
        );
      };
    }

    Finder chrome() => find.byKey(const ValueKey('shell-nav'));

    testWidgets('the clip alone, no chrome', (tester) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      expect(chrome(), findsOneWidget);

      // Android shrinks the app into the PiP window: only the clip shows.
      await platform('onPipEntered');
      await tester.pump();
      expect(chrome(), findsNothing);
      expect(find.byKey(const ValueKey('shell-nav-fade')), findsNothing);
      expect(find.text('Live'), findsNothing);
      expect(find.byTooltip('Search'), findsNothing);
      expect(find.byKey(OnsetShell.markKey), findsNothing);
      // The feed itself stayed (it keeps playing in the window).
      expect(find.byType(ClipsFeedScreen), findsOneWidget);

      await platform('onPipExited');
      await tester.pump();
      expect(chrome(), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a player that took the events gives them back', (
      tester,
    ) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();

      // A stream opened over the feed: its PipWidget takes the plugin's
      // single handler, then it closes.
      final stream = Object();
      var stolen = 0;
      PlaybackFocus.shared
        ..register(stream, onLost: () {}, onRegained: () {})
        ..claim(stream);
      SimplePip(onPipEntered: () => stolen++);
      PlaybackFocus.shared.release(stream);
      await tester.pump();
      await tester.pump();

      await platform('onPipEntered');
      await tester.pump();
      expect(stolen, 0);
      expect(chrome(), findsNothing);
      await platform('onPipExited');
      await tester.pump();
      await close(tester);
    });

    testWidgets('the mini player closing gives the events back', (
      tester,
    ) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();

      // A channel minimized over the feed: the mini window's PipWidget
      // takes the events; it closes.
      final player = MockIvsVideoStore();
      when(player.dispose).thenAnswer((_) async {});
      final chat = MockChatTabsStore();
      when(chat.dispose).thenReturn(null);
      mini.adopt(
        player: player,
        chatTabsStore: chat,
        userLogin: 'a',
        userId: '1',
        displayName: 'A',
      );
      var stolen = 0;
      SimplePip(onPipEntered: () => stolen++);
      mini.close();
      await tester.pump();
      await tester.pump();

      await platform('onPipEntered');
      await tester.pump();
      expect(stolen, 0);
      expect(chrome(), findsNothing);
      await platform('onPipExited');
      await tester.pump();
      await close(tester);
    });

    testWidgets('a player opening over the feed keeps the events it took', (
      tester,
    ) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      final player = MockIvsVideoStore();
      when(player.dispose).thenAnswer((_) async {});
      final chat = MockChatTabsStore();
      when(chat.dispose).thenReturn(null);
      mini.adopt(
        player: player,
        chatTabsStore: chat,
        userLogin: 'a',
        userId: '1',
        displayName: 'A',
      );
      await tester.pump();

      // The mini window restored into its channel, in one frame: the
      // channel claims focus, its PipWidget takes the events, the mini
      // window hides.
      final channelScreen = Object();
      var channelPip = 0;
      PlaybackFocus.shared
        ..register(channelScreen, onLost: () {}, onRegained: () {})
        ..claim(channelScreen);
      SimplePip(onPipEntered: () => channelPip++);
      mini.close();
      await tester.pump();
      await tester.pump();

      await platform('onPipEntered');
      await tester.pump();
      // The channel's PiP, not the feed's.
      expect(channelPip, 1);
      expect(chrome(), findsOneWidget);
      PlaybackFocus.shared.release(channelScreen);
      await tester.pump();
      await tester.pump();
      await close(tester);
    });

    testWidgets('leaving the clips while in PiP brings the chrome back', (
      tester,
    ) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      await platform('onPipEntered');
      await tester.pump();
      expect(chrome(), findsNothing);

      // The feed goes (back to Live) while still in PiP.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
      expect(chrome(), findsOneWidget);
      await close(tester);
    });

    testWidgets('an exit lost to another handler: resuming out of PiP '
        'brings the chrome back', (tester) async {
      final platform = pipPlatform(tester);
      await pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      await platform('onPipEntered');
      await tester.pump();
      expect(chrome(), findsNothing);

      // Another PipWidget took the handler meanwhile: the exit goes there.
      SimplePip(onPipExited: () {});
      await platform('onPipExited');
      await tester.pump();
      expect(chrome(), findsNothing);

      // Back in front, and the plugin says PiP is over.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(chrome(), findsOneWidget);
      await close(tester);
    });
  });

  testWidgets('no blur while a clip is still fading out', (tester) async {
    await pump(tester, auth: FakeAuthStore(loggedIn: true));
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // The feed is still on screen, fading: nothing blurs over its video.
    expect(find.byType(ClipsFeedScreen), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await close(tester);
  });

  testWidgets("Live's phone feed is a video page: no blur over it, even "
      'while it fades out', (tester) async {
    await pump(tester, auth: FakeAuthStore(loggedIn: true));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    // Search and whispers stay, light over the video's gradient.
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Whispers'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LiveFeed), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await close(tester);
  });

  testWidgets("a tablet's Live is a card under the opaque bar", (tester) async {
    await pump(tester, size: const Size(1280, 854));
    expect(find.byType(LiveFeed), findsOneWidget);
    // The tablet's header keeps its search field.
    expect(find.text('Search'), findsWidgets);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('leaving the clips cut short by another section: back on '
      'Home, the glass chrome at once', (tester) async {
    await pump(tester, auth: FakeAuthStore(loggedIn: true));
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // Mid-fade, off to Browse: the clips are gone at once.
    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);

    await tester.tap(nav('home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    // No clip left to protect: the header and the bar are glass again.
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await close(tester);
  });

  testWidgets('reduce motion: no blur over the clip during its short fade', (
    tester,
  ) async {
    await pump(tester, reduceMotion: true, auth: FakeAuthStore(loggedIn: true));
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(ClipsFeedScreen), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    // The short fade is 150 ms; then the glass is back.
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byType(ClipsFeedScreen, skipOffstage: false), findsNothing);
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await close(tester);
  });

  testWidgets('over the clips and Live, the bottom fade is dark in either '
      'theme', (tester) async {
    await pump(tester, auth: FakeAuthStore(loggedIn: true));
    Color fadeColor() =>
        ((tester
                            .widget<DecoratedBox>(
                              find.byKey(const ValueKey('shell-nav-fade')),
                            )
                            .decoration
                        as BoxDecoration)
                    .gradient!
                as LinearGradient)
            .colors
            .first;
    // The light theme's ground on Following.
    expect(fadeColor(), isNot(const Color(0xFF0A0A0A)));
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    expect(fadeColor(), const Color(0xFF0A0A0A));
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(fadeColor(), const Color(0xFF0A0A0A));
    await close(tester);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the system bars follow the theme (${mode.name})', (
      tester,
    ) async {
      await pump(tester, mode: mode, auth: FakeAuthStore(loggedIn: true));
      final dark = mode == ThemeMode.dark;
      final theme = dark
          ? OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark
          : OnsetThemes(colorSchemeSeed: OnsetTokens.accent).light;
      final themed = theme.appBarTheme.systemOverlayStyle!;
      expect(SystemChrome.latestStyle, themed);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
      expect(
        SystemChrome.latestStyle!.systemNavigationBarColor,
        theme.scaffoldBackgroundColor,
      );

      // Over the clips: light icons on the dark gradient and a dark bar.
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        SystemChrome.latestStyle!.systemNavigationBarColor,
        OnsetTokens.backgroundDark,
      );

      // Live's feed is a video page too.
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle!.systemNavigationBarColor,
        OnsetTokens.backgroundDark,
      );

      // Back on Following, the theme's again (not left white on a pale
      // header).
      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, themed);

      // Search, Profile: the theme's too.
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, themed);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(nav('profile'));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, themed);
      await close(tester);
    });
  }

  testWidgets('tablet over the clips: a dark navigation bar, the theme '
      'status bar over the opaque top bar', (tester) async {
    await pump(tester, size: const Size(1280, 854));
    final themed = OnsetThemes(
      colorSchemeSeed: OnsetTokens.accent,
    ).light.appBarTheme.systemOverlayStyle!;
    expect(SystemChrome.latestStyle, themed);
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    final style = SystemChrome.latestStyle!;
    expect(style.systemNavigationBarColor, OnsetTokens.backgroundDark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarIconBrightness, themed.statusBarIconBrightness);
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle, themed);
    await close(tester);
  });

  group('logged in', () {
    testWidgets('a whisper notice goes with its account; Open never opens '
        "the previous account's", (tester) async {
      whispers.dispose();
      final me = Observable<String?>('7');
      final events = StreamController<EventSubTopicEvent>.broadcast();
      addTearDown(events.close);
      whispers = WhisperStore(
        twitchApi: api,
        currentUserId: () => me.value,
        listen: (topic) =>
            EventSubHandle.forTesting(topic, events.stream, () {}),
      );
      await pump(tester, auth: FakeAuthStore(loggedIn: true));
      events.add(
        const EventSubData({
          'from_user_id': '8',
          'from_user_login': 'friend',
          'from_user_name': 'Friend',
          'to_user_id': '7',
          'whisper_id': 'w1',
          'whisper': {'text': 'hey'},
        }),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);

      runInAction(() => me.value = '9');
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('Activity: tabs with counts on a phone, two columns on a '
        'tablet', (tester) async {
      await activity.addAll([
        ActivityEntry(
          id: 'n1',
          kind: ActivityKind.live,
          title: 'streamer is live',
          body: '',
          at: DateTime.now(),
        ),
      ]);
      await pump(tester, auth: FakeAuthStore(loggedIn: true));
      await tester.tap(nav('activity'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Whispers'), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-count')), findsOneWidget);
      expect(find.text('See all'), findsNothing);

      // The same Activity on a tablet: no tabs, the whispers beside.
      tester.view.physicalSize = const Size(1280, 854);
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsNothing);
      expect(find.byKey(const ValueKey('tab-count')), findsNothing);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('streamer is live'), findsOneWidget);
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('Following first; whispers in the header and in Activity', (
      tester,
    ) async {
      await pump(tester, auth: FakeAuthStore(loggedIn: true));
      for (final tab in ['Following', 'Live', 'Clips']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('No followed streams'), findsOneWidget);
      expect(find.byTooltip('Whispers'), findsOneWidget);
      // The avatar is Profile.
      expect(
        find.descendant(
          of: nav('profile'),
          matching: find.byType(ProfilePicture),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Whispers'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(nav('activity'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      await tester.tap(find.text('Whispers'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersList), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('logging out keeps the section, drops what needs an account', (
      tester,
    ) async {
      final auth = FakeAuthStore(loggedIn: true);
      await pump(tester, auth: auth);
      await tester.tap(nav('activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Whispers'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersList), findsOneWidget);

      auth.setLoggedIn(false);
      await tester.pumpAndSettle();
      // Still Activity, on Notifications, without the Whispers tab.
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(find.byType(WhispersList), findsNothing);
      expect(find.text('Whispers'), findsNothing);
      expect(find.byTooltip('Whispers'), findsNothing);

      // Home lost Following: Live.
      await tester.tap(nav('home'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsNothing);
      expect(find.text('No live streams right now'), findsOneWidget);

      // Logging in again: Following and the whispers are back; the tab on
      // screen stays (a session restored behind the viewer must not move
      // them).
      auth.setLoggedIn(true);
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('No live streams right now'), findsOneWidget);
      expect(find.byTooltip('Whispers'), findsOneWidget);
      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(find.text('No followed streams'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });

  testWidgets("a token made for another app: the account's notice, once", (
    tester,
  ) async {
    final auth = FakeAuthStore(loggedIn: true);
    when(() => auth.tokenNotice).thenReturn(TokenNotice.foreignToken);
    when(auth.clearTokenNotice).thenReturn(null);
    await pump(tester, auth: auth);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(L10n.english.authForeignTokenNotice), findsOneWidget);
    verify(auth.clearTokenNotice).called(1);
    await close(tester);
  });

  testWidgets('a phone-tablet switch keeps the pages (fold, split, PiP)', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854));
    final live = tester.state(find.byType(LiveFeed));
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    final feed = tester.state(find.byType(ClipsFeedScreen));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-nav')), findsOneWidget);
    // The clips feed playing did not restart; Live kept its list.
    expect(identical(tester.state(find.byType(ClipsFeedScreen)), feed), isTrue);
    expect(
      identical(tester.state(find.byType(LiveFeed, skipOffstage: false)), live),
      isTrue,
    );
    await close(tester);
  });

  testWidgets('"Open the app on" Browse opens Browse', (tester) async {
    settings.startTab = HomeTab.browse;
    await pump(tester);
    expect(find.byType(Categories), findsOneWidget);
    expect(find.text('Browse'), findsWidgets);
    // Its first section: Back closes the app from there.
    expect(await tester.binding.handlePopRoute(), isFalse);
    await close(tester);
  });

  testWidgets('Browse: Categories and Live channels, kept between visits', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    ShellTabs browseTabs() => tester.widget<ShellTabs>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ShellTabs && widget.labels.contains('Live channels'),
      ),
    );
    expect(browseTabs().labels, ['Categories', 'Live channels']);
    expect(browseTabs().index, 0);
    expect(find.byType(Categories), findsOneWidget);
    expect(find.text('No top categories'), findsOneWidget);

    await tester.tap(find.text('Live channels'));
    await tester.pumpAndSettle();
    final live = find.byWidgetPredicate(
      (widget) => widget is StreamsList && widget.listType == ListType.top,
    );
    expect(live, findsOneWidget);
    expect(find.text('No live streams right now'), findsOneWidget);

    // Home and back: Browse is still on its live channels.
    await tester.tap(nav('home'));
    await tester.pumpAndSettle();
    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    expect(browseTabs().index, 1);
    expect(live, findsOneWidget);
    await close(tester);
  });

  testWidgets('Browse on a tablet: the tabs under the top bar, the rail', (
    tester,
  ) async {
    settings.startTab = HomeTab.browse;
    await pump(tester, size: const Size(1280, 854), mode: ThemeMode.dark);
    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Top categories'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a value saved before the shell still opens its place', (
    tester,
  ) async {
    settings = SettingsStore.fromJson({
      'startTab': 'search',
      'languagePromptVersion': 1,
    })..keepScreenAwake = false;
    await pump(tester);
    expect(find.byType(Categories), findsOneWidget);
    await close(tester);
  });

  /// Notes with an entry for the version under test (1.0.0).
  void notesFor100() {
    ReleaseNotes.debugSource = () async => '## v1.0.0\n\n- Something new.\n';
    addTearDown(() => ReleaseNotes.debugSource = null);
  }

  testWidgets('a first launch never opens the release notes, and remembers '
      'the version', (tester) async {
    SharedPreferences.setMockInitialValues({});
    notesFor100();
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('after an update, the release notes open when they have the '
      'new version', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    notesFor100();
    await pump(tester);
    expect(find.byType(ReleaseNotes), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReleaseNotes))).pop();
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('after an update, no release notes without an entry for the '
      'new version', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    ReleaseNotes.debugSource = () async => '## v0.9.0\n\n- Older.\n';
    addTearDown(() => ReleaseNotes.debugSource = null);
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('release notes that cannot be read keep the version for the '
      'next launch', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    ReleaseNotes.debugSource = () async => throw StateError('no asset');
    addTearDown(() => ReleaseNotes.debugSource = null);
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '0.9.0');
    await close(tester);
  });

  testWidgets('a first launch with unreadable notes still remembers the '
      'version', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ReleaseNotes.debugSource = () async => throw StateError('no asset');
    addTearDown(() => ReleaseNotes.debugSource = null);
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  /// Serves the real bundled notes file (its content; release_notes_test
  /// proves it loads through the asset bundle). A real asset read does not
  /// finish reliably under the fake clock of a widget test.
  void bundledNotes() {
    final bundled = File('assets/release-notes.md').readAsStringSync();
    ReleaseNotes.debugSource = () async => bundled;
    addTearDown(() => ReleaseNotes.debugSource = null);
  }

  testWidgets('a first launch with the bundled notes remembers the version', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    bundledNotes();
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('a later launch of the same version with the bundled notes '
      'opens nothing', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '1.0.0'});
    bundledNotes();
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('after an update to 1.0.0, the bundled notes open its entry as '
      'just updated, and Got it closes them', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    bundledNotes();
    await pump(tester);
    expect(find.byType(ReleaseNotes), findsOneWidget);
    expect(find.text('Updated to 1.0.0'), findsOneWidget);
    expect(find.textContaining('You were on'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotes), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_shown_version'), '1.0.0');
    await close(tester);
  });

  testWidgets('straight from the onboarding, the release notes wait for the '
      'tile to land', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    notesFor100();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pushed = <String?>[];
    final navigator = GlobalKey<NavigatorState>();
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
          Provider<ActivityStore>.value(value: activity),
          Provider<WhisperStore>.value(value: whispers),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: themes.light,
          navigatorObservers: [
            LaunchIntro.navigatorObserver,
            OnsetShell.routeObserver,
            _RouteNames(pushed),
          ],
          builder: (context, child) =>
              LaunchIntro(slotKey: OnsetShell.markKey, child: child!),
          home: const Scaffold(body: Text('onboarding')),
        ),
      ),
    );
    await tester.pump();
    expect(
      LaunchIntro.land(
        from: const Rect.fromLTWH(159, 386, 72, 72),
        onCovered: () => navigator.currentState!.pushAndRemoveUntil(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const Home(),
          ),
          (_) => false,
        ),
      ),
      isTrue,
    );
    await tester.pump();
    await tester.pump(LaunchIntro.landingDuration * 0.3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Home), findsOneWidget);
    // The notes are due (an update with notes for it) but the tile still
    // flies.
    expect(pushed, isNot(contains(ReleaseNotes.routeName)));
    expect(find.byKey(LaunchIntro.overlayKey), findsOneWidget);

    await tester.pump(LaunchIntro.landingDuration);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
    expect(pushed, contains(ReleaseNotes.routeName));
    await close(tester);
  });

  testWidgets('opened under a page (first run, a deep-linked channel during '
      'the landing): no orientation reset and no release notes over it, '
      'until it closes', (tester) async {
    SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
    notesFor100();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final orientations = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final pushed = <String?>[];
    final navigator = GlobalKey<NavigatorState>();
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
          Provider<ActivityStore>.value(value: activity),
          Provider<WhisperStore>.value(value: whispers),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: themes.light,
          navigatorObservers: [OnsetShell.routeObserver, _RouteNames(pushed)],
          home: const Scaffold(body: Text('onboarding')),
        ),
      ),
    );
    final onboarding = ModalRoute.of(tester.element(find.text('onboarding')))!;
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('channel')),
      ),
    );
    await tester.pumpAndSettle();
    orientations.clear();

    // The landing swaps the onboarding for Home, under the channel.
    navigator.currentState!.replace(
      oldRoute: onboarding,
      newRoute: PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const Home(),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('channel'), findsOneWidget);
    expect(orientations, isEmpty);
    expect(pushed, isNot(contains(ReleaseNotes.routeName)));

    navigator.currentState!.pop();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(orientations, contains(isEmpty));
    expect(pushed, contains(ReleaseNotes.routeName));
    await close(tester);
  });

  group('the one-time language question', () {
    final english = L10n.english;
    final french = lookupAppLocalizations(const Locale('fr'));

    /// Settings saved by a build before French: never asked.
    void savedBeforeFrench() {
      settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('asked once to an install from before French, preselected '
        'to the device; Continue answers it', (tester) async {
      savedBeforeFrench();
      await pump(tester);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      await tester.tap(find.text(english.languagePromptConfirm));
      await tester.pumpAndSettle();
      expect(find.text(english.languagePromptTitle), findsNothing);
      expect(settings.appLanguage, AppLanguage.en);
      expect(settings.languagePromptVersion, kLanguagePromptVersion);
      await close(tester);

      // Answered: never again.
      await pump(tester);
      expect(find.text(english.languagePromptTitle), findsNothing);
      await close(tester);
    });

    testWidgets('not asked once answered (a new install answers on the '
        'onboarding)', (tester) async {
      await pump(tester);
      await settle(tester);
      expect(find.text(english.languagePromptTitle), findsNothing);
      await close(tester);
    });

    testWidgets('comes before the release notes, which open after it', (
      tester,
    ) async {
      savedBeforeFrench();
      SharedPreferences.setMockInitialValues({'last_shown_version': '0.9.0'});
      notesFor100();
      await pump(tester);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      expect(find.byType(ReleaseNotes), findsNothing);
      await tester.tap(find.text(english.languagePromptConfirm));
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseNotes), findsOneWidget);
      await close(tester);
    });

    testWidgets('the scrim does not close it; back keeps the preselection', (
      tester,
    ) async {
      savedBeforeFrench();
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pump(tester);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      expect(settings.languagePromptVersion, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(english.languagePromptTitle), findsNothing);
      // The device is French: back confirmed French.
      expect(settings.appLanguage, AppLanguage.fr);
      expect(settings.languagePromptVersion, kLanguagePromptVersion);
      await close(tester);
    });

    testWidgets('a tap on the pill switches the app (the question with it) '
        'at once', (tester) async {
      savedBeforeFrench();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: FakeAuthStore()),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchClipService>.value(value: clips),
            Provider<TwitchVodService>.value(value: vods),
            Provider<TwitchHypeTrainService>.value(
              value: MockHypeTrainService(),
            ),
            Provider<ActivityStore>.value(value: activity),
            Provider<WhisperStore>.value(value: whispers),
            Provider<MiniPlayerStore>.value(value: mini),
          ],
          child: Observer(
            builder: (_) => MaterialApp(
              locale: settings.appLanguage.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: themes.light,
              navigatorObservers: [OnsetShell.routeObserver],
              home: const Home(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(settings.appLanguage, AppLanguage.fr);
      expect(find.text(french.languagePromptTitle), findsOneWidget);
      // The shell under it too.
      expect(find.text(french.shellSectionHome), findsOneWidget);
      // Not answered until Continue.
      expect(settings.languagePromptVersion, 0);
      await tester.tap(find.text(french.languagePromptConfirm));
      await tester.pumpAndSettle();
      expect(settings.appLanguage, AppLanguage.fr);
      expect(settings.languagePromptVersion, kLanguagePromptVersion);
      await close(tester);
    });

    testWidgets('a page opened while the tile lands: asked once it closes', (
      tester,
    ) async {
      savedBeforeFrench();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: FakeAuthStore()),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchClipService>.value(value: clips),
            Provider<TwitchVodService>.value(value: vods),
            Provider<TwitchHypeTrainService>.value(
              value: MockHypeTrainService(),
            ),
            Provider<ActivityStore>.value(value: activity),
            Provider<WhisperStore>.value(value: whispers),
            Provider<MiniPlayerStore>.value(value: mini),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: themes.light,
            navigatorObservers: [
              LaunchIntro.navigatorObserver,
              OnsetShell.routeObserver,
            ],
            builder: (context, child) =>
                LaunchIntro(slotKey: OnsetShell.markKey, child: child!),
            home: const Scaffold(body: Text('onboarding')),
          ),
        ),
      );
      await tester.pump();
      expect(
        LaunchIntro.land(
          from: const Rect.fromLTWH(159, 386, 72, 72),
          onCovered: () => navigator.currentState!.pushAndRemoveUntil(
            PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              pageBuilder: (_, _, _) => const Home(),
            ),
            (_) => false,
          ),
        ),
        isTrue,
      );
      await tester.pump();
      await tester.pump(LaunchIntro.landingDuration * 0.3);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Home), findsOneWidget);
      // Home is in front, waiting for the tile; a link opens a page.
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('channel')),
        ),
      );
      await tester.pump(LaunchIntro.landingDuration);
      await settle(tester);
      expect(find.text('channel'), findsOneWidget);
      expect(find.text(english.languagePromptTitle), findsNothing);

      navigator.currentState!.pop();
      await settle(tester);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      await close(tester);
    });

    testWidgets('the update offer waits for the question: never both at '
        'once', (tester) async {
      savedBeforeFrench();
      final updater = _MockUpdater();
      when(() => updater.enabled).thenReturn(true);
      when(() => updater.removeInstalledDownloads()).thenAnswer((_) async {});
      when(() => updater.check()).thenAnswer(
        (_) async => const UpdateAvailable(
          OnsetRelease(
            build: 2023,
            tag: 'build-2023',
            notes: 'Faster chat',
            apkAssetId: 1,
            shaAssetId: 2,
            apkSize: 1024,
          ),
          2020,
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: FakeAuthStore()),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchClipService>.value(value: clips),
            Provider<TwitchVodService>.value(value: vods),
            Provider<TwitchHypeTrainService>.value(
              value: MockHypeTrainService(),
            ),
            Provider<ActivityStore>.value(value: activity),
            Provider<WhisperStore>.value(value: whispers),
            Provider<MiniPlayerStore>.value(value: mini),
            Provider<OnsetUpdater>.value(value: updater),
          ],
          child: MaterialApp(
            theme: themes.light,
            navigatorObservers: [OnsetShell.routeObserver],
            home: const Home(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => updater.check()).called(1);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      expect(find.text('Update available'), findsNothing);

      await tester.tap(find.text(english.languagePromptConfirm));
      await tester.pumpAndSettle();
      expect(find.text(english.languagePromptTitle), findsNothing);
      expect(find.text('Update available'), findsWidgets);
      await close(tester);
    });

    testWidgets('waits while a page covers Home, then asks', (tester) async {
      savedBeforeFrench();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: FakeAuthStore()),
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchApi>.value(value: api),
            Provider<TwitchClipService>.value(value: clips),
            Provider<TwitchVodService>.value(value: vods),
            Provider<TwitchHypeTrainService>.value(
              value: MockHypeTrainService(),
            ),
            Provider<ActivityStore>.value(value: activity),
            Provider<WhisperStore>.value(value: whispers),
            Provider<MiniPlayerStore>.value(value: mini),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: themes.light,
            navigatorObservers: [OnsetShell.routeObserver],
            home: const Scaffold(body: Text('onboarding')),
          ),
        ),
      );
      final onboarding = ModalRoute.of(
        tester.element(find.text('onboarding')),
      )!;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('channel')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.replace(
        oldRoute: onboarding,
        newRoute: PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const Home(),
        ),
      );
      await settle(tester);
      expect(find.text('channel'), findsOneWidget);
      expect(find.text(english.languagePromptTitle), findsNothing);

      navigator.currentState!.pop();
      await settle(tester);
      expect(find.text(english.languagePromptTitle), findsOneWidget);
      await close(tester);
    });
  });

  group('in French', () {
    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        // The shell and every section's empty state (each screen's
        // content has its own French test), in French, then in English.
        for (final locale in sweepLocales) {
          testWidgets('Following, Live, Clips, Browse, Activity, '
              '$sizeName, text ×$scale${sweepName(locale)}', (tester) async {
            final words = lookupAppLocalizations(locale);
            await pump(
              tester,
              size: size,
              auth: FakeAuthStore(loggedIn: true),
              locale: locale,
              textScale: scale,
            );
            expect(find.text(words.streamListEmptyFollowed), findsOneWidget);
            await expectFrenchThroughout(tester, 'Following');

            for (final tab in [words.shellFeedLive, words.shellFeedClips]) {
              await tester.tap(find.text(tab).first);
              await tester.pump();
              await tester.pump(const Duration(seconds: 1));
              await expectFrenchThroughout(tester, tab);
            }

            await tester.tap(nav('browse'));
            await tester.pumpAndSettle();
            await expectFrenchThroughout(tester, 'Browse › categories');
            await tester.tap(find.text(words.shellBrowseLiveChannels).first);
            await tester.pumpAndSettle();
            await expectFrenchThroughout(tester, 'Browse › live channels');

            await tester.tap(nav('activity'));
            await tester.pumpAndSettle();
            expect(find.text(words.activityEmpty), findsOneWidget);
            await expectFrenchThroughout(tester, 'Activity');
            await close(tester);
          });
        }
      }
    }
  });
}

class _MockUpdater extends Mock implements OnsetUpdater {}

class _RouteNames extends NavigatorObserver {
  _RouteNames(this.names);

  final List<String?> names;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}
