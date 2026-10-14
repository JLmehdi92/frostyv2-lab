import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/services/go_live/go_live.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

StreamTwitch _stream(
  String id, {
  String title = 'Title',
  String game = 'Game',
}) => StreamTwitch(id, 'user$id', 'User$id', '1', game, title, 10, '', '');

void main() {
  group('newlyLive', () {
    test('only those not live last time', () {
      expect(
        newlyLive(
          wasLive: {'1'},
          live: [_stream('1'), _stream('2')],
        ).map((s) => s.userId),
        ['2'],
      );
    });

    test('nothing before a first check', () {
      expect(newlyLive(wasLive: null, live: [_stream('1')]), isEmpty);
    });

    test('not the muted channels', () {
      expect(
        newlyLive(
          wasLive: {},
          live: [_stream('1'), _stream('2')],
          muted: {'1'},
        ).map((s) => s.userId),
        ['2'],
      );
    });
  });

  test('a notice names the channel, its title and game', () {
    final notice = goLiveNotice(
      _stream('1', title: ' Speedruns ', game: 'Celeste'),
    );
    expect(notice.title, 'User1 is live');
    expect(notice.body, 'Speedruns · Celeste');
    expect(notice.login, 'user1');
    expect(goLiveNotice(_stream('2', title: '', game: '')).body, '');
  });

  group('checkGoLive', () {
    late MockTwitchApi api;
    late GoLivePrefs prefs;
    late List<(List<GoLiveNotice>, int)> notified;

    Future<int> check() => checkGoLive(
      api: api,
      prefs: prefs,
      notify: (notices, more) async => notified.add((notices, more)),
    );

    void followedLive(List<StreamTwitch> streams, {String? cursor}) => when(
      () => api.getFollowedStreams(id: '7', cursor: cursor, first: 100),
    ).thenAnswer((_) async => StreamsTwitch(streams, const {}));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = MockTwitchApi();
      prefs = await GoLivePrefs.load();
      await prefs.setEnabled(true);
      await prefs.setUserId('7');
      notified = [];
    });

    test('off or logged out: nothing is asked', () async {
      await prefs.setEnabled(false);
      expect(await check(), 0);
      await prefs.setEnabled(true);
      await prefs.setUserId(null);
      expect(await check(), 0);
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
          first: any(named: 'first'),
        ),
      );
    });

    test('the first check only remembers, later ones announce', () async {
      followedLive([_stream('1')]);
      expect(await check(), 0);
      expect(notified, isEmpty);
      expect(prefs.seen, {'1'});

      followedLive([_stream('1'), _stream('2')]);
      expect(await check(), 1);
      expect(notified.single.$1.single.login, 'user2');

      // Still live: not announced again; gone offline: forgotten.
      followedLive([_stream('2')]);
      expect(await check(), 0);
      expect(prefs.seen, {'2'});
    });

    test('reads every page', () async {
      await prefs.setSeen({});
      when(() => api.getFollowedStreams(id: '7', first: 100)).thenAnswer(
        (_) async => StreamsTwitch([_stream('1')], const {'cursor': 'c1'}),
      );
      when(
        () => api.getFollowedStreams(id: '7', cursor: 'c1', first: 100),
      ).thenAnswer((_) async => StreamsTwitch([_stream('2')], const {}));

      expect(await check(), 2);
      expect(prefs.seen, {'1', '2'});
    });

    test('a burst is capped, the rest summed up', () async {
      await prefs.setSeen({});
      followedLive([for (var i = 0; i < 8; i++) _stream('$i')]);
      expect(await check(), 8);
      expect(notified.single.$1, hasLength(kMaxGoLiveNotices));
      expect(notified.single.$2, 3);
    });

    test('a channel with its bell off is not announced', () async {
      await prefs.setSeen({});
      await prefs.setMuted('1', true);
      await prefs.setMuted('3', true);
      await prefs.setMuted('3', false);
      expect(prefs.muted, {'1'});
      followedLive([_stream('1'), _stream('2')]);
      expect(await check(), 1);
      expect(notified.single.$1.single.userId, '2');
    });

    test('a failed read keeps the last state', () async {
      await prefs.setSeen({'1'});
      when(
        () => api.getFollowedStreams(
          id: '7',
          cursor: any(named: 'cursor'),
          first: 100,
        ),
      ).thenThrow(const NetworkException('offline'));
      await expectLater(check(), throwsA(isA<NetworkException>()));
      expect(prefs.seen, {'1'});
    });

    test('a notice that fails is announced again next time', () async {
      await prefs.setSeen({});
      followedLive([_stream('1')]);
      await expectLater(
        checkGoLive(
          api: api,
          prefs: prefs,
          notify: (_, _) async => throw StateError('plugin'),
        ),
        throwsStateError,
      );
      expect(prefs.seen, isEmpty);
      expect(await check(), 1);
    });

    test(
      'turning it on again does not announce what happened while off',
      () async {
        await prefs.setSeen({'1'});
        await prefs.setEnabled(false);
        await prefs.setEnabled(true);
        expect(prefs.seen, isNull);
      },
    );

    test('another viewer starts over', () async {
      await prefs.setSeen({'1'});
      await prefs.setUserId('8');
      expect(prefs.seen, isNull);
    });
  });

  group('runGoLiveTask', () {
    late MockTwitchApi api;
    late GoLivePrefs prefs;
    late List<String> problems;
    late List<Object> reported;
    String? token;

    Future<bool> run() => runGoLiveTask(
      readToken: () async => token,
      buildApi: (_) => api,
      prefs: prefs,
      notify: (_, _) async {},
      notifyProblem: (message) async => problems.add(message),
      report: (error, _) => reported.add(error),
    );

    void answer(Object error) => when(
      () => api.getFollowedStreams(
        id: '7',
        cursor: any(named: 'cursor'),
        first: 100,
      ),
    ).thenThrow(error);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = MockTwitchApi();
      prefs = await GoLivePrefs.load();
      await prefs.setEnabled(true);
      await prefs.setUserId('7');
      problems = [];
      reported = [];
      token = 'token';
    });

    test('no token (logged out): done, nothing asked', () async {
      token = null;
      expect(await run(), isTrue);
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
          first: any(named: 'first'),
        ),
      );
    });

    test('a refused token pauses and says so once', () async {
      answer(const UnauthorizedException('expired'));
      expect(await run(), isTrue);
      expect(await run(), isTrue);
      expect(problems, [kGoLiveLoggedOut]);
      expect(prefs.problem, kGoLiveLoggedOut);

      when(
        () => api.getFollowedStreams(id: '7', first: 100),
      ).thenAnswer((_) async => const StreamsTwitch([], {}));
      expect(await run(), isTrue);
      expect(prefs.problem, isNull);
    });

    test('offline: retried later without a report', () async {
      answer(const NetworkException('offline'));
      expect(await run(), isFalse);
      expect(reported, isEmpty);
    });

    test('anything else: retried later and reported', () async {
      answer(StateError('changed'));
      expect(await run(), isFalse);
      expect(reported.single, isA<StateError>());
    });
  });
}
