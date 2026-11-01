import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/continue_watching/continue_watching.dart';
import 'package:onset/screens/home/stream_list/large_stream_card.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

class MockVodService extends Mock implements TwitchVodService {}

StreamTwitch _stream(int i, {List<String> tags = const []}) => StreamTwitch(
  '$i',
  'login$i',
  'Name $i',
  '50$i',
  'Game $i',
  'Title $i',
  1000 * (10 - i),
  '2026-10-28T10:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login$i-{width}x{height}.jpg',
  tags: tags,
);

Vod _vod(String id) => Vod(
  id: id,
  title: 'Past broadcast $id',
  lengthSeconds: 12000,
  createdAt: DateTime.utc(2026, 10, 27),
  viewCount: 1,
  ownerId: '9',
  ownerLogin: 'jltomy',
  ownerDisplayName: 'JLTomy',
);

/// The videos' titles (`title: 'Past broadcast $id'`): the streamer's
/// words, never translated.
final _vodTitles = [for (var id = 0; id < 200; id++) 'Past broadcast $id'];

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late MockVodService vods;
  late SettingsStore settings;
  late List<StreamTwitch> live;
  late Object? failure;

  setUpAll(() => registerFallbackValue(<String>[]));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockTwitchApi();
    auth = MockAuthStore();
    vods = MockVodService();
    settings = SettingsStore.fromJson({});
    live = [
      for (var i = 1; i <= 6; i++) _stream(i, tags: ['English']),
    ];
    failure = null;
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => auth.twitchWebToken).thenReturn(null);
    when(() => user.details).thenReturn(const UserTwitch('7', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async {
      if (failure != null) throw failure!;
      return StreamsTwitch(live, const {});
    });
    when(() => api.getStreamsByIds(userIds: any(named: 'userIds'))).thenAnswer(
      (invocation) async => StreamsTwitch([
        for (final s in live)
          if ((invocation.namedArguments[#userIds] as List).contains(s.userId))
            s,
      ], const {}),
    );
    when(
      () => api.getFollowedChannels(
        userId: any(named: 'userId'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => FollowedChannels(
        data: [
          FollowedChannel(
            broadcasterId: '77',
            broadcasterLogin: 'sleepy',
            broadcasterName: 'Sleepy',
            followedAt: DateTime.utc(2025, 10, 2),
          ),
        ],
        pagination: const {},
        total: 1,
      ),
    );
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    when(() => vods.viewerId).thenReturn(() => '7');
    when(() => vods.getResumeWatching(limit: any(named: 'limit'))).thenAnswer(
      (_) async => [
        ResumeWatchingEntry(
          vod: _vod('100'),
          history: ViewingHistory(
            positionSec: 9064,
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ),
        ResumeWatchingEntry(
          vod: _vod('101'),
          history: ViewingHistory(
            positionSec: 600,
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ),
      ],
    );
    when(
      () => vods.getVideos(any()),
    ).thenAnswer((_) async => const VideoLookup(videos: [], missing: {}));
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
    Locale? locale,
    double textScale = 1,
  }) async {
    // Saves queued in another test's fake zone never run in this one.
    VodResumeRepository.shared.resetQueue();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await localizedApp(
      tester,
      locale: locale,
      textScale: textScale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    );
    final hype = MockHypeTrainService();
    when(() => hype.getActiveStatuses(any())).thenAnswer((_) async => {});
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<TwitchHypeTrainService>.value(value: hype),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: MaterialApp(
          locale: app.locale,
          supportedLocales: app.supportedLocales,
          localizationsDelegates: app.delegates,
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: app.builder,
          home: Scaffold(
            body: StreamsList(
              listType: ListType.followed,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Past the entrances.
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet landscape', const Size(1280, 854)),
    ('tablet portrait', const Size(854, 1280)),
  ]) {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('$name, ${mode.name}: the shelf, the hero, live now, '
          'without overflow', (tester) async {
        await pump(tester, size: size, mode: mode);

        expect(tester.takeException(), isNull);
        expect(find.text('Continue watching'), findsOneWidget);
        expect(find.text('Past broadcast 100'), findsOneWidget);
        expect(find.text('Live now'), findsOneWidget);
        expect(find.text('Sorted by Viewers (High to Low)'), findsOneWidget);
        // The first live channel is the hero.
        final hero = tester.widget<LargeStreamCard>(
          find.byType(LargeStreamCard),
        );
        expect(hero.streamInfo.userId, '1');
        expect(hero.large, size.shortestSide >= 600);
        expect(find.text('LIVE'), findsOneWidget);
        if (size.shortestSide >= 600) {
          // Beside the hero: "Resume at …" in the row's second line.
          expect(find.textContaining('Resume at 2:31:04'), findsOneWidget);
          // The others are grid tiles.
          expect(
            tester.widget<StreamCard>(find.byType(StreamCard).first).tile,
            isTrue,
          );
        } else {
          expect(find.text('Resume at 2:31:04'), findsOneWidget);
          expect(find.text('Streak 4'), findsNothing);
        }
        await close(tester);
      });
    }
  }

  testWidgets('reduce motion: everything is there at once', (tester) async {
    await pump(tester, reduceMotion: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Name 1'), findsOneWidget);
    await close(tester);
  });

  testWidgets('pinned channels lead, with Pinned and All', (tester) async {
    settings.pinnedChannelIds = ['3'];
    await pump(tester);

    expect(find.text('PINNED'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);
    // The pinned channel is the hero.
    expect(
      tester
          .widget<LargeStreamCard>(find.byType(LargeStreamCard))
          .streamInfo
          .userId,
      '3',
    );
    await close(tester);
  });

  testWidgets('a long press opens the channel actions with Pin', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.text('Name 2'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(UserActionsModal), findsOneWidget);
    expect(find.text('Pin Name 2'), findsOneWidget);
    await close(tester);
  });

  testWidgets('thumbnails off: rows without pictures, no hero picture', (
    tester,
  ) async {
    settings.showThumbnails = false;
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('LIVE'), findsNothing);
    expect(find.textContaining('9,000 viewers'), findsOneWidget);
    await close(tester);
  });

  testWidgets('large stream cards: every live channel is a hero', (
    tester,
  ) async {
    settings.largeStreamCard = true;
    await pump(tester);

    expect(find.byType(StreamCard), findsNothing);
    expect(find.byType(LargeStreamCard), findsWidgets);
    await close(tester);
  });

  testWidgets('nobody live: followed videos, the shelf, the message', (
    tester,
  ) async {
    live = [];
    await pump(tester);

    expect(find.text('Followed videos'), findsOneWidget);
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('No followed streams'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await close(tester);
  });

  testWidgets('offline: the app\'s message and "Try again", which reloads', (
    tester,
  ) async {
    failure = const _Offline();
    await pump(tester);

    expect(find.text('Something went wrong loading streams'), findsOneWidget);
    expect(find.text('Followed videos'), findsOneWidget);
    // What loads on its own stays.
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    failure = null;
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Name 1'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the offline channels open on demand', (tester) async {
    await pump(tester);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('OFFLINE'),
      300,
      scrollable: list,
    );
    await tester.tap(find.text('OFFLINE'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.scrollUntilVisible(find.text('Sleepy'), 300, scrollable: list);
    expect(find.text('Sleepy'), findsOneWidget);
    await close(tester);
  });

  testWidgets('"See all" lists every video to resume', (tester) async {
    await pump(tester);

    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ContinueWatchingScreen), findsOneWidget);
    expect(find.text('Past broadcast 101'), findsWidgets);
    await close(tester);
  });

  test('resume times and when they were saved', () {
    expect(formatResumeTime(9064), '2:31:04');
    expect(formatResumeTime(65), '1:05');
    final now = DateTime(2026, 10, 28, 12);
    final en = L10n.english;
    expect(savedWhen(DateTime(2026, 10, 28, 1), en, now: now), 'today');
    expect(savedWhen(DateTime(2026, 10, 27, 23), en, now: now), 'yesterday');
    expect(savedWhen(DateTime(2026, 10, 25), en, now: now), '3 days ago');
    expect(savedWhen(DateTime(2026, 10, 14), en, now: now), '2 wk ago');
    expect(savedWhen(DateTime(2026, 8, 28), en, now: now), '2 mo ago');
    expect(savedWhen(null, en, now: now), isNull);
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(savedWhen(DateTime(2026, 10, 28, 1), fr, now: now), 'aujourd’hui');
    expect(savedWhen(DateTime(2026, 10, 27, 23), fr, now: now), 'hier');
    expect(
      savedWhen(DateTime(2026, 10, 25), fr, now: now),
      'il y a 3\u00a0jours',
    );
    expect(
      savedWhen(DateTime(2026, 10, 14), fr, now: now),
      'il y a 2\u00a0sem.',
    );
    expect(
      savedWhen(DateTime(2026, 8, 28), fr, now: now),
      'il y a 2\u00a0mois',
    );
  });

  group('in French', () {
    final french = lookupAppLocalizations(fr);

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('pinned, live, offline, the sort menu, $sizeName, text '
            '×$scale', (tester) async {
          settings.pinnedChannelIds = ['3'];
          await pump(tester, size: size, locale: fr, textScale: scale);
          expect(find.text(french.streamListLiveNow), findsOneWidget);
          if (size.shortestSide < 600) {
            // (A tablet makes the pinned channel its hero.)
            expect(
              find.text(french.streamListPinned.toUpperCase()),
              findsOneWidget,
            );
          }
          // The offline channels, opened.
          final list = find.byType(Scrollable).first;
          final offline = find.text(french.streamOffline.toUpperCase());
          await tester.scrollUntilVisible(offline, 300, scrollable: list);
          await tester.tap(offline);
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await expectFrenchThroughout(
            tester,
            'Following',
            content: _vodTitles,
          );

          // The orders.
          tester.state<ScrollableState>(list).position.jumpTo(0);
          await tester.pump();
          await tester.tap(find.byTooltip(french.followedSortTooltip));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(french.followedSortRecent), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            englishLeaks(tester, content: _vodTitles),
            isEmpty,
            reason: 'sort menu',
          );
          await close(tester);
        });
      }
    }

    testWidgets('nobody live, a failure, the thumbnails off, Continue '
        'watching\'s page', (tester) async {
      live = [];
      await pump(tester, locale: fr);
      expect(find.text(french.streamListEmptyFollowed), findsOneWidget);
      await expectFrenchThroughout(tester, 'nobody live', content: _vodTitles);
      await close(tester);

      live = [
        for (var i = 1; i <= 6; i++) _stream(i, tags: ['English']),
      ];
      failure = const _Offline();
      await pump(tester, locale: fr);
      expect(find.text(french.streamListLoadFailed), findsOneWidget);
      await expectFrenchThroughout(tester, 'failed', content: _vodTitles);
      await close(tester);

      failure = null;
      settings.showThumbnails = false;
      await pump(tester, locale: fr, size: const Size(360, 640));
      await expectFrenchThroughout(
        tester,
        'no thumbnails',
        content: _vodTitles,
      );

      final list = find.byType(Scrollable).first;
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await tester.pump();
      await tester.tap(find.text(french.commonSeeAll).first);
      await tester.pumpAndSettle();
      expect(find.text(french.continueWatchingTitle), findsWidgets);
      await expectFrenchThroughout(
        tester,
        'continue watching page',
        content: _vodTitles,
      );
      await close(tester);
    });
  });
}

class _Offline implements Exception {
  const _Offline();
}
