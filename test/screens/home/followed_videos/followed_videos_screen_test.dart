import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/followed_videos/followed_videos_screen.dart';
import 'package:frosty/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

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

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<TwitchApi>.value(
        value: api,
        child: MaterialApp(
          theme: theme ?? ThemeData(extensions: const [FrostyColors.light]),
          home: FollowedVideosScreen(
            store: FollowedVideosStore(
              twitchApi: api,
              vodService: vods,
              userId: '7',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Vod video(String id, Duration age, {String title = 'Video'}) => Vod(
    id: id,
    title: title,
    lengthSeconds: 3600,
    createdAt: DateTime.now().subtract(age),
    viewCount: 10,
    ownerId: '1',
    ownerLogin: 'c1',
    ownerDisplayName: 'Streamer',
    type: VodType.archive,
  );

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

  testWidgets('a failure offers to try again', (tester) async {
    when(
      () => vods.getFollowedVideos(any()),
    ).thenThrow(const VodApiException('Unreadable videos'));
    await pump(tester);
    expect(find.text('Unreadable videos'), findsOneWidget);

    when(() => vods.getFollowedVideos(any())).thenAnswer((_) async => []);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No recent videos'), findsOneWidget);
  });

  testWidgets('videos fall in Today / Yesterday / This week / Older', (
    tester,
  ) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer(
      (_) async => [
        video('a', Duration.zero, title: 'Now'),
        video('b', const Duration(days: 1), title: 'Day before'),
        video('c', const Duration(days: 3), title: 'Mid week'),
        video('d', const Duration(days: 12), title: 'Long ago'),
      ],
    );
    await pump(tester, size: const Size(390, 1400));

    expect(tester.takeException(), isNull);
    for (final label in ['TODAY', 'YESTERDAY', 'THIS WEEK', 'OLDER']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('TODAY'), lessThan(top('Now')));
    expect(top('Now'), lessThan(top('YESTERDAY')));
    expect(top('YESTERDAY'), lessThan(top('Day before')));
    expect(top('THIS WEEK'), lessThan(top('Mid week')));
    expect(top('OLDER'), lessThan(top('Long ago')));
  });

  testWidgets('a tablet shows tiles in a grid, light and dark', (tester) async {
    when(() => vods.getFollowedVideos(any())).thenAnswer(
      (_) async => [
        for (var i = 0; i < 6; i++) video('$i', Duration(hours: i)),
      ],
    );
    for (final theme in [
      ThemeData(extensions: const [FrostyColors.light]),
      ThemeData(
        brightness: Brightness.dark,
        extensions: const [FrostyColors.dark],
      ),
    ]) {
      for (final size in const [Size(1280, 854), Size(854, 1280)]) {
        // A new screen each time (its own store, loaded once).
        await tester.pumpWidget(const SizedBox());
        await pump(tester, size: size, theme: theme);
        expect(tester.takeException(), isNull);
        expect(
          find.text('The newest videos of the channels you follow'),
          findsOneWidget,
        );
        final cards = find.byType(VodCard);
        expect(cards, findsWidgets);
        expect(tester.widget<VodCard>(cards.first).tile, isTrue);
        // Several tiles share the first row.
        final first = tester.getTopLeft(cards.at(0));
        final second = tester.getTopLeft(cards.at(1));
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      }
    }
  });

  test('sections count calendar days', () {
    final now = DateTime(2026, 10, 29, 0, 30);
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 29, 0, 5), now),
      FollowedVideosSection.today,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 28, 23, 50), now),
      FollowedVideosSection.yesterday,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 23, 12), now),
      FollowedVideosSection.thisWeek,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 22, 12), now),
      FollowedVideosSection.older,
    );
    expect(
      FollowedVideosSection.of(DateTime(2026, 10, 30), now),
      FollowedVideosSection.today,
      reason: 'a clock behind the server',
    );
  });
}
