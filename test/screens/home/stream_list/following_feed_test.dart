import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/continue_watching/continue_watching.dart';
import 'package:frosty/screens/home/stream_list/large_stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_card.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    when(() => vods.getVideos(any())).thenAnswer((_) async => const []);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
  }) async {
    // Saves queued in another test's fake zone never run in this one.
    VodResumeRepository.shared.resetQueue();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hype = MockHypeTrainService();
    when(() => hype.getActiveStatuses(any())).thenAnswer((_) async => {});
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
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
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
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
    expect(savedWhen(DateTime(2026, 10, 28, 1), now: now), 'today');
    expect(savedWhen(DateTime(2026, 10, 27, 23), now: now), 'yesterday');
    expect(savedWhen(DateTime(2026, 10, 25), now: now), '3 days ago');
    expect(savedWhen(null, now: now), isNull);
  });
}

class _Offline implements Exception {
  const _Offline();
}
