import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockDirectoryService extends Mock implements TwitchDirectoryService {}

StreamTwitch stream(String id) =>
    StreamTwitch(id, 'login$id', 'Name$id', '1', 'Game', 'Title', 10, '', '');

void main() {
  late MockTwitchApi api;
  late MockDirectoryService directory;
  late SettingsStore settings;

  setUpAll(() => registerFallbackValue(StreamSort.recent));

  setUp(() {
    api = MockTwitchApi();
    directory = MockDirectoryService();
    settings = SettingsStore.fromJson({});
    when(() => api.getCategory(gameId: any(named: 'gameId'))).thenAnswer(
      (_) async =>
          const CategoriesTwitch([CategoryTwitch('', '33', 'Game')], null),
    );
    when(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => StreamsTwitch([stream('helix')], {'cursor': 'c'}),
    );
    when(
      () => directory.getCategoryStreams(
        gameId: any(named: 'gameId'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((invocation) async {
      final sort = invocation.namedArguments[#sort] as StreamSort;
      return StreamsTwitch([stream(sort.name)], const {});
    });
    when(
      () => directory.getTagStreams(
        tag: any(named: 'tag'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([stream('tagged')], const {}));
  });

  ListStore category() => ListStore(
    authStore: MockAuthStore(),
    settingsStore: settings,
    twitchApi: api,
    listType: ListType.category,
    categoryId: '33',
    directoryService: directory,
  );

  test('a category starts on Helix and pages', () async {
    final store = category();
    await pumpEventQueue();

    expect(store.allStreams.single.userId, 'helix');
    expect(store.hasMore, isTrue);
    verifyNever(
      () => directory.getCategoryStreams(
        gameId: any(named: 'gameId'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    );
    store.dispose();
  });

  test('another order asks GQL once, with the language', () async {
    settings.streamLanguage = 'fr';
    final store = category();
    await pumpEventQueue();

    store.sort = StreamSort.recent;
    await pumpEventQueue();

    verify(
      () => directory.getCategoryStreams(
        gameId: '33',
        sort: StreamSort.recent,
        language: 'fr',
      ),
    ).called(1);
    expect(store.allStreams.single.userId, 'recent');
    expect(store.hasMore, isFalse);

    store.sort = StreamSort.viewersHigh;
    await pumpEventQueue();
    expect(store.allStreams.single.userId, 'helix');
    expect(store.hasMore, isTrue);
    store.dispose();
  });

  test('a tag list asks GQL in its order and follows the language', () async {
    final store = ListStore(
      authStore: MockAuthStore(),
      settingsStore: settings,
      twitchApi: api,
      listType: ListType.tag,
      tag: 'Chill',
      directoryService: directory,
      sort: StreamSort.recommended,
    );
    await pumpEventQueue();

    verify(
      () => directory.getTagStreams(tag: 'Chill', sort: StreamSort.recommended),
    ).called(1);
    expect(store.allStreams.single.userId, 'tagged');
    expect(store.hasMore, isFalse);

    settings.streamLanguage = 'de';
    await pumpEventQueue();
    verify(
      () => directory.getTagStreams(
        tag: 'Chill',
        sort: StreamSort.recommended,
        language: 'de',
      ),
    ).called(1);
    verifyNever(() => api.getCategory(gameId: any(named: 'gameId')));
    store.dispose();
  });

  test('a failing GQL answer shows an error, not an empty list', () async {
    when(
      () => directory.getCategoryStreams(
        gameId: any(named: 'gameId'),
        sort: any(named: 'sort'),
        language: any(named: 'language'),
      ),
    ).thenThrow(const DirectoryApiException('failed integrity check'));
    final store = category();
    await pumpEventQueue();

    store.sort = StreamSort.viewersLow;
    await pumpEventQueue();

    expect(
      store.error,
      'Twitch could not sort by Viewers (low to high). '
      'Viewers (high to low) still works.',
    );

    // A new order clears it while it loads.
    store.sort = StreamSort.viewersHigh;
    expect(store.error, isNull);
    await pumpEventQueue();
    expect(store.allStreams.single.userId, 'helix');
    store.dispose();
  });

  test('a Helix page loading when the order changes is dropped', () async {
    final store = category();
    await pumpEventQueue();
    final pending = Completer<StreamsTwitch>();
    when(
      () => api.getStreamsUnderCategory(gameId: '33', cursor: 'c'),
    ).thenAnswer((_) => pending.future);
    final loadingMore = store.getStreams();

    store.sort = StreamSort.recent;
    await pumpEventQueue();
    pending.complete(StreamsTwitch([stream('stale')], {'cursor': 'c2'}));
    await loadingMore;

    expect(store.allStreams.map((s) => s.userId), ['recent']);
    expect(store.hasMore, isFalse);
    store.dispose();
  });

  test('only the last picked order fills the list', () async {
    final store = category();
    await pumpEventQueue();
    final slow = Completer<StreamsTwitch>();
    when(
      () => directory.getCategoryStreams(gameId: '33', sort: StreamSort.recent),
    ).thenAnswer((_) => slow.future);

    store.sort = StreamSort.recent;
    await pumpEventQueue();
    store.sort = StreamSort.viewersLow;
    await pumpEventQueue();
    slow.complete(StreamsTwitch([stream('recent')], const {}));
    await pumpEventQueue();

    expect(store.allStreams.map((s) => s.userId), ['viewersLow']);
    expect(store.isLoading, isFalse);
    store.dispose();
  });

  test('a failing category header does not stop paging', () async {
    when(
      () => api.getCategory(gameId: any(named: 'gameId')),
    ).thenThrow(const NotFoundException('gone'));
    final store = category();
    await pumpEventQueue();

    expect(store.categoryDetails, isNull);
    expect(store.isLoading, isFalse);
    expect(store.hasMore, isTrue);
    store.dispose();
  });

  test('a details-only store loads no streams and follows nothing', () async {
    final store = ListStore(
      authStore: MockAuthStore(),
      settingsStore: settings,
      twitchApi: api,
      listType: ListType.category,
      categoryId: '33',
      loadStreams: false,
    );
    await pumpEventQueue();
    settings.streamLanguage = 'fr';
    await pumpEventQueue();

    expect(store.categoryDetails?.id, '33');
    verifyNever(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    );
    store.dispose();
  });
}
