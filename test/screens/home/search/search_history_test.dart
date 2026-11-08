import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/search/stores/search_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'search_history': ['xqc', 'lirik', 'chess'],
    });
  });

  test('one past search can be removed and stays removed', () async {
    final store = SearchStore(
      authStore: MockAuthStore(),
      twitchApi: MockTwitchApi(),
    );
    // The constructor loads the history.
    await pumpEventQueue();

    store.removeFromHistory('lirik');

    expect(store.searchHistory, ['xqc', 'chess']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_history'), ['xqc', 'chess']);
    store.dispose();
  });

  test('a search asked for by a link fills the field and runs', () async {
    final api = MockTwitchApi();
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], null));
    final store = SearchStore(authStore: MockAuthStore(), twitchApi: api);
    await pumpEventQueue();

    store.searchFor('speed runs');

    expect(store.textEditingController.text, 'speed runs');
    expect(store.searchText, 'speed runs');
    expect(store.lastQuery, 'speed runs');
    verify(() => api.searchChannels(query: 'speed runs')).called(1);
    store.dispose();
  });

  test(
    'typing suggests past searches, then Twitch suggestions first',
    () async {
      final api = MockTwitchApi();
      when(
        () => api.searchChannels(query: any(named: 'query')),
      ).thenAnswer((_) async => []);
      when(
        () => api.searchCategories(query: any(named: 'query')),
      ).thenAnswer((_) async => const CategoriesTwitch([], null));
      final asked = <String>[];
      final store = SearchStore(
        authStore: MockAuthStore(),
        twitchApi: api,
        suggest: (fragment) async {
          asked.add(fragment);
          return [
            const SearchSuggestion(
              text: 'xQc',
              kind: SearchSuggestionKind.channel,
              login: 'xqc',
            ),
          ];
        },
      );
      await pumpEventQueue();

      store.textEditingController.text = 'x';
      store.onSearchTextChanged('x');
      expect(store.suggestions.map((s) => s.text), ['xqc']);

      await Future<void>.delayed(SearchStoreBase.suggestDelay * 2);
      expect(asked, ['x']);
      expect(store.suggestions.map((s) => (s.text, s.kind)), [
        ('xQc', SearchSuggestionKind.channel),
        ('xqc', SearchSuggestionKind.text),
      ]);

      store.handleQuery('x');
      expect(store.suggestions, isEmpty);
      store.dispose();
    },
  );

  test('failed suggestions keep the past searches', () async {
    final api = MockTwitchApi();
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    when(
      () => api.searchCategories(query: any(named: 'query')),
    ).thenAnswer((_) async => const CategoriesTwitch([], null));
    final store = SearchStore(
      authStore: MockAuthStore(),
      twitchApi: api,
      suggest: (_) async => throw Exception('gql'),
    );
    await pumpEventQueue();
    store.textEditingController.text = 'l';
    store.onSearchTextChanged('l');
    await Future<void>.delayed(SearchStoreBase.suggestDelay * 2);
    expect(store.suggestions.map((s) => s.text), ['lirik']);
    store.onSearchTextChanged('');
    expect(store.suggestions, isEmpty);
    store.dispose();
  });

  testWidgets('each past search has its own remove button', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: MockAuthStore()),
          Provider<TwitchApi>.value(value: MockTwitchApi()),
        ],
        child: MaterialApp(
          home: Scaffold(body: Search(scrollController: controller)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('lirik'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove lirik from history'));
    await tester.pump();

    expect(find.text('lirik'), findsNothing);
    expect(find.text('xqc'), findsOneWidget);
    expect(find.text('chess'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test(
    'related lives: the matched category\'s live channels, minus those listed',
    () async {
      final api = MockTwitchApi();
      when(() => api.searchChannels(query: any(named: 'query'))).thenAnswer(
        (_) async => [
          const ChannelQuery(
            broadcasterLogin: 'a',
            displayName: 'A',
            id: '1',
            isLive: true,
            startedAt: '',
          ),
        ],
      );
      when(() => api.searchCategories(query: any(named: 'query'))).thenAnswer(
        (_) async =>
            const CategoriesTwitch([CategoryTwitch('', '33', 'Chess')], null),
      );
      when(() => api.getStreamsUnderCategory(gameId: '33')).thenAnswer(
        (_) async => StreamsTwitch([
          for (final id in ['1', '2', '3', '4', '5', '6', '7', '8'])
            StreamTwitch(id, 'l$id', 'N$id', '33', 'Chess', 'T', 5, '', ''),
        ], const {}),
      );
      final store = SearchStore(authStore: MockAuthStore(), twitchApi: api);
      await pumpEventQueue();

      store.searchFor('chess');
      await pumpEventQueue();

      expect(store.relatedLives.map((s) => s.userId), [
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
      ]);
      store.onSearchTextChanged('');
      expect(store.relatedLives, isEmpty);
      store.dispose();
    },
  );

  test('related lives stay hidden when Twitch fails', () async {
    final api = MockTwitchApi();
    when(
      () => api.searchChannels(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    when(() => api.searchCategories(query: any(named: 'query'))).thenAnswer(
      (_) async =>
          const CategoriesTwitch([CategoryTwitch('', '33', 'Chess')], null),
    );
    when(
      () => api.getStreamsUnderCategory(gameId: '33'),
    ).thenThrow(Exception('down'));
    final store = SearchStore(authStore: MockAuthStore(), twitchApi: api);
    await pumpEventQueue();
    store.searchFor('chess');
    await pumpEventQueue();
    expect(store.relatedLives, isEmpty);
    store.dispose();
  });
}
