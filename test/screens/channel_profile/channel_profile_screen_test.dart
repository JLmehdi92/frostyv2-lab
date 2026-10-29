import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_channel_profile_service.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_parts.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/services/notifications/schedule_reminders.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/channel_profile_payloads.dart';

class MockProfileService extends Mock implements TwitchChannelProfileService {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockStreamService extends Mock implements TwitchStreamService {}

class FakeReminderPlatform implements ReminderPlatform {
  final scheduled = <int>{};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async => scheduled.add(id);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

const _phone = Size(390, 844);
const _tabletLandscape = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);

void main() {
  late MockProfileService profiles;
  late MockTwitchApi helix;
  late MockVodService vods;
  late MockClipService clips;
  late List<MethodCall> clipboard;

  setUpAll(() {
    registerFallbackValue(VodType.archive);
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    profiles = MockProfileService();
    helix = MockTwitchApi();
    vods = MockVodService();
    clips = MockClipService();
    when(
      () => vods.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => const VodPage(items: [], hasMore: false));
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
    when(
      () => profiles.getSchedule(any()),
    ).thenAnswer((_) async => ChannelSchedule.empty);
    when(
      () => helix.isFollowing(
        userId: any(named: 'userId'),
        broadcasterId: any(named: 'broadcasterId'),
      ),
    ).thenAnswer((_) async => true);
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call);
          return null;
        });
  });

  /// A few frames: the route's transition and the requests' answers (the
  /// live ring and the skeletons keep a settle from ever finishing when
  /// motion is on).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = _phone,
    ProfileTab tab = ProfileTab.home,
    bool fromChannel = false,
    String? userId,
    String? displayName = 'xQc',
    bool dark = true,
    bool reduceMotion = true,
    AuthStore? auth,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<TwitchChannelProfileService>.value(value: profiles),
          Provider<TwitchApi>.value(value: helix),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
          if (auth != null) Provider<AuthStore>.value(value: auth),
        ],
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ChannelProfileScreen.open(
                  context,
                  login: 'xqc',
                  userId: userId,
                  displayName: displayName,
                  initialTab: tab,
                  fromChannel: fromChannel,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  ChannelProfile xqc() => ChannelProfile.fromGql(
    (jsonDecode(gqlChannelProfileXqc) as Map)['data']['user'],
  )!;

  void answerProfile([ChannelProfile? profile]) => when(
    () => profiles.getProfile(any()),
  ).thenAnswer((_) async => profile ?? xqc());

  MockAuthStore signedIn(String login, {String id = '7'}) {
    final auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => auth.user).thenReturn(user);
    when(() => auth.twitchWebToken).thenReturn(null);
    when(() => user.details).thenReturn(UserTwitch(id, login, login, ''));
    return auth;
  }

  Future<void> tapTab(WidgetTester tester, ProfileTab tab) async {
    // The test font is wider than Inter: the row may scroll.
    await tester.ensureVisible(find.widgetWithText(Tab, tab.label));
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, tab.label));
    await settle(tester);
  }

  group('phone (board Profil)', () {
    testWidgets('the header, the stream, the actions and the tabs', (
      tester,
    ) async {
      answerProfile();
      for (final dark in [true, false]) {
        await pump(tester, dark: dark);
        expect(tester.takeException(), isNull);

        expect(find.byType(ProfileHeader), findsOneWidget);
        expect(find.text('xQc'), findsWidgets);
        expect(find.text('12.6m followers · Partner'), findsOneWidget);
        // The live card: Twitch's title of the stream, viewers.
        final card = find.byType(ProfileLiveCard);
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.textContaining('LOCK IN')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('watching')),
          findsOneWidget,
        );
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.text('Watch'), findsOneWidget);
        // Signed out: Subscribe (twitch.tv asks to log in), no Follow.
        expect(find.text('Subscribe'), findsOneWidget);
        expect(find.text('Follow'), findsNothing);
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.byTooltip('Share'), findsOneWidget);
        expect(find.byTooltip('More'), findsOneWidget);

        // The board's order.
        final xs = [
          for (final tab in ProfileTab.values)
            tester.getTopLeft(find.widgetWithText(Tab, tab.label)).dx,
        ];
        expect(xs, orderedEquals([...xs]..sort()));
        expect(ProfileTab.values.map((t) => t.label), [
          'Home',
          'Videos',
          'Clips',
          'Schedule',
          'About',
        ]);

        // The avatar hangs over the banner's edge, beside the name.
        final avatar = tester.getRect(find.byType(ProfileAvatar));
        expect(avatar.width, ProfileHeader.avatarSize);
        final meta = tester.getRect(find.text('12.6m followers · Partner'));
        expect(avatar.right, lessThan(meta.left));
        expect(avatar.bottom, closeTo(meta.bottom, 8));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('About shows the bio, without asking for the schedule twice', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      await tapTab(tester, ProfileTab.about);
      expect(find.textContaining('THE BEST AT ABSOLUTELY'), findsOneWidget);
      await tapTab(tester, ProfileTab.schedule);
      // Read once at the opening: Home shows the next stream.
      verify(() => profiles.getSchedule('xqc')).called(1);
      expect(find.text('No streams scheduled'), findsOneWidget);
    });

    testWidgets('Home: the next stream with Remind Me', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final platform = FakeReminderPlatform();
      ScheduleReminders.shared = ScheduleReminders(
        prefs: await SharedPreferences.getInstance(),
        platform: platform,
      );
      addTearDown(() => ScheduleReminders.shared = null);
      final start = DateTime.now().add(const Duration(hours: 3));
      when(() => profiles.getSchedule(any())).thenAnswer(
        (_) async => ChannelSchedule(
          nextStartAt: start.toUtc(),
          segments: [
            ScheduleSegment(
              id: 'next',
              startAt: start.toUtc(),
              title: 'Soirée GTA RP',
            ),
          ],
        ),
      );
      answerProfile();
      await pump(tester);

      expect(find.text('Soirée GTA RP'), findsOneWidget);
      expect(find.textContaining('Next stream · '), findsOneWidget);
      await tester.tap(find.text('Remind Me'));
      await settle(tester);
      expect(find.text('Reminder Set'), findsOneWidget);
      expect(platform.scheduled, {reminderNoticeId('next')});
    });

    testWidgets('scrolled, the banner folds into a bar; Back stays', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -700));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final back = tester.getRect(find.byTooltip('Back'));
      expect(back.top, greaterThanOrEqualTo(0));
      // The tabs stay pinned right under the bar.
      final tabs = tester.getRect(find.widgetWithText(Tab, 'Home'));
      expect(tabs.top, greaterThanOrEqualTo(ProfilePhoneHeader.barHeight - 1));
      expect(tabs.top, lessThan(ProfilePhoneHeader.barHeight + 24));
      // The avatar has gone under the bar.
      expect(
        tester.getRect(find.byType(ProfileAvatar)).bottom,
        lessThanOrEqualTo(ProfilePhoneHeader.barHeight),
      );

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(ChannelProfileScreen), findsNothing);
    });

    testWidgets('the folded bar keeps its taps from what slid under it', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -700));
      await settle(tester);
      final header = <RenderObject>{
        for (final element
            in find
                .descendant(
                  of: find.byType(ProfileHeader),
                  matching: find.byWidgetPredicate((_) => true),
                )
                .evaluate())
          ?element.renderObject,
      };
      for (final x in [120.0, 195.0, 260.0]) {
        final hits = tester.hitTestOnBinding(Offset(x, 28));
        expect(
          hits.path.where((entry) => header.contains(entry.target)),
          isEmpty,
          reason: 'x $x',
        );
      }
    });

    testWidgets('every tab pulls to refresh under the pinned header', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      for (final tab in ProfileTab.values) {
        await tapTab(tester, tab);
        final indicators = tester.widgetList<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        expect(indicators, isNotEmpty, reason: tab.label);
        for (final indicator in indicators) {
          expect(
            indicator.edgeOffset,
            greaterThanOrEqualTo(ProfilePhoneHeader.barHeight + 40),
            reason: tab.label,
          );
        }
      }
    });

    testWidgets('a landscape phone keeps everything clear of the cutout', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(left: 48, right: 24);
      addTearDown(tester.view.resetPadding);
      answerProfile();
      await pump(tester, size: const Size(800, 360));
      expect(tester.takeException(), isNull);

      expect(tester.getRect(find.byTooltip('Back')).left, greaterThan(48));
      expect(tester.getRect(find.byTooltip('More')).right, lessThan(800 - 24));
      expect(tester.getRect(find.byType(ProfileAvatar)).left, greaterThan(48));
      expect(
        tester.getRect(find.text('Watch')).left,
        greaterThanOrEqualTo(48 + 16),
      );
      await tapTab(tester, ProfileTab.about);
      expect(
        tester.getTopLeft(find.text('About xQc')).dx,
        greaterThanOrEqualTo(48 + 16),
      );
    });

    testWidgets('large text keeps each action on one line', (tester) async {
      answerProfile();
      when(
        () => helix.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      ).thenAnswer((_) async => false);
      await pump(
        tester,
        size: const Size(360, 740),
        textScale: 1.3,
        auth: signedIn('viewer'),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Watch', 'Follow', 'Subscribe']) {
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        expect(text.didExceedMaxLines, isFalse, reason: label);
        // One line of 14 sp at 1.3, scaled down rather than wrapped.
        expect(
          tester.getSize(find.text(label)).height,
          lessThan(14 * 1.3 * 2),
          reason: label,
        );
      }
    });

    testWidgets('fits a small phone, a landscape phone and large text', (
      tester,
    ) async {
      answerProfile();
      for (final (size, scale) in const [
        (Size(360, 740), 1.0),
        (Size(800, 360), 1.0),
        (Size(320, 640), 1.6),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
        await settle(tester);
        for (final tab in ProfileTab.values) {
          await tapTab(tester, tab);
          expect(tester.takeException(), isNull, reason: '$size ${tab.label}');
        }
      }
    });
  });

  group('tablet (board ProfilTablette)', () {
    for (final size in [_tabletLandscape, _tabletPortrait]) {
      testWidgets('the profile column and the tabs, $size', (tester) async {
        answerProfile();
        for (final dark in [true, false]) {
          await tester.pumpWidget(const SizedBox());
          await pump(tester, size: size, dark: dark);
          expect(tester.takeException(), isNull);

          expect(find.byType(ProfileRail), findsOneWidget);
          expect(find.byType(NestedScrollView), findsNothing);
          expect(find.text('Watch live'), findsOneWidget);
          expect(find.textContaining('THE BEST AT ABSOLUTELY'), findsWidgets);
          expect(find.byType(ProfileSocialPill), findsWidgets);
          // Home: the big stream card.
          final card = find.byWidgetPredicate(
            (w) => w is ProfileLiveCard && w.large,
          );
          expect(card, findsOneWidget);
          final rail = tester.getRect(find.byType(ProfileRail));
          expect(tester.getRect(card).left, greaterThan(rail.right));
          expect(tester.getSize(find.byType(ProfileAvatar)).width, 120);

          for (final tab in ProfileTab.values) {
            await tapTab(tester, tab);
            expect(tester.takeException(), isNull, reason: tab.label);
          }
        }
      });
    }

    testWidgets('a size change keeps the tab', (tester) async {
      answerProfile();
      await pump(tester);
      await tapTab(tester, ProfileTab.about);
      expect(find.text('About xQc'), findsOneWidget);

      tester.view.physicalSize = _tabletLandscape;
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileRail), findsOneWidget);
      // About is still the tab shown.
      expect(find.text('About xQc'), findsOneWidget);
    });
  });

  group('follow and subscribe', () {
    testWidgets('signed in: Following, read from Twitch', (tester) async {
      answerProfile();
      await pump(tester, auth: signedIn('viewer'));
      verify(
        () => helix.isFollowing(userId: '7', broadcasterId: '71092938'),
      ).called(greaterThanOrEqualTo(1));
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    });

    testWidgets('neither on the viewer\'s own channel', (tester) async {
      answerProfile();
      await pump(tester, auth: signedIn('xqc', id: '71092938'));
      // Nothing asked either.
      verifyNever(
        () => helix.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      );
      expect(find.text('Following'), findsNothing);
      expect(find.text('Follow'), findsNothing);
      expect(find.text('Subscribe'), findsNothing);
    });
  });

  group('the live card and Watch', () {
    late MockStreamService streams;
    late PlaybackPreloader previous;

    setUp(() {
      streams = MockStreamService();
      when(
        () => streams.preload(any(), authToken: any(named: 'authToken')),
      ).thenAnswer((_) async {});
      previous = PlaybackPreloader.instance;
      PlaybackPreloader.instance = PlaybackPreloader(streams, isAndroid: true);
    });

    tearDown(() => PlaybackPreloader.instance = previous);

    testWidgets('a finger down on the live card or Watch asks for the token', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ProfileLiveCard)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.cancel();
      verify(() => streams.preload('xqc')).called(1);

      final watch = await tester.startGesture(
        tester.getCenter(find.text('Watch')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await watch.cancel();
      verify(() => streams.preload('xqc')).called(1);
    });

    testWidgets('from the channel screen, Watch goes back to it', (
      tester,
    ) async {
      answerProfile();
      await pump(tester, fromChannel: true);
      await tester.tap(find.byType(ProfileLiveCard));
      await settle(tester);
      expect(find.byType(ChannelProfileScreen), findsNothing);
      // The channel already plays: nothing asked.
      verifyNever(() => streams.preload(any()));

      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Watch'));
      await settle(tester);
      expect(find.byType(ChannelProfileScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  testWidgets('Share copies the link where no share sheet exists', (
    tester,
  ) async {
    answerProfile();
    await pump(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => 'dev.fluttercommunity.plus/share/unavailable',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          ),
    );
    await tester.tap(find.byTooltip('Share'));
    await settle(tester);
    expect(
      (clipboard.single.arguments as Map)['text'],
      'https://www.twitch.tv/xqc',
    );
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('the Videos tab offers highlights and uploads', (tester) async {
    answerProfile();
    await pump(tester, tab: ProfileTab.videos);
    expect(find.text('No past broadcasts'), findsOneWidget);
    await tester.tap(find.text('Highlights'));
    await settle(tester);
    verify(
      () => vods.getChannelVideos(login: 'xqc', type: VodType.highlight),
    ).called(1);
    expect(find.text('No highlights'), findsOneWidget);
    await tester.ensureVisible(find.text('Uploads'));
    await tester.pump();
    await tester.tap(find.text('Uploads'));
    await settle(tester);
    expect(find.text('No uploads'), findsOneWidget);
  });

  testWidgets('a broken profile query still shows the Helix header', (
    tester,
  ) async {
    when(
      () => profiles.getProfile(any()),
    ).thenThrow(const ChannelProfileApiException('schema'));
    when(
      () => helix.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => const UserTwitch('71092938', 'xqc', 'xQc', ''));
    await pump(tester);

    expect(find.text("Couldn't load this channel's profile"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('an unknown channel says so, with a way back', (tester) async {
    when(() => profiles.getProfile(any())).thenAnswer((_) async => null);
    await pump(tester);
    expect(find.text('Channel not found'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
  });

  group('motion', () {
    testWidgets('the live ring pulses, and holds still under reduce motion', (
      tester,
    ) async {
      answerProfile();
      await pump(tester, reduceMotion: false);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());

      await pump(tester);
      // Nothing left to draw: everything holds still.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the pulse stops once the avatar is under the bar', (
      tester,
    ) async {
      answerProfile();
      await pump(tester, reduceMotion: false);
      bool shown() => tester
          .widget<ProfileAvatarShown>(find.byType(ProfileAvatarShown))
          .shown;
      expect(shown(), isTrue);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -700));
      await settle(tester);
      expect(shown(), isFalse);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 900));
      await settle(tester);
      expect(shown(), isTrue);
    });

    testWidgets('a hidden avatar does not pulse', (tester) async {
      Widget avatar({required bool shown}) => MaterialApp(
        theme: ThemeData(extensions: const [FrostyColors.dark]),
        home: ProfileAvatarShown(
          shown: shown,
          child: const Center(
            child: ProfileAvatar(
              login: 'a',
              imageUrl: 'https://static-cdn.jtvnw.net/p.png',
              size: 88,
              live: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(avatar(shown: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(avatar(shown: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('review fixes', () {
    void failEverything() {
      when(
        () => profiles.getProfile(any()),
      ).thenThrow(const ChannelProfileApiException('down'));
      when(
        () => helix.getUser(userLogin: any(named: 'userLogin')),
      ).thenThrow(Exception('offline'));
    }

    testWidgets('with nothing loaded, the caller\'s id still allows More', (
      tester,
    ) async {
      failEverything();
      await pump(tester, userId: '71092938');
      expect(find.byTooltip('More'), findsOneWidget);
    });

    testWidgets('without any id, Chat says why instead of doing nothing', (
      tester,
    ) async {
      failEverything();
      await pump(tester);
      await tester.tap(find.text('Chat'));
      await tester.pump();
      expect(
        find.text("Couldn't open this channel, check your connection"),
        findsOneWidget,
      );
    });

    testWidgets('a retry that only Helix answers updates the header', (
      tester,
    ) async {
      failEverything();
      await pump(tester, displayName: null);
      expect(find.byTooltip('More'), findsNothing);

      when(
        () => helix.getUser(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) async => const UserTwitch('71092938', 'xqc', 'XQC', ''));
      await tester.tap(find.text('Try again').first);
      await settle(tester);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.text('XQC'), findsWidgets);
    });

    testWidgets('a failed refresh over a shown profile is said', (
      tester,
    ) async {
      answerProfile();
      await pump(tester);
      when(
        () => profiles.getProfile(any()),
      ).thenThrow(const ChannelProfileApiException('down'));
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pump();
      expect(find.text("Couldn't refresh this channel"), findsOneWidget);
      expect(find.byType(ProfileHeader), findsOneWidget);
    });

    testWidgets('a hidden videos list is not kept alive in the profile', (
      tester,
    ) async {
      answerProfile();
      await pump(tester, tab: ProfileTab.videos);
      expect(find.byType(ChannelVideosTab), findsOneWidget);
      await tapTab(tester, ProfileTab.clips);
      expect(find.byType(ChannelVideosTab, skipOffstage: false), findsNothing);
    });

    testWidgets('a deep link straight to a tab opens on it', (tester) async {
      answerProfile();
      await pump(tester, tab: ProfileTab.schedule);
      expect(find.text('No streams scheduled'), findsOneWidget);
    });
  });
}
