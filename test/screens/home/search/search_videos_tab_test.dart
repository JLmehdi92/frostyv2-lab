import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockVodService extends Mock implements TwitchVodService {}

/// A result tab, by its label.
Finder tab(String label) =>
    find.descendant(of: find.byType(ShellTabs), matching: find.text(label));

/// Taps a result tab, scrolling the row to it first (the test font is
/// wider than Inter).
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.ensureVisible(tab(label));
  await tester.pump();
  await tester.tap(tab(label));
}

Vod _vod(String id, String title) => Vod(
  id: id,
  title: title,
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 10,
  ownerId: '42',
  ownerLogin: 'speedy',
  ownerDisplayName: 'Speedy',
);

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late MockVodService vods;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockTwitchApi();
    auth = MockAuthStore();
    vods = MockVodService();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(null);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Completer<UserTwitch>().future);
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], null));
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: MaterialApp(
          home: Scaffold(body: Search(scrollController: ScrollController())),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> typeQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    // The result tabs slide in.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the tabs show only once something is searched', (tester) async {
    await pumpSearch(tester);

    expect(tab('Videos'), findsNothing);

    await typeQuery(tester, 'mario');

    for (final label in ['Top', 'Channels', 'Categories', 'Videos']) {
      expect(tab(label), findsOneWidget);
    }
  });

  testWidgets('the Videos tab lists the matching videos', (tester) async {
    when(() => vods.searchVideos('mario')).thenAnswer(
      (_) async => VodSearchPage(items: [_vod('1', 'Any% world record')]),
    );
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');

    verifyNever(() => vods.searchVideos(any()));
    await tapTab(tester, 'Videos');
    await tester.pumpAndSettle();

    expect(find.byType(VodCard), findsOneWidget);
    expect(find.text('Any% world record'), findsOneWidget);
    expect(find.text('Speedy'), findsOneWidget, reason: 'names the channel');
  });

  testWidgets('a new query refreshes the Videos tab', (tester) async {
    when(
      () => vods.searchVideos('mario'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('1', 'Mario run')]));
    when(
      () => vods.searchVideos('zelda'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('2', 'Zelda run')]));
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');
    await tapTab(tester, 'Videos');
    await tester.pumpAndSettle();

    await typeQuery(tester, 'zelda');
    await tester.pumpAndSettle();

    expect(find.text('Zelda run'), findsOneWidget);
    expect(find.text('Mario run'), findsNothing);
  });

  testWidgets('no video says so, like Twitch', (tester) async {
    when(
      () => vods.searchVideos('nothing'),
    ).thenAnswer((_) async => const VodSearchPage(items: []));
    await pumpSearch(tester);
    await typeQuery(tester, 'nothing');
    await tapTab(tester, 'Videos');
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('a failed search offers to try again', (tester) async {
    var calls = 0;
    when(() => vods.searchVideos('mario')).thenAnswer((_) async {
      if (calls++ == 0) throw const VodApiException('boom');
      return VodSearchPage(items: [_vod('1', 'Mario run')]);
    });
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');
    await tapTab(tester, 'Videos');
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load videos.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Mario run'), findsOneWidget);
  });

  testWidgets('the Channels tab shows the channels alone', (tester) async {
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');

    expect(find.text('No matching categories'), findsOneWidget);
    await tapTab(tester, 'Channels');
    await tester.pumpAndSettle();

    expect(find.text('No matching categories'), findsNothing);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    when(() => vods.searchVideos('mario')).thenAnswer(
      (_) async => VodSearchPage(
        items: [for (var i = 0; i < 25; i++) _vod('$i', 'Run $i')],
        cursor: 'MjU=',
        hasMore: true,
      ),
    );
    when(
      () => vods.searchVideos('mario', cursor: 'MjU='),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('99', 'Last run')]));
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');
    await tapTab(tester, 'Videos');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Last run'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Last run'), findsOneWidget);
    verify(() => vods.searchVideos('mario', cursor: 'MjU=')).called(1);
  });

  testWidgets('failed channels and categories: Try again searches again', (
    tester,
  ) async {
    var channelCalls = 0;
    var categoryCalls = 0;
    when(() => api.searchChannels(query: 'mario')).thenAnswer((_) async {
      if (channelCalls++ == 0) throw Exception('offline');
      return [];
    });
    when(() => api.searchCategories(query: 'mario')).thenAnswer((_) async {
      if (categoryCalls++ == 0) throw Exception('offline');
      return const CategoriesTwitch([], null);
    });
    await pumpSearch(tester);
    await typeQuery(tester, 'mario');
    await tester.pumpAndSettle();
    await tapTab(tester, 'Channels');
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load channels.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(channelCalls, 2);
    expect(categoryCalls, 2);
    expect(find.text('Couldn’t load channels.'), findsNothing);
  });
}
