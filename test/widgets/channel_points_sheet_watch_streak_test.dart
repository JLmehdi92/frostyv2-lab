import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/apis/twitch_watch_streak_service.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/models/watch_streak.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/services/hermes_client.dart';
import 'package:frosty/widgets/channel_points_sheet.dart';
import 'package:mocktail/mocktail.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

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
      find.text('1 more stream until an extra 450 channel points reward'),
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

    expect(find.text('Watch Streak Expiring'), findsOneWidget);
    expect(find.text('9/9'), findsNothing);
  });

  testWidgets('no streak, no card', (tester) async {
    await pump(tester, null);

    expect(find.textContaining('Watch Streak'), findsNothing);
    expect(find.textContaining('may not count'), findsNothing);
  });
}
