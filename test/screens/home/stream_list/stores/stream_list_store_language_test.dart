import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

StreamTwitch stream(String id) =>
    StreamTwitch(id, 'login$id', 'Name$id', '1', 'Game', 'Title', 10, '', '');

Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late SettingsStore settings;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    settings = SettingsStore.fromJson({});
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.details).thenReturn(const UserTwitch('me', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((invocation) async {
      final language = invocation.namedArguments[#language] as String;
      return StreamsTwitch(
        [stream(language.isEmpty ? 'all' : language)],
        {'cursor': 'next'},
      );
    });
    when(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([stream('c')], {}));
    when(() => api.getCategory(gameId: any(named: 'gameId'))).thenAnswer(
      (_) async =>
          const CategoriesTwitch([CategoryTwitch('', '33', 'Game')], null),
    );
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([stream('f')], {}));
  });

  ListStore build(ListType type, {String? categoryId}) => ListStore(
    authStore: auth,
    settingsStore: settings,
    twitchApi: api,
    listType: type,
    categoryId: categoryId,
  );

  test('top streams are asked in the picked language', () async {
    settings.streamLanguage = 'fr';
    final store = build(ListType.top);
    await settle();

    verify(() => api.getTopStreams(language: 'fr')).called(1);
    expect(store.allStreams.single.userId, 'fr');
    store.dispose();
  });

  test('an unknown saved language asks for every language', () async {
    settings.streamLanguage = 'xx';
    final store = build(ListType.top);
    await settle();

    verify(() => api.getTopStreams()).called(1);
    store.dispose();
  });

  test('picking a language starts the list over in it', () async {
    final store = build(ListType.top);
    await settle();
    await store.getStreams();
    expect(store.allStreams.map((s) => s.userId), ['all', 'all']);

    settings.streamLanguage = 'de';
    await settle();

    verify(() => api.getTopStreams(language: 'de')).called(1);
    expect(store.allStreams.map((s) => s.userId), ['de']);
    store.dispose();
  });

  test('a page asked for before the change is dropped', () async {
    final store = build(ListType.top);
    await settle();

    final pending = Completer<StreamsTwitch>();
    when(
      () => api.getTopStreams(cursor: 'next'),
    ).thenAnswer((_) => pending.future);
    final loadingMore = store.getStreams();

    settings.streamLanguage = 'es';
    await settle();
    pending.complete(StreamsTwitch([stream('stale')], {}));
    await loadingMore;

    expect(store.allStreams.map((s) => s.userId), ['es']);
    store.dispose();
  });

  test('category streams follow the language too', () async {
    settings.streamLanguage = 'ko';
    final store = build(ListType.category, categoryId: '33');
    await settle();

    verify(
      () => api.getStreamsUnderCategory(gameId: '33', language: 'ko'),
    ).called(1);

    settings.streamLanguage = '';
    await settle();
    verify(() => api.getStreamsUnderCategory(gameId: '33')).called(1);
    store.dispose();
  });

  test('the followed list ignores the language', () async {
    final store = build(ListType.followed);
    await settle();
    clearInteractions(api);

    settings.streamLanguage = 'fr';
    await settle();

    verifyNever(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    );
    store.dispose();
  });

  test('a disposed list no longer follows the language', () async {
    final store = build(ListType.top);
    await settle();
    store.dispose();
    clearInteractions(api);

    settings.streamLanguage = 'fr';
    await settle();

    verifyNever(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    );
  });

  test('a page failing after the change leaves the new list alone', () async {
    final store = build(ListType.top);
    await settle();
    final pending = Completer<StreamsTwitch>();
    when(
      () => api.getTopStreams(cursor: 'next'),
    ).thenAnswer((_) => pending.future);
    final loadingMore = store.getStreams();

    settings.streamLanguage = 'es';
    await settle();
    pending.completeError(const SocketException('offline'));
    await loadingMore;

    expect(store.error, isNull);
    expect(store.allStreams.map((s) => s.userId), ['es']);
    expect(store.isLoading, isFalse);
    store.dispose();
  });

  group('per-list filters', () {
    StreamTwitch tagged(String id, List<String> tags, {String language = ''}) =>
        StreamTwitch(
          id,
          'l$id',
          'N$id',
          '1',
          'Game',
          'Title',
          10,
          '',
          '',
          tags: tags,
          language: language,
        );

    test('a list language overrides the setting for that list only', () async {
      settings.streamLanguage = 'fr';
      final store = build(ListType.top);
      final other = build(ListType.top);
      await settle();

      store.languageFilter = 'de';
      await settle();
      verify(() => api.getTopStreams(language: 'de')).called(1);
      expect(store.allStreams.single.userId, 'de');
      expect(other.allStreams.single.userId, 'fr');
      expect(store.isFiltered, isTrue);

      store.clearFilters();
      await settle();
      expect(store.allStreams.single.userId, 'fr');
      expect(store.isFiltered, isFalse);
      store.dispose();
      other.dispose();
    });

    test(
      'tags rank by use, filter the list, and stay listed when picked',
      () async {
        when(
          () => api.getTopStreams(
            cursor: any(named: 'cursor'),
            language: any(named: 'language'),
          ),
        ).thenAnswer(
          (_) async => StreamsTwitch([
            tagged('1', ['English', 'Chill']),
            tagged('2', ['english']),
            tagged('3', ['Speedrun']),
          ], const {}),
        );
        final store = build(ListType.top);
        await settle();

        expect(store.topTags, ['English', 'Chill', 'Speedrun']);
        store.tagFilter = 'Speedrun';
        expect(store.streams.map((s) => s.userId), ['3']);
        expect(store.topTags.first, 'Speedrun');
        store.tagFilter = 'ENGLISH';
        expect(store.streams.map((s) => s.userId), ['1', '2']);
        store.dispose();
      },
    );

    test('Following filters its language on the device', () async {
      when(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => StreamsTwitch([
          tagged('1', [], language: 'fr'),
          tagged('2', [], language: 'en'),
          tagged('3', [], language: 'xx'),
        ], const {}),
      );
      final store = build(ListType.followed);
      await settle();

      store.languageFilter = 'fr';
      expect(store.streams.map((s) => s.userId), ['1']);
      store.languageFilter = 'other';
      expect(store.streams.map((s) => s.userId), ['3']);
      store.languageFilter = '';
      expect(store.streams, hasLength(3));
      verifyNever(() => api.getTopStreams(language: any(named: 'language')));
      store.dispose();
    });
  });

  test(
    'a channel hidden from Browse is left out of Top, not Following',
    () async {
      settings.hiddenChannelIds = ['all', 'f'];
      final top = build(ListType.top);
      final followed = build(ListType.followed);
      await settle();
      expect(top.streams, isEmpty);
      expect(followed.streams.map((s) => s.userId), ['f']);
      top.dispose();
      followed.dispose();
    },
  );
}
