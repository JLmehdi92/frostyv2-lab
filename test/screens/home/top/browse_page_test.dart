import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/browse_page.dart';
import 'package:onset/screens/home/top/categories/categories.dart';
import 'package:onset/screens/home/top/categories/category_card.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

/// A logged-out viewer with no blocked channel.
MockAuthStore loggedOut() {
  final auth = MockAuthStore();
  final user = MockUserStore();
  when(() => auth.isLoggedIn).thenReturn(false);
  when(() => auth.user).thenReturn(user);
  when(() => auth.twitchWebToken).thenReturn(null);
  when(() => user.details).thenReturn(null);
  when(() => user.blockedUsers).thenReturn(ObservableList());
  return auth;
}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class MockDirectoryService extends Mock implements TwitchDirectoryService {}

const _categories = [
  CategoryTwitch('https://art/{width}x{height}.jpg', '509658', 'Just Chatting'),
  CategoryTwitch(
    'https://art/{width}x{height}.jpg',
    '21779',
    'League of Legends',
  ),
  CategoryTwitch(
    'https://art/{width}x{height}.jpg',
    '32982',
    'Grand Theft Auto V',
  ),
  CategoryTwitch('https://art/{width}x{height}.jpg', '32399', 'Counter-Strike'),
];

StreamTwitch _stream(String id, String game) => StreamTwitch(
  id,
  'streamer$id',
  'Streamer$id',
  game,
  'Game',
  'Title $id',
  2104,
  DateTime.now().toUtc().toIso8601String(),
  'https://thumb-{width}x{height}.jpg',
  tags: const ['Français', 'Chill'],
);

void main() {
  late MockTwitchApi api;
  late MockDirectoryService directory;
  late HomeStore home;

  setUpAll(() => registerFallbackValue(StreamSort.recent));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockTwitchApi();
    directory = MockDirectoryService();
    when(
      () => api.getTopCategories(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const CategoriesTwitch(_categories, {}));
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => StreamsTwitch([_stream('1', '509658')], const {}),
    );
    when(() => api.getCategory(gameId: any(named: 'gameId'))).thenAnswer(
      (invocation) async => CategoriesTwitch([
        _categories.firstWhere(
          (c) => c.id == invocation.namedArguments[#gameId],
        ),
      ], const {}),
    );
    when(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (invocation) async => StreamsTwitch([
        _stream('2', invocation.namedArguments[#gameId] as String),
      ], const {}),
    );
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Completer<UserTwitch>().future);
    home = HomeStore(authStore: loggedOut());
    addTearDown(home.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.dark,
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
    final auth = loggedOut();
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchVodService>.value(value: MockVodService()),
          Provider<TwitchClipService>.value(value: MockClipService()),
          Provider<TwitchDirectoryService>.value(value: directory),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
        ],
        child: MaterialApp(
          locale: app.locale,
          supportedLocales: app.supportedLocales,
          localizationsDelegates: app.delegates,
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: app.builder,
          home: Scaffold(
            body: Observer(
              builder: (context) => BrowsePage(
                tab: home.browseTab,
                categoriesController: home.categoriesScrollController,
                liveController: home.browseLiveScrollController,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('phone: a three-column grid that opens the category '
        '(${mode.name})', (tester) async {
      await pump(tester, mode: mode);
      expect(tester.takeException(), isNull);

      final tiles = find.byType(CategoryTile);
      expect(tiles, findsNWidgets(_categories.length));
      // Three per row, the fourth under the first.
      final first = tester.getRect(tiles.at(0));
      expect(tester.getRect(tiles.at(1)).top, first.top);
      expect(tester.getRect(tiles.at(2)).top, first.top);
      expect(tester.getRect(tiles.at(3)).left, first.left);
      expect(tester.getRect(tiles.at(3)).top, greaterThan(first.bottom));
      expect(first.width, closeTo((390 - 32 - 24) / 3, 0.5));

      await tester.tap(find.text('League of Legends'));
      await settle(tester);
      expect(find.byType(CategoryStreams), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the live channels tab is the top streams', (tester) async {
    await pump(tester);
    runInActionTab(home, BrowseTab.live);
    await settle(tester);

    final list = tester.widget<StreamsList>(find.byType(StreamsList));
    expect(list.listType, ListType.top);
    expect(list.scrollController, home.browseLiveScrollController);
    expect(find.text('Streamer1'), findsOneWidget);
    // Back on Categories: the grid was kept, not asked for again.
    runInActionTab(home, BrowseTab.categories);
    await settle(tester);
    expect(find.byType(CategoryTile), findsNWidgets(_categories.length));
    verify(() => api.getTopCategories()).called(1);
  });

  testWidgets('landscape tablet: the categories beside the chosen one', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854));
    expect(tester.takeException(), isNull);
    expect(find.text('Top categories'), findsOneWidget);
    expect(find.text('Most watched first'), findsOneWidget);

    // The first category is shown at once, in the pane.
    expect(find.byType(CategoryView), findsOneWidget);
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '509658',
    );
    expect(
      tester.widget<CategoryTile>(find.byType(CategoryTile).first).selected,
      isTrue,
    );

    // Another category takes the pane; nothing is pushed.
    await tester.tap(find.text('Counter-Strike').first);
    await settle(tester);
    expect(find.byType(CategoryStreams), findsNothing);
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '32399',
    );
    expect(find.text('Counter-Strike'), findsNWidgets(2));
    // Its live streams in the pane, their viewers in words.
    expect(find.text('Streamer2'), findsOneWidget);
    expect(find.text('2,104 viewers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait tablet: a grid that opens the category\'s page', (
    tester,
  ) async {
    await pump(tester, size: const Size(854, 1280), mode: ThemeMode.light);
    expect(find.byType(CategoryView), findsNothing);
    final tiles = find.byType(CategoryTile);
    // Every category on the first row (six fit at 854).
    final top = tester.getRect(tiles.first).top;
    for (var i = 0; i < _categories.length; i++) {
      expect(tester.getRect(tiles.at(i)).top, top);
    }
    await tester.tap(find.text('Grand Theft Auto V'));
    await settle(tester);
    expect(find.byType(CategoryStreams), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the tablet keeps the categories and the choice', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854));
    await tester.tap(find.text('Grand Theft Auto V').first);
    await settle(tester);

    tester.view.physicalSize = const Size(854, 1280);
    await settle(tester);
    expect(find.byType(CategoryView), findsNothing);
    expect(find.byType(Categories), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 854);
    await settle(tester);
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '32982',
    );
    // One request for the whole time: the grid and its store were kept.
    verify(() => api.getTopCategories()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion: the pane changes without sliding', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854), reduceMotion: true);
    await tester.tap(find.text('League of Legends').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final pane = find
        .ancestor(
          of: find.byType(CategoryView).first,
          matching: find.byType(AnimatedSwitcher),
        )
        .first;
    expect(
      find.descendant(of: pane, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the next page loads at the end, skeletons meanwhile', (
    tester,
  ) async {
    final next = Completer<CategoriesTwitch>();
    when(() => api.getTopCategories()).thenAnswer(
      (_) async => CategoriesTwitch(
        [
          for (var i = 0; i < 30; i++)
            CategoryTwitch('https://art/{width}x{height}.jpg', '$i', 'Game $i'),
        ],
        const {'cursor': 'page2'},
      ),
    );
    when(
      () => api.getTopCategories(cursor: 'page2'),
    ).thenAnswer((_) => next.future);
    await pump(tester);

    await tester.scrollUntilVisible(
      find.text('Game 29'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    verify(() => api.getTopCategories(cursor: 'page2')).called(1);
    expect(find.byType(CategoryTileSkeleton), findsWidgets);

    next.complete(
      const CategoriesTwitch([
        CategoryTwitch('https://art/{width}x{height}.jpg', '99', 'Last game'),
      ], {}),
    );
    await settle(tester);
    expect(find.byType(CategoryTileSkeleton), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Last game'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page that fails is not asked for again by itself', (
    tester,
  ) async {
    var pages = 0;
    when(() => api.getTopCategories()).thenAnswer(
      (_) async => CategoriesTwitch(
        [
          for (var i = 0; i < 30; i++)
            CategoryTwitch('https://art/{width}x{height}.jpg', '$i', 'Game $i'),
        ],
        const {'cursor': 'page2'},
      ),
    );
    when(() => api.getTopCategories(cursor: 'page2')).thenAnswer((_) async {
      pages++;
      throw Exception('offline');
    });
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text('Game 29'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await settle(tester);
    expect(pages, 1);
    // The grid stays, with a way to try the page again.
    expect(find.text('Game 29'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Try again'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(pages, 2);
  });

  testWidgets('a refresh adds no row of loading tiles', (tester) async {
    final refresh = Completer<CategoriesTwitch>();
    await pump(tester);
    when(() => api.getTopCategories()).thenAnswer((_) => refresh.future);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await settle(tester);
    expect(find.byType(CategoryTile), findsNWidgets(_categories.length));
    expect(find.byType(CategoryTileSkeleton), findsNothing);
    refresh.complete(const CategoriesTwitch(_categories, {}));
    await settle(tester);
  });

  for (final size in const [Size(1024, 768), Size(1024, 600)]) {
    testWidgets('a narrow pane keeps the tablet\'s tiles '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      await pump(tester, size: size);
      expect(find.byType(CategoryView), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is StreamCard && widget.tile),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the category shown first stays when a refresh reorders', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854));
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '509658',
    );
    when(() => api.getTopCategories()).thenAnswer(
      (_) async => CategoriesTwitch(_categories.reversed.toList(), const {}),
    );
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await settle(tester);
    expect(
      tester.widget<CategoryTile>(find.byType(CategoryTile).first).category.id,
      '32399',
    );
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '509658',
    );
  });

  testWidgets('the pane keeps a category a refresh no longer lists', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 854));
    await tester.tap(find.text('Counter-Strike').first);
    await settle(tester);
    when(() => api.getTopCategories()).thenAnswer(
      (_) async => CategoriesTwitch(_categories.take(2).toList(), const {}),
    );
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await settle(tester);
    expect(find.byType(CategoryTile), findsNWidgets(2));
    expect(
      tester.widget<CategoryView>(find.byType(CategoryView)).categoryId,
      '32399',
    );
  });

  testWidgets('a short landscape tablet keeps the pane\'s grid', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 610));
    // The tiles of the pane's streams: thumbnail on top, three a row.
    expect(
      find.byWidgetPredicate((widget) => widget is StreamCard && widget.tile),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no categories says so, with a way to try again', (tester) async {
    when(
      () => api.getTopCategories(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const CategoriesTwitch([], {}));
    await pump(tester);
    expect(find.text('No top categories'), findsOneWidget);

    when(
      () => api.getTopCategories(cursor: any(named: 'cursor')),
    ).thenThrow(Exception('boom'));
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await settle(tester);
    expect(find.text('Something went wrong loading categories'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('in French', () {
    final french = lookupAppLocalizations(fr);

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('categories and live channels, $sizeName, text ×$scale', (
          tester,
        ) async {
          await pump(tester, size: size, locale: fr, textScale: scale);
          if (size.shortestSide >= 600 && size.width > size.height) {
            expect(find.text(french.categoriesRailTitle), findsOneWidget);
          }
          await expectFrenchThroughout(tester, 'categories');
          runInActionTab(home, BrowseTab.live);
          await settle(tester);
          await expectFrenchThroughout(tester, 'live channels');
        });
      }
    }
  });
}

/// Lets transitions and loads finish (the skeletons' sheen never settles:
/// pictures never load in tests).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Picks a Browse tab, as the shell's header does.
void runInActionTab(HomeStore home, BrowseTab tab) => home.selectBrowseTab(tab);
