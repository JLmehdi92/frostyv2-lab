import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/followed_videos/new_followed_videos.dart';
import 'package:onset/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

StreamTwitch _stream(String id, int viewers) =>
    StreamTwitch(id, 'u$id', 'U$id', '', '', '', viewers, '', '');

Vod _vod(String id, DateTime at) => Vod(
  id: id,
  title: id,
  lengthSeconds: 60,
  createdAt: at,
  viewCount: 1,
  ownerId: '1',
  ownerLogin: 'o',
  ownerDisplayName: 'O',
);

void main() {
  test('recommended puts running watch streaks first, then viewers', () {
    final sorted = sortFollowedStreams(
      [_stream('1', 900), _stream('2', 10), _stream('3', 50), _stream('4', 5)],
      FollowedSort.recommended,
      streaks: {'2': 3, '4': 12},
    );
    expect(sorted.map((s) => s.userId), ['4', '2', '1', '3']);
  });

  test('new videos are the ones posted since the list was last seen', () {
    final videos = [
      _vod('a', DateTime.utc(2026, 11, 8)),
      _vod('b', DateTime.utc(2026, 11, 6)),
    ];
    expect(countNewVideos(videos, '2026-11-07T00:00:00Z'), 1);
    expect(countNewVideos(videos, ''), 0);
  });

  group('NewFollowedVideos', () {
    late MockTwitchApi api;
    late MockVodService vods;

    setUp(() {
      NewFollowedVideos.reset();
      api = MockTwitchApi();
      vods = MockVodService();
      when(
        () => api.getFollowedChannels(
          userId: any(named: 'userId'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => FollowedChannels(
          data: [
            FollowedChannel(
              broadcasterId: '9',
              broadcasterLogin: 'nine',
              broadcasterName: 'Nine',
              followedAt: DateTime.utc(2026),
            ),
          ],
          pagination: const {},
          total: 1,
        ),
      );
      when(
        () => vods.getFollowedVideos(any()),
      ).thenAnswer((_) async => [_vod('a', DateTime.utc(2026, 11, 8))]);
    });

    FollowedVideosStore store() =>
        FollowedVideosStore(twitchApi: api, vodService: vods, userId: '7');

    test('the first look only sets where new videos start', () async {
      final settings = SettingsStore();
      await NewFollowedVideos.refresh(
        store(),
        settings,
        now: () => DateTime.utc(2026, 11, 9),
      );
      expect(NewFollowedVideos.count.value, 0);
      expect(settings.followedVideosSeenAt, '2026-11-09T00:00:00.000Z');
    });

    test(
      'videos since the last visit are counted, and opening clears them',
      () async {
        final settings = SettingsStore()
          ..followedVideosSeenAt = '2026-11-07T00:00:00Z';
        await NewFollowedVideos.refresh(
          store(),
          settings,
          now: () => DateTime.utc(2026, 11, 9),
        );
        expect(NewFollowedVideos.count.value, 1);

        await NewFollowedVideos.refresh(
          store(),
          settings,
          now: () => DateTime.utc(2026, 11, 9, 0, 10),
        );
        verify(() => vods.getFollowedVideos(any())).called(1);

        NewFollowedVideos.markSeen(
          settings,
          now: () => DateTime.utc(2026, 11, 9),
        );
        expect(NewFollowedVideos.count.value, 0);
      },
    );
  });

  testWidgets('the badge counts the new videos, capped at 99+', (tester) async {
    await pumpLocalized(
      tester,
      locale: en,
      const Scaffold(
        body: Center(
          child: Column(
            children: [NewVideosBadge(count: 3), NewVideosBadge(count: 150)],
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.bySemanticsLabel('3 new videos'), findsOneWidget);
  });
}
