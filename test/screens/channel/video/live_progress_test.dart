import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A live player whose state tests set directly.
class _FakePlayer extends Mock implements PlayerController {
  final _paused = Observable(true);
  final _stream = Observable<StreamTwitch?>(null);
  final _latency = Observable<String?>(null);

  set isPaused(bool value) => runInAction(() => _paused.value = value);
  set stream(StreamTwitch? value) => runInAction(() => _stream.value = value);
  set latencyText(String? value) => runInAction(() => _latency.value = value);

  @override
  bool get paused => _paused.value;
  @override
  StreamTwitch? get streamInfo => _stream.value;
  @override
  String? get latency => _latency.value;
}

StreamTwitch _stream({
  String id = '318071962212',
  String userId = '42',
  String startedAt = '2026-10-19T18:00:00Z',
}) => StreamTwitch(
  userId,
  'streamer',
  'Streamer',
  '509658',
  'Just Chatting',
  'Live',
  10,
  startedAt,
  '',
  id: id,
);

Vod _vod({
  String id = '2905241941',
  String? broadcastId = '318071962212',
  String ownerId = '42',
  DateTime? createdAt,
  int length = 36000,
  VodType? type = VodType.archive,
}) => Vod(
  id: id,
  title: 'Past broadcast',
  lengthSeconds: length,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 19, 18, 0, 7),
  viewCount: 0,
  ownerId: ownerId,
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: type,
  broadcastId: broadcastId,
);

void main() {
  late LiveProgressRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LiveProgressRepository.shared.resetQueue();
    repo = LiveProgressRepository.shared;
  });

  group('liveOffsetSeconds', () {
    final now = DateTime.utc(2026, 10, 19, 20);

    test('time since the stream started, minus the latency', () {
      expect(liveOffsetSeconds(stream: _stream(), now: now), 7200);
      expect(
        liveOffsetSeconds(stream: _stream(), latency: '2.6s', now: now),
        7197,
      );
      expect(
        liveOffsetSeconds(stream: _stream(), latency: 'n/a', now: now),
        7200,
      );
    });

    test('an unreadable or future start is no position', () {
      expect(
        liveOffsetSeconds(
          stream: _stream(startedAt: 'soon'),
          now: now,
        ),
        isNull,
      );
      expect(
        liveOffsetSeconds(
          stream: _stream(startedAt: '2026-10-19T21:00:00Z'),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('LiveProgressRepository', () {
    Future<void> save({
      String? viewer = '1234',
      String streamId = '318071962212',
      String channelId = '42',
      DateTime? startedAt,
      int offset = 5400,
    }) => repo.save(
      viewer: viewer,
      streamId: streamId,
      channelId: channelId,
      startedAt: startedAt ?? DateTime.utc(2026, 10, 19, 18),
      offsetSec: offset,
    );

    test('finds the live session of an archive by its broadcast id', () async {
      await save();

      final entry = await repo.forVod(_vod(), viewer: '1234');

      expect(entry?.streamId, '318071962212');
      expect(entry?.offsetSec, 5400);
      expect(entry?.channelId, '42');
      expect(entry?.startedAt, DateTime.utc(2026, 10, 19, 18));
      expect(entry?.updatedAt, isNotNull);
    });

    test('a later save of the same broadcast replaces the earlier', () async {
      await save(offset: 600);
      await save(offset: 9000);

      expect((await repo.forVod(_vod(), viewer: '1234'))?.offsetSec, 9000);
    });

    test('another account never sees the positions', () async {
      await save();

      expect(await repo.forVod(_vod(), viewer: '9999'), isNull);
      expect(await repo.forVod(_vod(), viewer: null), isNull);

      await save(viewer: null, offset: 300);
      expect((await repo.forVod(_vod(), viewer: null))?.offsetSec, 300);
      expect((await repo.forVod(_vod(), viewer: '1234'))?.offsetSec, 5400);
    });

    test(
      'without a broadcast id: same channel, started with the VOD',
      () async {
        await save(streamId: '1', startedAt: DateTime.utc(2026, 10, 18, 18));
        await save(streamId: '2', offset: 4000);

        final vod = _vod(broadcastId: null);
        expect((await repo.forVod(vod, viewer: '1234'))?.streamId, '2');

        // Too far from the VOD's start, or another channel: no match.
        expect(
          await repo.forVod(
            _vod(broadcastId: null, createdAt: DateTime.utc(2026, 10, 19, 19)),
            viewer: '1234',
          ),
          isNull,
        );
        expect(
          await repo.forVod(
            _vod(broadcastId: null, ownerId: '7'),
            viewer: '1234',
          ),
          isNull,
        );
      },
    );

    test('a broadcast id that matches nothing does not guess', () async {
      await save(streamId: '2');

      expect(
        await repo.forVod(_vod(broadcastId: '318000000000'), viewer: '1234'),
        isNull,
      );
    });

    test('only past broadcasts map to a live session', () async {
      await save();

      for (final type in [VodType.highlight, VodType.upload, null]) {
        expect(
          await repo.forVod(_vod(type: type), viewer: '1234'),
          isNull,
          reason: '$type',
        );
      }
    });

    test('bad ids or offsets are not saved', () async {
      await save(streamId: '../x');
      await save(channelId: 'abc');
      await save(viewer: 'me');
      await save(offset: 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('live_progress_v1'), isNull);
    });

    test('keeps the 300 most recent sessions', () async {
      for (var i = 0; i < 305; i++) {
        await save(streamId: '${1000 + i}');
      }

      final prefs = await SharedPreferences.getInstance();
      final all = jsonDecode(prefs.getString('live_progress_v1')!) as Map;
      expect(all, hasLength(300));
      expect(all.keys, isNot(contains('1234|1000')));
      expect(all.keys, contains('1234|1304'));
    });

    test('corrupted or wrongly typed data reads as nothing', () async {
      SharedPreferences.setMockInitialValues({'live_progress_v1': '{nope'});
      expect(await repo.forVod(_vod(), viewer: '1234'), isNull);

      SharedPreferences.setMockInitialValues({
        'live_progress_v1': jsonEncode({
          '1234|318071962212': {'c': '42', 's': 'x', 'p': 10, 'u': 1},
        }),
      });
      expect(await repo.forVod(_vod(), viewer: '1234'), isNull);

      await save();
      expect((await repo.forVod(_vod(), viewer: '1234'))?.offsetSec, 5400);
    });

    test('maps live sessions by broadcast for the lists', () async {
      await save(streamId: '11', offset: 100);
      await save(streamId: '12', offset: 200, viewer: '9999');

      final byBroadcast = await repo.snapshot(viewer: '1234');
      expect(byBroadcast.keys, ['11']);
      expect(byBroadcast['11']?.offsetSec, 100);
    });
  });

  group('LiveProgressTracker', () {
    late _FakePlayer player;
    late List<(String, int)> reported;

    LiveProgressTracker tracker({String? viewer = '1234'}) =>
        LiveProgressTracker(
          repository: repo,
          viewer: () => viewer,
          report: (streamId, offset) async {
            reported.add((streamId, offset));
            return true;
          },
        );

    setUp(() {
      player = _FakePlayer()..stream = _stream();
      reported = [];
    });

    int? savedOffset(FakeAsync async, {String? viewer = '1234'}) {
      int? result;
      repo.forVod(_vod(), viewer: viewer).then((e) => result = e?.offsetSec);
      async.flushMicrotasks();
      return result;
    }

    test('saves every 20 s while playing, tells Twitch every 5 min', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;

        async.elapse(const Duration(seconds: 20));
        expect(savedOffset(async), 7220);
        expect(reported, isEmpty);

        async.elapse(const Duration(minutes: 5));
        expect(reported, [('318071962212', 7500)]);

        async.elapse(const Duration(minutes: 1));
        expect(reported, hasLength(1));
        t.cancel();
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('nothing is saved while paused', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();

        async.elapse(const Duration(minutes: 6));
        expect(savedOffset(async), isNull);
        expect(reported, isEmpty);
        t.cancel();
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('a pause saves and tells Twitch at once', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 5));

        player.isPaused = true;
        async.flushMicrotasks();

        expect(savedOffset(async), 7205);
        expect(reported, [('318071962212', 7205)]);
        t.cancel();
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('closing, or the app going to the background, saves', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 3));

        t.save(report: true);
        async.flushMicrotasks();
        expect(reported, [('318071962212', 7203)]);

        async.elapse(const Duration(seconds: 4));
        t.close();
        async.flushMicrotasks();
        expect(savedOffset(async), 7207);
        expect(reported.last, ('318071962212', 7207));
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('a pause then the background tell Twitch once', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 5));

        player.isPaused = true;
        async.flushMicrotasks();
        t.save(report: true);
        async.flushMicrotasks();
        expect(reported, [('318071962212', 7205)]);

        // Later, playing again and pausing tells Twitch again.
        player.isPaused = false;
        async.elapse(const Duration(seconds: 30));
        player.isPaused = true;
        async.flushMicrotasks();
        expect(reported, hasLength(2));
        t.cancel();
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('saves while paused keep the paused frame, told once', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 5));
        player.isPaused = true;
        async.flushMicrotasks();
        expect(reported, [('318071962212', 7205)]);

        // A VOD watched on top for 45 minutes, then home, then close.
        async.elapse(const Duration(minutes: 45));
        t.save(report: true);
        async.flushMicrotasks();
        expect(savedOffset(async), 7205);
        t.close();
        async.flushMicrotasks();
        expect(savedOffset(async), 7205);
        expect(reported, [('318071962212', 7205)]);
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('playing again after a pause follows the clock again', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 5));
        player.isPaused = true;
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));
        player.isPaused = false;
        async.elapse(const Duration(seconds: 40));

        t.close();
        async.flushMicrotasks();
        expect(savedOffset(async), 7305);
        expect(reported.last, ('318071962212', 7305));
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('starting twice runs one timer', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start()
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(minutes: 5));
        expect(reported, hasLength(1));
        t.cancel();
        expect(async.pendingTimers, isEmpty);
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('a stream never played saves nothing on close', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();

        t.close();
        async.flushMicrotasks();

        expect(savedOffset(async), isNull);
        expect(reported, isEmpty);
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('follows a new player after a fallback', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player.isPaused = false;

        final web = _FakePlayer()
          ..stream = _stream()
          ..latencyText = '10.0s';
        t.attach(web);
        web.isPaused = false;
        async.elapse(const Duration(seconds: 20));
        expect(savedOffset(async), 7210);

        // The old player's pause is no longer followed.
        player.isPaused = true;
        async.flushMicrotasks();
        expect(reported, isEmpty);

        web.isPaused = true;
        async.flushMicrotasks();
        expect(reported, [('318071962212', 7210)]);
        t.cancel();
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('offline or without a stream id: nothing is saved', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker()
          ..attach(player)
          ..start();
        player
          ..stream = null
          ..isPaused = false;
        async.elapse(const Duration(seconds: 20));
        player.stream = _stream(id: '');
        async.elapse(const Duration(seconds: 20));
        t.close();
        async.flushMicrotasks();

        expect(savedOffset(async), isNull);
        expect(reported, isEmpty);
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });

    test('logged out: kept on this device only, Twitch is not told', () {
      fakeAsync((async) {
        // Saves chain on a future made in this fake zone.
        repo.resetQueue();
        final t = tracker(viewer: null)
          ..attach(player)
          ..start();
        player.isPaused = false;
        async.elapse(const Duration(seconds: 5));

        t.close();
        async.flushMicrotasks();

        expect(savedOffset(async, viewer: null), 7205);
        expect(savedOffset(async), isNull);
        expect(reported, isEmpty);
      }, initialTime: DateTime.utc(2026, 10, 19, 20));
    });
  });
}
