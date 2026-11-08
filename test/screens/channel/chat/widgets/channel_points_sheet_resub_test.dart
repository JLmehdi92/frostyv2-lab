import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/resub_share_card.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

void main() {
  late MockPointsService points;
  late MockWatchStreakService streaks;
  late MockViewerActions actions;
  late MockCommunity community;

  setUp(() {
    points = MockPointsService();
    streaks = MockWatchStreakService();
    actions = MockViewerActions();
    community = MockCommunity();
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const CommunityPointsContext(balance: 1200));
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => actions.shareResub(
        channelLogin: any(named: 'channelLogin'),
        tokenId: any(named: 'tokenId'),
        message: any(named: 'message'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => ViewerActionOutcome.done);
  });

  Future<void> pump(WidgetTester tester, ResubNotification? resub) async {
    when(
      () => community.getResubNotification(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => resub);
    final store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
      client: MockHermesClient(),
      pointsService: points,
      watchStreakService: streaks,
      viewerActionsService: actions,
      communityService: community,
      tokenProvider: () async => 'tok',
    );
    await store.refreshPoints();
    await store.refreshWatchStreak();
    await tester.runAsync(pumpEventQueue);
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
  }

  testWidgets('no card without a shareable resub', (tester) async {
    await pump(tester, null);

    expect(find.byKey(ResubShareCard.shareKey), findsNothing);
  });

  testWidgets('sharing asks first, then sends the message', (tester) async {
    await pump(tester, const ResubNotification(months: 14, tokenId: 't-1'));

    expect(find.text('Share your 14-month sub'), findsOneWidget);
    await tester.tap(find.byKey(ResubShareCard.shareKey));
    await tester.pumpAndSettle();
    verifyNever(
      () => actions.shareResub(
        channelLogin: any(named: 'channelLogin'),
        tokenId: any(named: 'tokenId'),
        message: any(named: 'message'),
        authToken: any(named: 'authToken'),
      ),
    );

    await tester.enterText(find.byKey(ResubShareDialog.messageKey), 'Hi');
    await tester.tap(find.byKey(ResubShareDialog.sendKey));
    await tester.pumpAndSettle();

    verify(
      () => actions.shareResub(
        channelLogin: 'streamer',
        tokenId: 't-1',
        message: 'Hi',
        authToken: 'tok',
      ),
    ).called(1);
    expect(find.text('Your sub was shared in chat.'), findsOneWidget);
    expect(find.byKey(ResubShareCard.shareKey), findsNothing);
  });

  testWidgets('cancelling sends nothing', (tester) async {
    await pump(tester, const ResubNotification(months: 1, tokenId: 't-1'));

    expect(find.text('Share your 1-month sub'), findsOneWidget);
    await tester.tap(find.byKey(ResubShareCard.shareKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => actions.shareResub(
        channelLogin: any(named: 'channelLogin'),
        tokenId: any(named: 'tokenId'),
        message: any(named: 'message'),
        authToken: any(named: 'authToken'),
      ),
    );
    expect(find.byKey(ResubShareCard.shareKey), findsOneWidget);
  });

  testWidgets('the leaderboards row opens the boards', (tester) async {
    when(
      () => community.getLeaderboards(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => const ChannelLeaderboards(
        boards: {
          LeaderboardKind.cheers: [
            LeaderboardEntry(
              rank: 1,
              score: 500,
              userId: '1',
              displayName: 'TopCheerer',
            ),
          ],
        },
      ),
    );
    await pump(tester, null);

    await tester.tap(find.byKey(const ValueKey('points-leaderboards')));
    await tester.pumpAndSettle();

    expect(find.text('TopCheerer'), findsOneWidget);
    expect(find.text('500 Bits cheered'), findsOneWidget);
  });
}
