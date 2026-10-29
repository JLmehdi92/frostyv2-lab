import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/clips_feed_store.dart';

class MockClipService extends Mock implements TwitchClipService {}

Clip clip(String slug) => Clip(
  id: slug,
  slug: slug,
  title: 'Clip $slug',
  viewCount: 1,
  createdAt: DateTime.utc(2026, 10, 2),
  durationSeconds: 30,
  broadcasterId: '42',
  broadcasterLogin: 'streamer',
  broadcasterDisplayName: 'Streamer',
);

void main() {
  late MockClipService service;

  setUp(() => service = MockClipService());

  ClipsFeedStore make({String language = '', int maxClips = 200}) =>
      ClipsFeedStore(
        clipService: service,
        language: language,
        maxClips: maxClips,
      );

  test('loads the first page in the chosen language', () async {
    when(() => service.getTopClips(language: 'fr')).thenAnswer(
      (_) async => ClipFeedPage(items: [clip('a'), clip('b')], cursor: 'Mg=='),
    );
    final store = make(language: 'fr');

    await store.load();

    expect(store.clips.map((c) => c.slug), ['a', 'b']);
    expect(store.hasMore, isTrue);
    expect(store.error, isNull);
  });

  test('loading more appends, without repeats', () async {
    when(
      () => service.getTopClips(language: ''),
    ).thenAnswer((_) async => ClipFeedPage(items: [clip('a')], cursor: 'MQ=='));
    when(
      () => service.getTopClips(cursor: 'MQ==', language: ''),
    ).thenAnswer((_) async => ClipFeedPage(items: [clip('a'), clip('b')]));
    final store = make();

    await store.load();
    await store.loadMore();

    expect(store.clips.map((c) => c.slug), ['a', 'b']);
    expect(store.hasMore, isFalse);
  });

  test('a failing next page ends the feed quietly, once', () async {
    when(
      () => service.getTopClips(language: ''),
    ).thenAnswer((_) async => ClipFeedPage(items: [clip('a')], cursor: 'MQ=='));
    when(
      () => service.getTopClips(cursor: 'MQ==', language: ''),
    ).thenThrow(const ClipApiException('integrity', isIntegrity: true));
    final store = make();

    await store.load();
    await store.loadMore();
    await store.loadMore();

    expect(store.clips, hasLength(1));
    expect(store.hasMore, isFalse);
    expect(store.error, isNull);
    verify(() => service.getTopClips(cursor: 'MQ==', language: '')).called(1);
  });

  test('a failing first page says so, and retry loads again', () async {
    var calls = 0;
    when(() => service.getTopClips(language: '')).thenAnswer((_) async {
      if (calls++ == 0) throw const ClipApiException('boom');
      return ClipFeedPage(items: [clip('a')]);
    });
    final store = make();

    await store.load();
    expect(store.error, isNotNull);

    await store.load();
    expect(store.error, isNull);
    expect(store.clips, hasLength(1));
  });

  test('the feed stops at its bound, whatever Twitch has left', () async {
    when(() => service.getTopClips(language: '')).thenAnswer(
      (_) async => ClipFeedPage(
        items: [clip('a'), clip('b'), clip('c')],
        cursor: 'Mw==',
      ),
    );
    final store = make(maxClips: 2);

    await store.load();
    await store.loadMore();

    expect(store.clips, hasLength(2));
    expect(store.hasMore, isFalse);
    verify(
      () => service.getTopClips(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).called(1);
  });

  test(
    'a list left ten minutes ago is stale, however long it was watched',
    () async {
      var now = DateTime.utc(2026, 10, 29, 12);
      when(
        () => service.getTopClips(language: ''),
      ).thenAnswer((_) async => ClipFeedPage(items: [clip('a')]));
      final store = ClipsFeedStore(clipService: service, now: () => now);
      expect(store.stale, isFalse, reason: 'nothing loaded yet');

      await store.load();
      // Watched for a quarter of an hour: still the viewer's list.
      now = now.add(const Duration(minutes: 15));
      expect(store.stale, isFalse);
      store.left();
      now = now.add(const Duration(seconds: 2));
      expect(store.stale, isFalse);
      now = now.add(ClipsFeedStoreBase.staleAfter);
      expect(store.stale, isTrue);

      store
        ..position = 1
        ..clear();
      expect(store.clips, isEmpty);
      expect(store.position, 0);
      expect(store.stale, isFalse);
    },
  );

  test(
    'a page that fails ends the feed on an error; Try again loads it',
    () async {
      var fail = true;
      when(() => service.getTopClips(language: '')).thenAnswer(
        (_) async => ClipFeedPage(items: [clip('a')], cursor: 'MQ=='),
      );
      when(() => service.getTopClips(cursor: 'MQ==', language: '')).thenAnswer((
        _,
      ) async {
        if (fail) throw const ClipApiException('down');
        return ClipFeedPage(items: [clip('b')]);
      });
      final store = make();
      await store.load();

      await store.loadMore();
      expect(store.hasMore, isFalse);
      expect(store.endedOnError, isTrue);

      fail = false;
      await store.retryMore();
      expect(store.endedOnError, isFalse);
      expect(store.clips.map((c) => c.slug), ['a', 'b']);
    },
  );
}
