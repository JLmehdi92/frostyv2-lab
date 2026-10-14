import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/followed_videos/followed_videos_screen.dart';
import 'package:frosty/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

void main() {
  late MockTwitchApi api;
  late MockVodService vods;

  setUp(() {
    api = MockTwitchApi();
    vods = MockVodService();
    when(() => api.getFollowedChannels(userId: '7')).thenAnswer(
      (_) async => FollowedChannels(
        data: [
          FollowedChannel(
            broadcasterId: '1',
            broadcasterLogin: 'c1',
            broadcasterName: 'C1',
            followedAt: DateTime.utc(2026),
          ),
        ],
        pagination: const {},
        total: 1,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [FrostyColors.light]),
        home: FollowedVideosScreen(
          store: FollowedVideosStore(
            twitchApi: api,
            vodService: vods,
            userId: '7',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists the videos with their channel', (tester) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer(
      (_) async => [
        Vod(
          id: 'a',
          title: 'Morning stream',
          lengthSeconds: 3600,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          viewCount: 10,
          ownerId: '1',
          ownerLogin: 'c1',
          ownerDisplayName: 'Streamer',
          type: VodType.archive,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Followed videos'), findsOneWidget);
    expect(find.text('Morning stream'), findsOneWidget);
    expect(find.textContaining('Streamer'), findsWidgets);
  });

  testWidgets('says when there is nothing', (tester) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.text('No recent videos'), findsOneWidget);
  });

  testWidgets('a failure offers a retry', (tester) async {
    when(
      () => vods.getFollowedVideos(any()),
    ).thenThrow(const VodApiException('Unreadable videos'));
    await pump(tester);
    expect(find.text('Unreadable videos'), findsOneWidget);

    when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No recent videos'), findsOneWidget);
  });
}
