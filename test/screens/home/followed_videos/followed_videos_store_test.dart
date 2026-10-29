import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/followed_videos/stores/followed_videos_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

FollowedChannel followed(String id) => FollowedChannel(
  broadcasterId: id,
  broadcasterLogin: 'c$id',
  broadcasterName: 'C$id',
  followedAt: DateTime.utc(2026),
);

Vod vod(String id) => Vod(
  id: id,
  title: 'V$id',
  lengthSeconds: 60,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 1,
  ownerId: '1',
  ownerLogin: 'c1',
  ownerDisplayName: 'C1',
  type: VodType.archive,
);

void main() {
  late MockTwitchApi api;
  late MockVodService vods;

  setUp(() {
    api = MockTwitchApi();
    vods = MockVodService();
    when(() => api.getFollowedChannels(userId: '7')).thenAnswer(
      (_) async => FollowedChannels(
        data: [followed('1'), followed('2')],
        pagination: const {'cursor': 'p2'},
        total: 3,
      ),
    );
    when(() => api.getFollowedChannels(userId: '7', cursor: 'p2')).thenAnswer(
      (_) async => FollowedChannels(
        data: [followed('3')],
        pagination: const {},
        total: 3,
      ),
    );
    when(
      () => vods.getFollowedVideos(any()),
    ).thenAnswer((_) async => [vod('a'), vod('b')]);
  });

  FollowedVideosStore build() =>
      FollowedVideosStore(twitchApi: api, vodService: vods, userId: '7');

  test('reads every followed channel, then their videos', () async {
    final store = build();
    await store.load();

    verify(() => vods.getFollowedVideos(['1', '2', '3'])).called(1);
    expect(store.videos.map((v) => v.id), ['a', 'b']);
    expect(store.loading, isFalse);
    expect(store.error, isNull);
  });

  test('a failure says so and keeps what was shown', () async {
    final store = build();
    await store.load();
    when(
      () => vods.getFollowedVideos(any()),
    ).thenThrow(const VodApiException('Unreadable videos'));

    await store.load();

    expect(store.error, isNotNull);
    expect(store.videos, hasLength(2));
  });

  test('a network failure on the follows says so', () async {
    when(
      () => api.getFollowedChannels(userId: '7'),
    ).thenThrow(const NetworkException('down'));
    final store = build();
    await store.load();

    expect(store.error, 'Unable to connect to Twitch');
    expect(store.videos, isEmpty);
  });
}
