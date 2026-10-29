import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/search/featured_channel.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/home/search/search_results_channels.dart';
import 'package:frosty/screens/home/shell/shell_tabs.dart';
import 'package:frosty/screens/home/top/categories/category_card.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/theme.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockVodService extends Mock implements TwitchVodService {}

ChannelQuery _channel(String login, {bool live = false}) => ChannelQuery(
  broadcasterLogin: login,
  displayName: login,
  id: 'id_$login',
  isLive: live,
  startedAt: live ? DateTime.now().toUtc().toIso8601String() : '',
  gameName: 'Chess',
  title: live ? 'Blitz' : '',
);

CategoryTwitch _category(int i) =>
    CategoryTwitch('https://art/{width}x{height}.jpg', '$i', 'Chess $i');

Vod _vod(String id) => Vod(
  id: id,
  title: 'Opening $id',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 10,
  ownerId: '42',
  ownerLogin: 'gm',
  ownerDisplayName: 'GM',
);

/// A result tab, by its label.
Finder tab(String label) =>
    find.descendant(of: find.byType(ShellTabs), matching: find.text(label));

/// Lets loads and transitions finish (a skeleton's sheen never settles).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MockTwitchApi api;
  late MockVodService vods;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'search_history': ['chess', 'lirik'],
    });
    api = MockTwitchApi();
    vods = MockVodService();
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Completer<UserTwitch>().future);
    when(() => api.searchChannels(query: any(named: 'query'))).thenAnswer(
      (_) async => [
        _channel('chess', live: true),
        for (var i = 0; i < 8; i++) _channel('chess_fan$i', live: i.isEven),
      ],
    );
    when(() => api.searchCategories(query: any(named: 'query'))).thenAnswer(
      (_) async =>
          CategoriesTwitch([for (var i = 0; i < 6; i++) _category(i)], null),
    );
    when(
      () => vods.searchVideos(any(), cursor: any(named: 'cursor')),
    ).thenAnswer(
      (_) async =>
          VodSearchPage(items: [for (var i = 0; i < 8; i++) _vod('$i')]),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => auth.isLoggedIn).thenReturn(false);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const SearchScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
  }

  const sizes = [Size(390, 844), Size(1280, 854), Size(854, 1280)];
  for (final size in sizes) {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('history, then every tab '
          '(${size.width.toInt()}x${size.height.toInt()}, ${mode.name})', (
        tester,
      ) async {
        await pump(tester, size: size, mode: mode);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('lirik'), findsOneWidget);
        expect(find.byType(ShellTabs), findsNothing);
        expect(tester.takeException(), isNull);

        await search(tester, 'chess');
        expect(find.byType(FeaturedChannelCard), findsOneWidget);
        for (final label in ['Top', 'Channels', 'Categories', 'Videos']) {
          await tester.ensureVisible(tab(label));
          await tester.pump();
          await tester.tap(tab(label));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: label);
        }
      });
    }
  }

  testWidgets('phone: Top shows the first channels and categories, '
      '"See all" the rest', (tester) async {
    await pump(tester, size: const Size(390, 844));
    await search(tester, 'chess');

    expect(find.byType(FeaturedChannelCard), findsOneWidget);
    expect(find.byType(SearchChannelRow), findsNWidgets(5));
    // No videos on a phone's Top: they are not even asked for.
    expect(find.byType(VodCard), findsNothing);
    verifyNever(() => vods.searchVideos(any(), cursor: any(named: 'cursor')));

    await tester.tap(find.text('See all').first);
    await settle(tester);
    expect(tester.widget<ShellTabs>(find.byType(ShellTabs)).index, 1);
    expect(find.byType(SearchChannelRow), findsNWidgets(8));
    expect(find.text('Go to channel "chess"'), findsOneWidget);
  });

  testWidgets('tablet: Top has a Videos column with "See all"', (tester) async {
    await pump(tester, size: const Size(1280, 854));
    await search(tester, 'chess');

    expect(find.text('Videos'), findsNWidgets(2), reason: 'tab and column');
    expect(find.byType(VodCard), findsNWidgets(5));
    // The categories as box arts beside the channels.
    expect(find.byType(CategoryTile), findsNWidgets(4));
    final channels = tester.getTopLeft(find.byType(FeaturedChannelCard));
    final categories = tester.getTopLeft(find.byType(CategoryTile).first);
    final videos = tester.getTopLeft(find.byType(VodCard).first);
    expect(categories.dx, greaterThan(channels.dx));
    expect(videos.dx, greaterThan(categories.dx));
    verify(() => vods.searchVideos('chess')).called(1);

    await tester.tap(find.text('See all').last);
    await settle(tester);
    expect(tester.widget<ShellTabs>(find.byType(ShellTabs)).index, 3);
    expect(find.byType(VodCard), findsNWidgets(8));
    // The same answer: the column and the tab share the search.
    verifyNever(() => vods.searchVideos('chess'));
  });

  testWidgets('portrait tablet: the videos come under the channels', (
    tester,
  ) async {
    await pump(tester, size: const Size(854, 1280), mode: ThemeMode.light);
    await search(tester, 'chess');
    final channels = tester.getTopLeft(find.byType(FeaturedChannelCard));
    final videos = tester.getTopLeft(find.byType(VodCard).first);
    expect(videos.dy, greaterThan(channels.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Clear" forgets every past search', (tester) async {
    await pump(tester, size: const Size(390, 844));
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(find.text('No recent searches'), findsOneWidget);
    expect(find.text('lirik'), findsNothing);
  });

  testWidgets('a past search searches again', (tester) async {
    await pump(tester, size: const Size(1280, 854));
    await tester.tap(find.text('lirik'));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'lirik',
    );
    verify(() => api.searchChannels(query: 'lirik')).called(1);
  });

  testWidgets('the field: "Cancel" while empty, "Clear" once typed', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 844));
    await tester.tap(find.byType(TextField));
    await settle(tester);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    await search(tester, 'chess');
    expect(find.byTooltip('Clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('reduce motion: the tabs show at once', (tester) async {
    await pump(tester, size: const Size(390, 844), reduceMotion: true);
    await tester.enterText(find.byType(TextField), 'chess');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(find.byType(ShellTabs)).height, 44);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('results keep clear of a side cutout', (tester) async {
    tester.view.padding = const FakeViewPadding(left: 48);
    addTearDown(tester.view.resetPadding);
    await pump(tester, size: const Size(844, 390));
    await search(tester, 'chess');
    expect(
      tester.getTopLeft(find.byType(FeaturedChannelCard)).dx,
      greaterThanOrEqualTo(48 + 16),
    );
    expect(
      tester.getTopLeft(find.byType(SearchAvatar).at(1)).dx,
      greaterThanOrEqualTo(48 + 16),
    );
    expect(
      tester.getTopLeft(find.text('Channels').first).dx,
      greaterThanOrEqualTo(48 + 16),
    );

    tester.view.physicalSize = const Size(1280, 854);
    await settle(tester);
    expect(
      tester.getTopLeft(find.byType(FeaturedChannelCard)).dx,
      greaterThanOrEqualTo(48 + 28),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('"See all" is read once, with its section', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, size: const Size(390, 844));
    await search(tester, 'chess');
    expect(find.bySemanticsLabel('See all Channels'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'See all\nSee all')), findsNothing);
    expect(find.bySemanticsLabel('See all'), findsNothing);
    handle.dispose();
  });

  testWidgets('nothing is blurred under search until it is in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => SearchScreen.open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-transition: the page below (a live preview, a video) shows
    // through, and must not be blurred.
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    await settle(tester);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );

    // Leaving: no blur while the page slides away.
    Navigator.of(tester.element(find.byType(SearchScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    await settle(tester);
  });
}
