import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

Vod _vod(String id) => Vod(
  id: id,
  title: 'v$id',
  lengthSeconds: 60,
  createdAt: DateTime.utc(2026),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
);

void main() {
  late MockTwitchVodService service;
  late ChannelVideosStore store;
  late int calls;
  late List<Object> answers;

  setUpAll(() => registerFallbackValue(VodType.archive));

  setUp(() {
    service = MockTwitchVodService();
    calls = 0;
    answers = [];
    when(
      () => service.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async {
      final answer =
          answers[calls < answers.length ? calls : answers.length - 1];
      calls++;
      if (answer is Completer<VodPage>) return answer.future;
      if (answer is VodPage) return answer;
      throw answer;
    });
    store = ChannelVideosStore(
      login: 'streamer',
      type: VodType.highlight,
      vodService: service,
    );
  });

  tearDown(() => store.dispose());

  test('loads the newest videos of its type', () async {
    answers = [
      VodPage(items: [_vod('1'), _vod('2')], hasMore: true),
    ];

    await store.load();

    expect(store.videos.map((v) => v.id), ['1', '2']);
    expect(store.hasMore, isTrue);
    expect(store.error, isNull);
    expect(store.isLoading, isFalse);
    verify(
      () =>
          service.getChannelVideos(login: 'streamer', type: VodType.highlight),
    ).called(1);
  });

  test('a load while one is running makes no second request', () async {
    final page = Completer<VodPage>();
    answers = [page];

    final first = store.load();
    final second = store.load();
    expect(store.isLoading, isTrue);
    page.complete(VodPage(items: [_vod('1')], hasMore: false));
    await Future.wait([first, second]);

    expect(calls, 1);
  });

  test('an error keeps what was shown', () async {
    answers = [
      VodPage(items: [_vod('1')], hasMore: false),
      const ApiException('boom'),
    ];
    await store.load();

    await store.refresh();

    expect(store.videos.map((v) => v.id), ['1']);
    expect(store.error, "Couldn't load videos");
  });

  test('refresh fetches again and replaces the list', () async {
    answers = [
      VodPage(items: [_vod('1')], hasMore: false),
      VodPage(items: [_vod('3'), _vod('1')], hasMore: false),
    ];
    await store.load();

    await store.refresh();

    expect(store.videos.map((v) => v.id), ['3', '1']);
    expect(calls, 2);
  });

  test('an empty channel has no videos and no error', () async {
    answers = [const VodPage(items: [], hasMore: false)];

    await store.load();

    expect(store.videos, isEmpty);
    expect(store.loaded, isTrue);
    expect(store.error, isNull);
  });

  test('an unknown channel says so', () async {
    answers = [const NotFoundException('Channel not found')];

    await store.load();

    expect(store.error, 'Channel not found');
  });

  test('a category store asks for the category\'s top videos', () async {
    when(
      () => service.getCategoryVideos('32982'),
    ).thenAnswer((_) async => VodPage(items: [_vod('1')], hasMore: false));
    final category = ChannelVideosStore(
      login: '',
      type: VodType.archive,
      gameId: '32982',
      vodService: service,
    );
    addTearDown(category.dispose);

    await category.load();

    expect(category.videos.single.id, '1');
    expect(category.error, isNull);
  });
}
