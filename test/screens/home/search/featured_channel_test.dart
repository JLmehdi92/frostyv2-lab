import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/home/search/featured_channel.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

ChannelQuery channel(
  String login, {
  String? name,
  bool live = false,
  String game = '',
  String title = '',
}) => ChannelQuery(
  broadcasterLogin: login,
  displayName: name ?? login,
  id: 'id_$login',
  isLive: live,
  startedAt: live ? DateTime.now().toUtc().toIso8601String() : '',
  gameName: game,
  title: title,
);

void main() {
  group('featuredChannel', () {
    final results = [
      channel('xqcow'),
      channel('xqc', name: 'xQc'),
      channel('xqc_fan'),
    ];

    test('the exact login wins, whatever the case and spaces', () {
      expect(featuredChannel(results, ' XQC ')?.broadcasterLogin, 'xqc');
    });

    test('the exact display name counts too', () {
      final named = [channel('gotaga_tv', name: 'Gotaga')];
      expect(featuredChannel(named, 'gotaga'), named.single);
    });

    test('a partial match is not featured', () {
      expect(featuredChannel(results, 'xq'), isNull);
      expect(featuredChannel(results, ''), isNull);
      expect(featuredChannel(const [], 'xqc'), isNull);
    });
  });

  group('search results', () {
    late MockTwitchApi api;
    late MockAuthStore auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = MockTwitchApi();
      auth = MockAuthStore();
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
      when(() => api.searchChannels(query: any(named: 'query'))).thenAnswer(
        (_) async => [
          channel('xqcow'),
          channel(
            'xqc',
            name: 'xQc',
            live: true,
            game: 'Just Chatting',
            title: 'react andy',
          ),
        ],
      );
    });

    testWidgets('the exact match comes first, bigger, and only once', (
      tester,
    ) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStore>.value(value: auth),
            Provider<TwitchApi>.value(value: api),
          ],
          child: MaterialApp(
            home: Scaffold(body: Search(scrollController: controller)),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'xqc');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();

      expect(find.byType(FeaturedChannelCard), findsOneWidget);
      expect(find.text('xQc'), findsOneWidget);
      expect(find.text('Just Chatting'), findsOneWidget);
      expect(find.text('react andy'), findsOneWidget);
      expect(find.text('xqcow'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(FeaturedChannelCard)).dy,
        lessThan(tester.getTopLeft(find.text('xqcow')).dy),
      );

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('an offline exact match says so', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<TwitchApi>.value(value: api)],
          child: MaterialApp(
            home: Scaffold(
              body: FeaturedChannelCard(
                channel: channel('lirik', game: 'Hytale', title: 'later'),
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Offline · Hytale'), findsOneWidget);
      expect(find.text('later'), findsOneWidget);
    });
  });
}
