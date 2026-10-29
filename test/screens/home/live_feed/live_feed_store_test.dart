import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

StreamTwitch _s(String id, String gameId, String game) =>
    StreamTwitch(id, 'l$id', 'N$id', gameId, game, 'T', 10, '', '');

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
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#cursor] == null
          ? StreamsTwitch(
              [
                _s('1', '10', 'Just Chatting'),
                _s('2', '20', 'League of Legends'),
                _s('3', '10', 'Just Chatting'),
                _s('4', '30', 'GTA V'),
                _s('5', '', ''),
                _s('6', '20', 'League of Legends'),
                _s('7', '40', 'Chess'),
                _s('8', '50', 'Dota 2'),
              ],
              const {'cursor': 'next'},
            )
          : StreamsTwitch([_s('9', '10', 'Just Chatting')], const {}),
    );
    when(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async =>
          StreamsTwitch([_s('20', '20', 'League of Legends')], const {}),
    );
  });

  Channel channel(String id, [List<String> labels = const []]) => Channel(
    broadcasterId: id,
    broadcasterLogin: 'l$id',
    broadcasterName: 'N$id',
    broadcasterLanguage: 'en',
    title: 'T',
    gameId: '',
    gameName: '',
    contentClassificationLabels: labels,
  );

  Future<LiveFeedStore> build() async {
    final store = LiveFeedStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: api,
    );
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return store;
  }

  group('content labels for the previews', () {
    test('read once per channel, a page at a time', () async {
      when(() => api.getChannelsByIds(any())).thenAnswer(
        (invocation) async => {
          for (final id in invocation.positionalArguments.first as List)
            id as String: channel(id, id == '2' ? ['SexualThemes'] : []),
        },
      );
      final store = await build();

      expect(store.knowsLabelsOf('1'), isTrue);
      expect(store.labelsOf('1'), isEmpty);
      expect(store.labelsOf('2'), ['Sexual Themes']);
      expect(store.knowsLabelsOf('9'), isFalse);
      verify(
        () => api.getChannelsByIds(['1', '2', '3', '4', '5', '6', '7', '8']),
      ).called(1);

      // The next page: only its new channel.
      store.setIndex(6);
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      verify(() => api.getChannelsByIds(['9'])).called(1);
      expect(store.labelsOf('9'), isEmpty);
      store.dispose();
    });

    test(
      'unreadable labels are unknown (null), read again on a refresh',
      () async {
        var fail = true;
        when(() => api.getChannelsByIds(any())).thenAnswer((invocation) async {
          if (fail) throw Exception('helix down');
          return {
            for (final id in invocation.positionalArguments.first as List)
              id as String: channel(id),
          };
        });
        final store = await build();
        expect(store.knowsLabelsOf('1'), isTrue);
        expect(store.labelsOf('1'), isNull);

        fail = false;
        await store.refresh();
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(store.labelsOf('1'), isEmpty);
        store.dispose();
      },
    );

    test('warnings off: nothing is read', () async {
      settings.warnMatureContent = false;
      final store = await build();
      verifyNever(() => api.getChannelsByIds(any()));
      expect(store.knowsLabelsOf('1'), isFalse);
      store.dispose();
    });
  });

  test('chips: the categories of the first page, most streams first', () async {
    final store = await build();

    expect(store.chips.map((c) => c.name), [
      'Just Chatting',
      'League of Legends',
      'GTA V',
      'Chess',
    ]);
    expect(store.current!.userId, '1');
    store.dispose();
  });

  test(
    'a chip shows its category from the first stream; All comes back',
    () async {
      final store = await build();
      store.setIndex(2);

      store.selectCategory('20');
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(store.categoryId, '20');
      expect(store.index, 0);
      expect(store.streams.map((s) => s.userId), ['20']);
      verify(
        () => api.getStreamsUnderCategory(
          gameId: '20',
          cursor: any(named: 'cursor'),
          language: any(named: 'language'),
        ),
      ).called(1);
      // The chips stay as they were.
      expect(store.chips, hasLength(4));

      store.selectCategory(null);
      expect(store.streams.first.userId, '1');
      store.dispose();
    },
  );

  test('not interested: left out this session, and undone', () async {
    final store = await build();

    store.hide('1');
    expect(store.current!.userId, '2');
    expect(store.streams, hasLength(7));
    store.unhide('1');
    expect(store.current!.userId, '1');
    store.dispose();
  });

  test('the next page comes before the end', () async {
    final store = await build();

    store.setIndex(3);
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => api.getTopStreams(
        cursor: 'next',
        language: any(named: 'language'),
      ),
    );

    store.setIndex(6);
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    verify(
      () => api.getTopStreams(
        cursor: 'next',
        language: any(named: 'language'),
      ),
    ).called(1);
    expect(store.streams, hasLength(9));
    store.dispose();
  });

  test('refresh starts the list over from the first stream', () async {
    final store = await build();
    store.setIndex(4);

    await store.refresh();

    expect(store.index, 0);
    store.dispose();
  });

  test('the page after the last channel has no current one, until a new '
      'page brings one', () async {
    final store = await build();
    store.setIndex(8);
    expect(store.current, isNull);
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // The next page landed on that very index.
    expect(store.current!.userId, '9');
    store.dispose();
  });

  test('hiding the last channel leaves none current there', () async {
    final store = await build();
    store.setIndex(7);
    store.hide('8');
    expect(store.current, isNull);
    store.dispose();
  });

  test('a refresh that keeps the place leaves a viewer who moved where they '
      'went', () async {
    final store = await build();
    store.setIndex(2);
    final answer = Completer<StreamsTwitch>();
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor', that: isNull),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => answer.future);

    final refreshing = store.refresh(keepPosition: true);
    store.setIndex(4);
    answer.complete(
      StreamsTwitch([
        for (var n = 1; n <= 6; n++) _s('${n + 10}', '10', 'Just Chatting'),
      ], const {}),
    );
    await refreshing;

    expect(store.index, 4);
    store.dispose();
  });

  test('a viewer who swiped past the end of a shorter new list lands on its '
      'last channel', () async {
    final store = await build();
    store.setIndex(2);
    final answer = Completer<StreamsTwitch>();
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor', that: isNull),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => answer.future);

    final refreshing = store.refresh(keepPosition: true);
    store.setIndex(6);
    answer.complete(
      StreamsTwitch([
        _s('3', '10', 'Just Chatting'),
        _s('8', '1', 'X'),
      ], const {}),
    );
    await refreshing;

    expect(store.index, 1);
    expect(store.current!.userId, '8');
    store.dispose();
  });

  test('a refresh that keeps the place finds the channel again', () async {
    final store = await build();
    store.setIndex(2);
    expect(store.current!.userId, '3');
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor', that: isNull),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (_) async => StreamsTwitch([
        _s('7', '40', 'Chess'),
        _s('3', '10', 'Just Chatting'),
      ], const {}),
    );

    await store.refresh(keepPosition: true);

    expect(store.index, 1);
    expect(store.current!.userId, '3');
    store.dispose();
  });

  test('a list older than five minutes is stale; a refresh is not', () async {
    final store = await build();
    expect(store.stale, isFalse);
    store.list.lastTimeRefreshed = DateTime.now().subtract(
      const Duration(minutes: 6),
    );
    expect(store.stale, isTrue);
    await store.refresh();
    expect(store.stale, isFalse);
    store.dispose();
  });
}
