import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/screens/clips/clips_feed_screen.dart';
import 'package:frosty/screens/home/home.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/home/shell/onset_shell.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/home/top/categories/categories.dart';
import 'package:frosty/screens/settings/settings.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockClipService extends Mock implements TwitchClipService {}

class FakeAuthStore extends Mock implements AuthStore {
  @override
  bool get isLoggedIn => false;
}

void main() {
  late MockTwitchApi api;
  late MockClipService clips;
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
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: FakeAuthStore()),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchClipService>.value(value: clips),
          Provider<ActivityStore>.value(value: activity),
          Provider<WhisperStore>.value(value: whispers),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
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
    expect(find.text('No top streams'), findsOneWidget);

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
    expect(find.text("Hooray! You're up to date"), findsOneWidget);

    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    // Settings inside the shell: no app bar of its own.
    expect(find.byType(Settings), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byTooltip('View source on GitHub'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('search opens over the shell, and back returns', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(nav('browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search channels, categories or videos'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
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
    expect(find.text('No top streams'), findsOneWidget);

    // Back from Profile: Home.
    await tester.tap(nav('profile'));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('No top streams'), findsOneWidget);
    expect(find.byType(Settings), findsNothing);

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
    expect(find.text('No top streams'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the mini player keeps under the header and above the bar', (
    tester,
  ) async {
    await pump(tester);
    // Live's header (56 + 44) and the floating bar (14 + 64).
    expect(mini.shellChrome, const EdgeInsets.only(top: 100, bottom: 78));

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

  testWidgets('a count changing does not rebuild the pages', (tester) async {
    await pump(tester);
    final list = tester.widget(find.byType(StreamsList));
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
    expect(identical(tester.widget(find.byType(StreamsList)), list), isTrue);
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

  testWidgets('"Open the app on" Browse opens Browse', (tester) async {
    settings.startTab = HomeTab.browse;
    await pump(tester);
    expect(find.byType(Categories), findsOneWidget);
    expect(find.text('Browse'), findsWidgets);
    await close(tester);
  });

  testWidgets('a value saved before the shell still opens its place', (
    tester,
  ) async {
    settings = SettingsStore.fromJson({'startTab': 'search'})
      ..keepScreenAwake = false;
    await pump(tester);
    expect(find.byType(Categories), findsOneWidget);
    await close(tester);
  });
}
