import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';

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
}
