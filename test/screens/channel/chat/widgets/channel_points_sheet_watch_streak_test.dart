import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

void main() {
  late MockPointsService points;
  late MockWatchStreakService streaks;

  setUp(() {
    points = MockPointsService();
    streaks = MockWatchStreakService();
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const CommunityPointsContext(balance: 1200));
  });

  Future<ChannelEventsStore> pump(
    WidgetTester tester,
    WatchStreak? streak, {
    bool live = true,
    TwitchViewerActionsService? actions,
  }) async {
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => streak);
    final store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
      isChannelLive: () => live,
      client: MockHermesClient(),
      pointsService: points,
      watchStreakService: streaks,
      viewerActionsService: actions,
      tokenProvider: () async => 'tok',
    );
    await store.refreshPoints();
    await store.refreshWatchStreak();
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelPointsSheet(points: store.points, store: store),
        ),
      ),
    );
    return store;
  }

  testWidgets('the streak tops the panel, as on Twitch', (tester) async {
    await pump(
      tester,
      const WatchStreak(value: 4, threshold: 5, pointsBonus: 450),
    );

    expect(find.text('Your Watch Streak: 4'), findsOneWidget);
    expect(
      find.text('1 more stream to earn 450 bonus channel points'),
      findsOneWidget,
    );
    expect(find.text('4/5'), findsOneWidget);
    // Said, so a streak that stops growing here is not a surprise.
    expect(find.textContaining('may not count'), findsOneWidget);
  });

  testWidgets('a suspended streak on an offline channel', (tester) async {
    await pump(
      tester,
      const WatchStreak(value: 9, state: WatchStreakState.suspended),
      live: false,
    );

    expect(find.text('Watch Streak expiring'), findsOneWidget);
    expect(find.text('9/9'), findsNothing);
  });

  testWidgets('no streak, no card', (tester) async {
    await pump(tester, null);

    expect(find.textContaining('Watch Streak'), findsNothing);
    expect(find.textContaining('may not count'), findsNothing);
  });

  testWidgets('a milestone to share offers Share in chat, once', (
    tester,
  ) async {
    final actions = MockViewerActions();
    when(
      () => actions.shareWatchStreak(
        channelId: '42',
        milestoneId: 'm1',
        authToken: 'tok',
      ),
    ).thenAnswer((_) async => ViewerActionOutcome.done);
    await pump(
      tester,
      const WatchStreak(value: 5, milestoneId: 'm1', canShare: true),
      actions: actions,
    );

    await tester.tap(find.byKey(WatchStreakCard.shareKey));
    await tester.pumpAndSettle();
    expect(find.text('Your watch streak was shared in chat.'), findsOneWidget);
    expect(find.byKey(WatchStreakCard.shareKey), findsNothing);
  });

  testWidgets('a refused share says so and keeps the button', (tester) async {
    final actions = MockViewerActions();
    when(
      () => actions.shareWatchStreak(
        channelId: any(named: 'channelId'),
        milestoneId: any(named: 'milestoneId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => ViewerActionOutcome.integrityRefused);
    await pump(
      tester,
      const WatchStreak(value: 5, milestoneId: 'm1', canShare: true),
      actions: actions,
    );

    await tester.tap(find.byKey(WatchStreakCard.shareKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('anti-bot'), findsOneWidget);
    expect(find.byKey(WatchStreakCard.shareKey), findsOneWidget);
  });

  testWidgets('nothing to share, no button', (tester) async {
    await pump(
      tester,
      const WatchStreak(value: 5, milestoneId: 'm1'),
      actions: MockViewerActions(),
    );
    expect(find.byKey(WatchStreakCard.shareKey), findsNothing);
  });
}
