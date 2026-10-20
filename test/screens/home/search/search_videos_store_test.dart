import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/search/search_videos_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockVodService extends Mock implements TwitchVodService {}

Vod _vod(String id) => Vod(
  id: id,
  title: 'Video $id',
  lengthSeconds: 600,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
);

void main() {
  late _MockVodService service;
  late SearchVideosStore store;

  setUp(() {
    service = _MockVodService();
    store = SearchVideosStore(vodService: service);
  });

  test('a search loads the first page', () async {
    when(() => service.searchVideos('mario')).thenAnswer(
      (_) async => VodSearchPage(
        items: [_vod('1'), _vod('2')],
        cursor: 'Mg==',
        hasMore: true,
      ),
    );

    await store.search('mario');

    expect(store.videos.map((v) => v.id), ['1', '2']);
    expect(store.hasMore, isTrue);
    expect(store.loading, isFalse);
    expect(store.error, isNull);
  });

  test('loading more appends the next page, with the cursor', () async {
    when(() => service.searchVideos('mario')).thenAnswer(
      (_) async =>
          VodSearchPage(items: [_vod('1')], cursor: 'MQ==', hasMore: true),
    );
    when(
      () => service.searchVideos('mario', cursor: 'MQ=='),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('2'), _vod('1')]));

    await store.search('mario');
    await store.loadMore();

    expect(
      store.videos.map((v) => v.id),
      ['1', '2'],
      reason: 'a video already listed is not repeated',
    );
    expect(store.hasMore, isFalse);
  });

  test('a failing next page stops paging quietly', () async {
    when(() => service.searchVideos('mario')).thenAnswer(
      (_) async =>
          VodSearchPage(items: [_vod('1')], cursor: 'MQ==', hasMore: true),
    );
    when(
      () => service.searchVideos('mario', cursor: 'MQ=='),
    ).thenThrow(const VodApiException('failed integrity', isIntegrity: true));

    await store.search('mario');
    await store.loadMore();
    await store.loadMore();

    expect(store.videos.map((v) => v.id), ['1']);
    expect(store.hasMore, isFalse);
    expect(store.error, isNull, reason: 'the first page stays usable');
    verify(() => service.searchVideos('mario', cursor: 'MQ==')).called(1);
  });

  test('a failing first page says so', () async {
    when(
      () => service.searchVideos('mario'),
    ).thenThrow(const VodApiException('boom'));

    await store.search('mario');

    expect(store.videos, isEmpty);
    expect(store.error, isNotNull);
    expect(store.loading, isFalse);
  });

  test('the same query is not searched twice', () async {
    when(
      () => service.searchVideos('mario'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('1')]));

    await store.search('mario');
    await store.search(' mario ');

    verify(() => service.searchVideos('mario')).called(1);
  });

  test('an older answer never replaces a newer search', () async {
    final slow = Completer<VodSearchPage>();
    when(() => service.searchVideos('old')).thenAnswer((_) => slow.future);
    when(
      () => service.searchVideos('new'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('2')]));

    final first = store.search('old');
    await store.search('new');
    slow.complete(VodSearchPage(items: [_vod('1')]));
    await first;

    expect(store.query, 'new');
    expect(store.videos.map((v) => v.id), ['2']);
  });

  test('a blank query clears the results without a request', () async {
    when(
      () => service.searchVideos('mario'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('1')]));
    await store.search('mario');

    await store.search('  ');

    expect(store.videos, isEmpty);
    expect(store.query, isEmpty);
    verifyNever(() => service.searchVideos('  '));
  });

  test('loading more does nothing without a next page', () async {
    when(
      () => service.searchVideos('mario'),
    ).thenAnswer((_) async => VodSearchPage(items: [_vod('1')]));

    await store.search('mario');
    await store.loadMore();

    verify(() => service.searchVideos('mario')).called(1);
    verifyNoMoreInteractions(service);
  });

  test('retry runs the failed search again', () async {
    var calls = 0;
    when(() => service.searchVideos('mario')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const VodApiException('boom');
      return VodSearchPage(items: [_vod('1')]);
    });

    await store.search('mario');
    await store.retry();

    expect(store.error, isNull);
    expect(store.videos.map((v) => v.id), ['1']);
  });
}
