import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/continue_watching/stores/continue_watching_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVodService extends Mock implements TwitchVodService {}

Vod _vod(String id, {int length = 7200, bool recording = false}) => Vod(
  id: id,
  title: 'Video $id',
  lengthSeconds: length,
  createdAt: DateTime.utc(2026, 10, 20),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  isRecording: recording,
);

ResumeWatchingEntry _entry(String id, int position, DateTime at) =>
    ResumeWatchingEntry(
      vod: _vod(id),
      history: ViewingHistory(positionSec: position, updatedAt: at),
    );

void main() {
  late MockVodService service;
  final repository = VodResumeRepository.shared;
  String? viewer = '7';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository.resetQueue();
    viewer = '7';
    service = MockVodService();
    when(() => service.viewerId).thenReturn(() => viewer);
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer((_) async => null);
    when(
      () => service.getVideos(any()),
    ).thenAnswer((_) async => const VideoLookup(videos: [], missing: {}));
  });

  Future<void> save(
    String id,
    int position,
    DateTime at, {
    int length = 7200,
  }) => withClock(
    Clock.fixed(at),
    () => repository.save(
      id,
      positionSec: position,
      lengthSec: length,
      viewer: viewer,
    ),
  );

  test('this device and Twitch together, newest first', () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [_entry('2', 1200, DateTime.utc(2026, 10, 27, 12))],
    );
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    expect(store.loading, isTrue);
    await store.load();

    expect(store.loading, isFalse);
    expect(store.items.map((i) => i.vod.id), ['2', '1']);
    expect(store.items.first.positionSec, 1200);
    expect(store.items.last.positionSec, 600);
    expect(store.items.last.progress, closeTo(600 / 7200, 1e-9));
    // Only the video Twitch did not name was asked for.
    verify(() => service.getVideos(['1'])).called(1);
  });

  test('a video saved in both places shows the later save', () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    await save('2', 900, DateTime.utc(2026, 10, 27, 14));
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [
        _entry('1', 3000, DateTime.utc(2026, 10, 27, 12)),
        _entry('2', 100, DateTime.utc(2026, 10, 27, 13)),
      ],
    );
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    final byId = {for (final i in store.items) i.vod.id: i.positionSec};
    expect(byId, {'1': 3000, '2': 900});
    expect(store.items.first.vod.id, '2');
    verifyNever(() => service.getVideos(any()));
  });

  test('finished videos and positions near the end are left out', () async {
    // Watched to the end here (saved as finished).
    await save('1', 7190, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [
        _entry('1', 1000, DateTime.utc(2026, 10, 27, 9)),
        _entry('2', 7180, DateTime.utc(2026, 10, 27, 9)),
        _entry('3', 0, DateTime.utc(2026, 10, 27, 9)),
        ResumeWatchingEntry(
          vod: _vod('4', recording: true, length: 600),
          history: ViewingHistory(
            positionSec: 590,
            updatedAt: DateTime.utc(2026, 10, 27, 9),
          ),
        ),
      ],
    );
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    // A broadcast still recording is never "near its end".
    expect(store.items.map((i) => i.vod.id), ['4']);
  });

  test('logged out: this device only, never asking for a token', () async {
    viewer = null;
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    expect(store.items.single.vod.id, '1');
  });

  test("another viewer's positions are never shown", () async {
    viewer = '99';
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    viewer = '7';
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    expect(store.items, isEmpty);
    verifyNever(() => service.getVideos(any()));
  });

  test('videos that cannot be named are left out, never thrown', () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [_entry('2', 1200, DateTime.utc(2026, 10, 27, 9))],
    );
    when(
      () => service.getVideos(any()),
    ).thenAnswer((_) async => throw const VodApiException('down'));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    expect(store.items.map((i) => i.vod.id), ['2']);
  });

  test("a service that throws leaves this device's positions", () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenThrow(StateError('broken'));
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();

    expect(store.items.single.vod.id, '1');
  });

  test('a deleted video is not asked again until the next load', () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getVideos(any(that: contains('1'))),
    ).thenAnswer((_) async => const VideoLookup(videos: [], missing: {'1'}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);

    await store.load();
    // A save elsewhere merges again from memory.
    await save('2', 700, DateTime.utc(2026, 10, 27, 11));
    await pumpEventQueue();
    verify(() => service.getVideos(any(that: contains('1')))).called(1);

    // A load asks again: a video can come back.
    await store.load();
    verify(() => service.getVideos(any(that: contains('1')))).called(1);
    expect(store.items, isEmpty);
  });

  test('a video refused once (not deleted) is asked again at the next '
      'merge', () async {
    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => const VideoLookup(videos: [], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);
    await store.load();

    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    await save('1', 650, DateTime.utc(2026, 10, 27, 12));
    await pumpEventQueue();

    expect(store.items.single.positionSec, 650);
  });

  test('a save on this device updates the shelf without asking Twitch '
      'again', () async {
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [_entry('2', 1200, DateTime.utc(2026, 10, 27, 9))],
    );
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);
    await store.load();

    await save('2', 1500, DateTime.utc(2026, 10, 27, 15));
    await save('1', 300, DateTime.utc(2026, 10, 27, 16));
    await pumpEventQueue();

    expect(store.items.map((i) => (i.vod.id, i.positionSec)), [
      ('1', 300),
      ('2', 1500),
    ]);
    verify(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).called(1);
  });

  test('a refusal keeps what Twitch said last for the same viewer', () async {
    var answer = <ResumeWatchingEntry>[
      _entry('2', 1200, DateTime.utc(2026, 10, 27, 9)),
    ];
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer((_) async => answer);
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);
    await store.load();

    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer((_) async => null);
    await store.load();
    expect(store.items.single.vod.id, '2');

    viewer = '8';
    await store.load();
    expect(store.items, isEmpty);
    answer = const [];
  });

  test("another account's Twitch shelf never joins a local change", () async {
    when(
      () => service.getResumeWatching(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => [_entry('2', 1200, DateTime.utc(2026, 10, 27, 9))],
    );
    when(
      () => service.getVideos(['1']),
    ).thenAnswer((_) async => VideoLookup(videos: [_vod('1')], missing: {}));
    final store = ContinueWatchingStore(vodService: service);
    addTearDown(store.dispose);
    await store.load();
    expect(store.items.single.vod.id, '2');

    // Another account, which closes a video before any refresh.
    viewer = '8';
    await save('1', 300, DateTime.utc(2026, 10, 27, 16));
    await pumpEventQueue();

    expect(store.items.map((i) => i.vod.id), ['1']);
  });

  test(
    'an account change during the first load still ends the loading',
    () async {
      final answer = Completer<List<ResumeWatchingEntry>?>();
      when(
        () => service.getResumeWatching(limit: any(named: 'limit')),
      ).thenAnswer((_) => answer.future);
      final store = ContinueWatchingStore(vodService: service);
      addTearDown(store.dispose);

      final loading = store.load();
      viewer = '8';
      answer.complete([_entry('2', 1200, DateTime.utc(2026, 10, 27, 9))]);
      await loading;

      expect(store.loading, isFalse);
      // The answer was the other account's.
      expect(store.items, isEmpty);
    },
  );

  test('a disposed store stops following saves', () async {
    final store = ContinueWatchingStore(vodService: service);
    await store.load();
    store.dispose();

    await save('1', 600, DateTime.utc(2026, 10, 27, 10));
    await pumpEventQueue();

    verifyNever(() => service.getVideos(any()));
  });
}
