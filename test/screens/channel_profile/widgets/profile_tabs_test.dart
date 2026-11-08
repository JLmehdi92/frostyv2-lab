import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_home_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_icons/simple_icons.dart';

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class _BlockedNotifications extends GoLivePlatform {
  @override
  Future<bool> allowed() async => false;
}

class FakeReminderPlatform implements ReminderPlatform {
  var granted = true;
  final scheduled = <int>{};

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppLocalizations l,
  }) async => scheduled.add(id);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

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
  // Still: the live badge's ping and the skeletons' sheen.
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
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

    testWidgets('a hostile, deeply nested panel renders without breaking', (
      tester,
    ) async {
      final panel = ChannelPanel.fromGql({
        'id': '1',
        'type': 'DEFAULT',
        'description': '${'>' * 4990} x',
      })!;
      final watch = Stopwatch()..start();
      await tester.pumpWidget(
        _app(ProfilePanel(panel: panel, onOpenLink: opened.add), width: 320),
      );
      watch.stop();
      expect(tester.takeException(), isNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
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

      expect(find.textContaining('Next stream in 4 hours · '), findsOneWidget);
      expect(find.text('Yesterday'), findsNothing);
      // The next stream on top, and in its day.
      expect(find.text('Ranked'), findsNWidgets(2));
      expect(find.textContaining('Chess'), findsOneWidget);
      expect(find.textContaining('Canceled'), findsOneWidget);
      expect(find.text('Wednesday, October 14'), findsOneWidget);
      expect(find.text('Thursday, October 15'), findsOneWidget);
    });

    group('Remind me', () {
      late FakeReminderPlatform platform;
      late ScheduleReminders reminders;
      final schedule = ChannelSchedule(
        nextStartAt: DateTime(2026, 10, 14, 16).toUtc(),
        segments: [
          ScheduleSegment(
            id: 'a',
            startAt: DateTime(2026, 10, 14, 16).toUtc(),
            title: 'Ranked',
          ),
          ScheduleSegment(
            id: 'b',
            startAt: DateTime(2026, 10, 15, 16).toUtc(),
            title: 'Blitz',
          ),
          ScheduleSegment(
            id: 'c',
            startAt: DateTime(2026, 10, 16, 16).toUtc(),
            isCancelled: true,
          ),
        ],
      );

      Future<void> pump(WidgetTester tester, {double width = 400}) async {
        await tester.pumpWidget(
          _app(
            width: width,
            ProfileScheduleContent(
              schedule: schedule,
              now: now,
              login: 'streamer',
              channelName: 'Streamer',
              reminders: reminders,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        platform = FakeReminderPlatform();
        reminders = ScheduleReminders(
          prefs: await SharedPreferences.getInstance(),
          platform: platform,
          now: () => now,
        );
      });

      testWidgets('the next stream and each segment to come', (tester) async {
        await pump(tester);
        // The next stream's button, and a bell on the two to come.
        expect(find.text('Remind me'), findsOneWidget);
        expect(find.byTooltip('Remind me'), findsNWidgets(2));

        await tester.tap(find.text('Remind me'));
        await tester.pumpAndSettle();
        expect(find.text('Reminder set'), findsOneWidget);
        expect(find.byTooltip('Reminder set'), findsOneWidget);
        expect(reminders.isSet('a'), isTrue);

        await tester.tap(find.byTooltip('Remind me'));
        await tester.pumpAndSettle();
        expect(reminders.isSet('b'), isTrue);

        await tester.tap(find.text('Reminder set'));
        await tester.pumpAndSettle();
        expect(reminders.isSet('a'), isFalse);
        expect(platform.scheduled, {reminderNoticeId('b')});
      });

      testWidgets('fits a narrow phone', (tester) async {
        await pump(tester, width: 280);
        expect(tester.takeException(), isNull);
        expect(find.text('Remind me'), findsOneWidget);
      });

      testWidgets('a refused right says where to allow it', (tester) async {
        platform.granted = false;
        await pump(tester);
        await tester.tap(find.text('Remind me'));
        await tester.pumpAndSettle();
        expect(find.textContaining('system settings'), findsOneWidget);
        expect(find.text('Remind me'), findsOneWidget);
      });

      testWidgets('without the right yet, explains before setting one', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => toggleScheduleReminder(
                  context,
                  reminders,
                  schedule.segments.first,
                  login: 'streamer',
                  channelName: 'Streamer',
                  notificationPlatform: _BlockedNotifications(),
                ),
                child: const Text('toggle'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('toggle'));
        await tester.pumpAndSettle();
        expect(find.text('Allow notifications?'), findsOneWidget);
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        expect(reminders.isSet('a'), isFalse);

        await tester.tap(find.text('toggle'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(reminders.isSet('a'), isTrue);
      });

      testWidgets('nothing to tap without reminders', (tester) async {
        await tester.pumpWidget(
          _app(ProfileScheduleContent(schedule: schedule, now: now)),
        );
        expect(find.text('Remind me'), findsNothing);
        expect(find.byTooltip('Remind me'), findsNothing);
      });
    });

    testWidgets('nothing coming', (tester) async {
      await tester.pumpWidget(
        _app(ProfileScheduleContent(schedule: ChannelSchedule.empty, now: now)),
      );
      expect(find.text('No streams scheduled'), findsOneWidget);
    });

    test('starts in', () {
      expect(formatStartsIn(now, now, L10n.english), 'starting now');
      expect(
        formatStartsIn(now.add(const Duration(minutes: 1)), now, L10n.english),
        'in 1 minute',
      );
      expect(
        formatStartsIn(now.add(const Duration(hours: 30)), now, L10n.english),
        'in 1 day',
      );
      final french = lookupAppLocalizations(const Locale('fr'));
      expect(formatStartsIn(now, now, french), 'imminent');
      expect(
        formatStartsIn(now.add(const Duration(minutes: 1)), now, french),
        'dans 1\u00a0minute',
      );
      expect(
        formatStartsIn(now.add(const Duration(hours: 3)), now, french),
        'dans 3\u00a0heures',
      );
      expect(
        formatStartsIn(now.add(const Duration(hours: 30)), now, french),
        'dans 1\u00a0jour',
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
            showStream: true,
          ),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chess with viewers'), findsOneWidget);
      expect(find.text('Last live 2 days ago · Chess'), findsOneWidget);
      expect(find.byType(ProfileVideoTile), findsNWidgets(4));
      expect(find.byType(ProfileClipTile), findsNWidgets(4));

      await tester.tap(find.text('Chess with viewers'));
      await tester.tap(find.text('See all').first);
      await tester.ensureVisible(find.text('See all').last);
      await tester.tap(find.text('See all').last);
      expect(taps, ['channel', 'videos', 'clips']);
    });

    testWidgets('tablet: the stream beside what comes up, three columns', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 14, 12);
      final reminders = ScheduleReminders(
        prefs: await SharedPreferences.getInstance(),
        platform: FakeReminderPlatform(),
        now: () => now,
      );
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

      await tester.pumpWidget(
        _app(
          ProfileHomeContent(
            login: 'streamer',
            channelName: 'Streamer',
            profile: const ChannelProfile(
              id: '42',
              login: 'streamer',
              displayName: 'Streamer',
              lastBroadcast: LastBroadcast(title: 'Ranked'),
              live: LiveStatus(isRerun: false, viewers: 963),
            ),
            videos: videoStore,
            clips: clipStore,
            schedule: ChannelSchedule(
              nextStartAt: DateTime(2026, 10, 15, 21).toUtc(),
              segments: [
                ScheduleSegment(
                  id: 'a',
                  startAt: DateTime(2026, 10, 15, 21).toUtc(),
                  title: 'Soirée GTA RP',
                  categoryName: 'GTA V',
                ),
                ScheduleSegment(
                  id: 'b',
                  startAt: DateTime(2026, 10, 18, 18).toUtc(),
                  title: 'Annonces',
                ),
                ScheduleSegment(
                  id: 'c',
                  startAt: DateTime(2026, 10, 19, 18).toUtc(),
                  title: 'Third',
                ),
              ],
            ),
            reminders: reminders,
            now: now,
            onOpenChannel: () {},
            onViewAllVideos: () {},
            onViewAllClips: () {},
            showStream: true,
            large: true,
          ),
          width: 840,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final card = find.byType(ProfileLiveCard);
      expect(tester.widget<ProfileLiveCard>(card).large, isTrue);
      expect(find.text('COMING UP'), findsOneWidget);
      // The next two, beside the stream.
      expect(find.text('Soirée GTA RP'), findsOneWidget);
      expect(find.text('Annonces'), findsOneWidget);
      expect(find.text('Third'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Soirée GTA RP')).dx,
        greaterThan(tester.getRect(card).right),
      );
      expect(find.textContaining('GTA V'), findsOneWidget);
      expect(find.text('Remind me'), findsNWidgets(2));
      // Two rows of three.
      expect(find.byType(ProfileVideoTile), findsNWidgets(6));
      final tiles = tester
          .widgetList(find.byType(ProfileVideoTile))
          .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
          .toSet();
      expect(tiles, hasLength(2));
    });

    testWidgets('a tile shows how far the viewer got', (tester) async {
      SharedPreferences.setMockInitialValues({});
      VodResumeRepository.shared.resetQueue();
      LiveProgressRepository.shared.resetQueue();
      await tester.runAsync(
        () => VodResumeRepository.shared.save(
          '1',
          positionSec: 1800,
          lengthSec: 3600,
        ),
      );
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
      await tester.pumpWidget(
        _app(
          ProfileHomeContent(
            login: 'streamer',
            profile: null,
            videos: videoStore,
            clips: clipStore,
            onOpenChannel: () {},
            onViewAllVideos: () {},
            onViewAllClips: () {},
          ),
          width: 390,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      final tiles = tester
          .widgetList<ProfileVideoTile>(find.byType(ProfileVideoTile))
          .toList();
      expect(tiles.map((t) => t.progress.progress), [
        isNull,
        closeTo(0.5, 0.01),
        isNull,
        isNull,
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}
