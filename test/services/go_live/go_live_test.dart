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
  String startedAt = '',
}) =>
    StreamTwitch(id, 'user$id', 'User$id', '1', game, title, 10, startedAt, '');

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

    test('not a broadcast already announced', () {
      expect(
        newlyLive(
          wasLive: {},
          live: [
            _stream('1', startedAt: '2026-10-20T10:00:00Z'),
            _stream('2', startedAt: '2026-10-20T11:00:00Z'),
          ],
          announced: {'1': '2026-10-20T10:00:00Z', '2': '2026-10-19T09:00:00Z'},
        ).map((s) => s.userId),
        ['2'],
      );
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
    expect(
      goLiveNotice(_stream('3', startedAt: '2026-10-20T10:00:00Z')).startedAt,
      '2026-10-20T10:00:00Z',
    );
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

    test('a broadcast seen going off and back on is announced once', () async {
      await prefs.setSeen({});
      final first = _stream('1', startedAt: '2026-10-20T10:00:00Z');
      followedLive([first]);
      expect(await check(), 1);
      followedLive([]);
      expect(await check(), 0);
      followedLive([first]);
      expect(await check(), 0);
      // A new broadcast is.
      followedLive([]);
      await check();
      followedLive([_stream('1', startedAt: '2026-10-20T12:00:00Z')]);
      expect(await check(), 1);
      expect(notified, hasLength(2));
    });

    test('announced broadcasts older than a day are forgotten', () async {
      await prefs.setAnnounced({
        '1': '2026-10-18T10:00:00Z',
        '2': '2026-10-20T09:00:00Z',
      });
      await prefs.setSeen({});
      followedLive([]);
      await checkGoLive(
        api: api,
        prefs: prefs,
        notify: (_, _) async {},
        now: () => DateTime.utc(2026, 10, 20, 12),
      );
      expect(prefs.announced, {'2': '2026-10-20T09:00:00Z'});
    });

    test('skipped when another check ran within minGap', () async {
      await prefs.setSeen({});
      followedLive([_stream('1')]);
      var now = DateTime.utc(2026, 10, 20, 12);
      Future<int> gapped() => checkGoLive(
        api: api,
        prefs: prefs,
        notify: (notices, more) async => notified.add((notices, more)),
        minGap: const Duration(seconds: 60),
        now: () => now,
      );
      expect(await gapped(), 1);
      expect(prefs.checkedAt!.isAtSameMomentAs(now), isTrue);
      now = now.add(const Duration(seconds: 30));
      followedLive([_stream('1'), _stream('2')]);
      expect(await gapped(), 0);
      verify(() => api.getFollowedStreams(id: '7', first: 100)).called(1);
      now = now.add(const Duration(seconds: 31));
      expect(await gapped(), 1);
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

  group('checkGoLiveInApp', () {
    late MockTwitchApi api;
    late GoLivePrefs prefs;
    var now = DateTime.utc(2026, 10, 20, 12);

    Future<int> check({bool loggedIn = true}) => checkGoLiveInApp(
      api: api,
      prefs: prefs,
      loggedIn: loggedIn,
      notify: (_, _) async {},
      now: () => now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = MockTwitchApi();
      prefs = await GoLivePrefs.load();
      await prefs.setEnabled(true);
      await prefs.setUserId('7');
      await prefs.setSeen({});
      when(
        () => api.getFollowedStreams(id: '7', first: 100),
      ).thenAnswer((_) async => StreamsTwitch([_stream('1')], const {}));
    });

    test('logged out: nothing is asked', () async {
      expect(await check(loggedIn: false), 0);
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
          first: any(named: 'first'),
        ),
      );
    });

    test('announces, and skips right after another check', () async {
      expect(await check(), 1);
      now = now.add(kGoLiveMinGap ~/ 2);
      await prefs.setSeen({});
      expect(await check(), 0);
      now = now.add(kGoLiveMinGap);
      expect(await check(), 1);
    });
  });

  group('runGoLiveTask', () {
    late MockTwitchApi api;
    late GoLivePrefs prefs;
    late List<String> problems;
    late List<Object> reported;
    String? token;
    late DateTime now;

    // The background task runs about every 15 minutes.
    Future<bool> run() {
      now = now.add(const Duration(minutes: 15));
      return runGoLiveTask(
        readToken: () async => token,
        buildApi: (_) => api,
        prefs: prefs,
        notify: (_, _) async {},
        notifyProblem: (message) async => problems.add(message),
        report: (error, _) => reported.add(error),
        now: () => now,
      );
    }

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
      now = DateTime.utc(2026, 10, 20, 12);
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

    test('done without asking right after the app checked', () async {
      await prefs.setProblem(kGoLiveLoggedOut);
      await prefs.setCheckedAt(
        now.add(const Duration(minutes: 15) - kGoLiveMinGap ~/ 2),
      );
      expect(await run(), isTrue);
      // A skipped check says nothing about the token.
      expect(prefs.problem, kGoLiveLoggedOut);
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          cursor: any(named: 'cursor'),
          first: any(named: 'first'),
        ),
      );
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
