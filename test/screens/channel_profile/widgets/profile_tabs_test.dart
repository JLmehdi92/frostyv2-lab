import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_home_tab.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simple_icons/simple_icons.dart';

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

const _profile = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  description: 'Chess every day.',
  followers: 1234,
  role: BroadcasterRole.affiliate,
  socials: [
    SocialLink(name: 'discord', title: 'Discord', url: 'https://discord.gg/x'),
  ],
  panels: [
    ChannelPanel(
      id: '1',
      title: 'Rules',
      description:
          'Be **nice**. [Site](https://site.example/) '
          '[Bad](javascript:alert(1)) ![img](https://evil.example/t.png)',
    ),
    ChannelPanel(id: '2', title: 'Shop', linkUrl: 'https://shop.example/'),
  ],
);

Widget _app(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  group('about', () {
    late List<String> opened;

    setUp(() => opened = []);

    testWidgets('bio, facts, socials and panels; only web links open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(ProfileAboutContent(profile: _profile, onOpenLink: opened.add)),
      );

      expect(find.text('Chess every day.'), findsOneWidget);
      expect(find.textContaining('1,234 followers'), findsOneWidget);
      expect(find.textContaining('Affiliate'), findsOneWidget);
      expect(find.byIcon(SimpleIcons.discord), findsOneWidget);

      await tester.tap(find.text('Discord'));
      // Markdown links are spans of one paragraph: call the handler.
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      markdown.onTapLink!('Site', 'https://site.example/', '');
      markdown.onTapLink!('Bad', 'javascript:alert(1)', '');
      await tester.tap(find.text('shop.example'));
      expect(opened, [
        'https://discord.gg/x',
        'https://site.example/',
        'https://shop.example/',
      ]);
      // Markdown images are never fetched.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('no bio says so', (tester) async {
      await tester.pumpWidget(
        _app(
          ProfileAboutContent(
            profile: const ChannelProfile(
              id: '1',
              login: 'a',
              displayName: 'A',
            ),
            onOpenLink: opened.add,
          ),
        ),
      );
      expect(find.text('No bio yet.'), findsOneWidget);
    });

    test('social icons fall back to a link', () {
      expect(socialIcon('x'), SimpleIcons.x);
      expect(socialIcon('twitter'), SimpleIcons.x);
      expect(socialIcon('myspace'), Icons.link_rounded);
    });
  });

  group('schedule', () {
    final now = DateTime(2026, 10, 14, 12);

    testWidgets('by day, the next start, cancelled ones marked', (
      tester,
    ) async {
      final schedule = ChannelSchedule(
        nextStartAt: DateTime(2026, 10, 14, 16).toUtc(),
        segments: [
          ScheduleSegment(
            id: 'past',
            startAt: DateTime(2026, 10, 13, 16).toUtc(),
            title: 'Yesterday',
          ),
          ScheduleSegment(
            id: 'a',
            startAt: DateTime(2026, 10, 14, 16).toUtc(),
            endAt: DateTime(2026, 10, 14, 20).toUtc(),
            title: 'Ranked',
            categoryName: 'Chess',
          ),
          ScheduleSegment(
            id: 'b',
            startAt: DateTime(2026, 10, 15, 16).toUtc(),
            isCancelled: true,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(ProfileScheduleContent(schedule: schedule, now: now)),
      );

      expect(find.text('Next stream in 4 hours'), findsOneWidget);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.text('Ranked'), findsOneWidget);
      expect(find.textContaining('Chess'), findsOneWidget);
      expect(find.textContaining('Cancelled'), findsOneWidget);
      expect(find.text('Wednesday, October 14'), findsOneWidget);
      expect(find.text('Thursday, October 15'), findsOneWidget);
    });

    testWidgets('nothing coming', (tester) async {
      await tester.pumpWidget(
        _app(ProfileScheduleContent(schedule: ChannelSchedule.empty, now: now)),
      );
      expect(find.text('No streams scheduled'), findsOneWidget);
    });

    test('starts in', () {
      expect(formatStartsIn(now, now), 'now');
      expect(
        formatStartsIn(now.add(const Duration(minutes: 1)), now),
        'in 1 minute',
      );
      expect(
        formatStartsIn(now.add(const Duration(hours: 30)), now),
        'in 1 day',
      );
    });
  });

  group('home', () {
    late MockVodService vods;
    late MockClipService clips;

    setUpAll(() {
      registerFallbackValue(VodType.archive);
      registerFallbackValue(ClipPeriod.lastWeek);
      registerFallbackValue(ClipSort.top);
    });

    setUp(() {
      vods = MockVodService();
      clips = MockClipService();
      when(
        () => vods.getChannelVideos(
          login: any(named: 'login'),
          type: any(named: 'type'),
        ),
      ).thenAnswer(
        (_) async => VodPage(
          items: [
            for (var i = 0; i < 6; i++)
              Vod(
                id: '$i',
                title: 'Video $i',
                lengthSeconds: 60,
                createdAt: DateTime.utc(2026),
                viewCount: 1,
                ownerId: '42',
                ownerLogin: 'streamer',
                ownerDisplayName: 'Streamer',
              ),
          ],
          hasMore: false,
        ),
      );
      when(
        () => clips.getChannelClips(
          login: any(named: 'login'),
          period: any(named: 'period'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer(
        (_) async => ClipPage(
          items: [
            for (var i = 0; i < 6; i++)
              Clip(
                id: '$i',
                slug: 'Slug$i',
                title: 'Clip $i',
                viewCount: 1,
                createdAt: DateTime.utc(2026),
                durationSeconds: 30,
                broadcasterId: '42',
                broadcasterLogin: 'streamer',
                broadcasterDisplayName: 'Streamer',
              ),
          ],
          hasMore: false,
        ),
      );
    });

    testWidgets('offline: last broadcast, four videos and four clips', (
      tester,
    ) async {
      final videoStore = ChannelVideosStore(
        login: 'streamer',
        type: VodType.archive,
        vodService: vods,
      );
      final clipStore = ChannelClipsStore(
        login: 'streamer',
        clipService: clips,
      );
      addTearDown(videoStore.dispose);
      addTearDown(clipStore.dispose);
      final taps = <String>[];

      await tester.pumpWidget(
        _app(
          ProfileHomeContent(
            login: 'streamer',
            profile: ChannelProfile(
              id: '42',
              login: 'streamer',
              displayName: 'Streamer',
              lastBroadcast: LastBroadcast(
                title: 'Chess with viewers',
                startedAt: DateTime.now().subtract(const Duration(days: 2)),
                gameName: 'Chess',
              ),
            ),
            videos: videoStore,
            clips: clipStore,
            onOpenChannel: () => taps.add('channel'),
            onViewAllVideos: () => taps.add('videos'),
            onViewAllClips: () => taps.add('clips'),
          ),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chess with viewers'), findsOneWidget);
      expect(find.text('Last live 2 days ago · Chess'), findsOneWidget);
      expect(find.byType(VodCard), findsNWidgets(4));
      expect(find.byType(ClipCard), findsNWidgets(4));

      await tester.tap(find.text('Chess with viewers'));
      await tester.tap(find.text('View all').first);
      await tester.ensureVisible(find.text('View all').last);
      await tester.tap(find.text('View all').last);
      expect(taps, ['channel', 'videos', 'clips']);
    });
  });
}
