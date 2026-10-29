import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

StreamTwitch stream(
  String id, {
  String name = '',
  String game = 'Game',
  int viewers = 10,
  String startedAt = '2026-10-20T10:00:00Z',
}) => StreamTwitch(
  id,
  'login$id',
  name.isEmpty ? 'Name$id' : name,
  '1',
  game,
  'Title',
  viewers,
  startedAt,
  '',
);

void main() {
  group('sortFollowedStreams', () {
    final a = stream(
      'a',
      name: 'zeta',
      game: 'Minecraft',
      viewers: 50,
      startedAt: '2026-10-20T08:00:00Z',
    );
    final b = stream(
      'b',
      name: 'Alpha',
      game: 'Just Chatting',
      viewers: 900,
      startedAt: '2026-10-20T09:30:00Z',
    );
    final c = stream(
      'c',
      name: 'mike',
      game: 'minecraft',
      viewers: 300,
      startedAt: '2026-10-20T07:00:00Z',
    );
    final d = stream('d', name: 'Bravo', game: '', viewers: 5, startedAt: '');

    List<String> ids(List<StreamTwitch> list) => [
      for (final s in list) s.userId,
    ];

    test('viewers: high to low, like Twitch', () {
      expect(ids(sortFollowedStreams([a, b, c, d], FollowedSort.viewers)), [
        'b',
        'c',
        'a',
        'd',
      ]);
    });

    test('recently started: newest first, unknown start last', () {
      expect(ids(sortFollowedStreams([a, b, c, d], FollowedSort.recent)), [
        'b',
        'a',
        'c',
        'd',
      ]);
    });

    test('name: alphabetical, ignoring case', () {
      expect(ids(sortFollowedStreams([a, b, c, d], FollowedSort.name)), [
        'b',
        'd',
        'c',
        'a',
      ]);
    });

    test('category: grouped by category, most watched first in each', () {
      expect(ids(sortFollowedStreams([a, b, c, d], FollowedSort.category)), [
        'b',
        'c',
        'a',
        'd',
      ]);
    });

    test('labels use Twitch wording where Twitch has one', () {
      expect(FollowedSort.viewers.label, 'Viewers (High to Low)');
      expect(FollowedSort.recent.label, 'Recently Started');
    });
  });

  group('the followed list', () {
    late MockTwitchApi api;
    late MockAuthStore auth;
    late SettingsStore settings;

    setUp(() {
      api = MockTwitchApi();
      auth = MockAuthStore();
      settings = SettingsStore.fromJson({});
      final user = MockUserStore();
      when(() => auth.user).thenReturn(user);
      when(
        () => user.details,
      ).thenReturn(const UserTwitch('me', 'me', 'Me', ''));
      when(() => user.blockedUsers).thenReturn(ObservableList());
      when(() => api.getTopStreams(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => StreamsTwitch([
          stream('t1', name: 'zz', viewers: 1),
          stream('t2', name: 'aa', viewers: 2),
        ], const {}),
      );
    });

    Future<ListStore> build(ListType type) async {
      final store = ListStore(
        authStore: auth,
        settingsStore: settings,
        twitchApi: api,
        listType: type,
      );
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return store;
    }

    test('follows the remembered sort and re-sorts when it changes', () async {
      when(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => StreamsTwitch([
          stream('1', name: 'Zed', viewers: 100),
          stream('2', name: 'amy', viewers: 20),
        ], const {}),
      );
      settings.followedSort = FollowedSort.name;
      final store = await build(ListType.followed);

      expect(store.streams.map((s) => s.userId), ['2', '1']);

      settings.followedSort = FollowedSort.viewers;
      expect(store.streams.map((s) => s.userId), ['1', '2']);
    });

    test('a sort other than viewers loads every page before sorting', () async {
      when(() => api.getFollowedStreams(id: any(named: 'id'))).thenAnswer(
        (_) async => StreamsTwitch(
          [stream('1', name: 'Bob', viewers: 100)],
          const {'cursor': 'next'},
        ),
      );
      when(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: 'next',
        ),
      ).thenAnswer(
        (_) async =>
            StreamsTwitch([stream('2', name: 'Al', viewers: 3)], const {}),
      );
      settings.followedSort = FollowedSort.name;
      final store = await build(ListType.followed);

      expect(store.streams.map((s) => s.userId), ['2', '1']);
      verify(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: 'next',
        ),
      ).called(1);
    });

    test('viewers order keeps paging on scroll only', () async {
      when(() => api.getFollowedStreams(id: any(named: 'id'))).thenAnswer(
        (_) async => StreamsTwitch(
          [stream('1', viewers: 100)],
          const {'cursor': 'next'},
        ),
      );
      final store = await build(ListType.followed);

      expect(store.hasMore, isTrue);
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: 'next',
        ),
      );
    });

    test('other lists keep their own order', () async {
      settings.followedSort = FollowedSort.name;
      final store = await build(ListType.top);

      expect(store.streams.map((s) => s.userId), ['t1', 't2']);
    });
  });

  test('the sort is remembered with the settings', () {
    final settings = SettingsStore.fromJson({})
      ..followedSort = FollowedSort.category;
    final restored = SettingsStore.fromJson(settings.toJson());

    expect(restored.followedSort, FollowedSort.category);
    expect(SettingsStore.fromJson({}).followedSort, FollowedSort.viewers);
    expect(
      SettingsStore.fromJson({'followedSort': 'gone'}).followedSort,
      FollowedSort.viewers,
    );
  });
}
