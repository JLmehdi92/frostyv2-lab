import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/app_localizations_en.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/drops_card.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

import '../../../../fixtures/community_goal_payloads.dart';
import '../../../../fixtures/drops_gql_payloads.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

void main() {
  late MockPointsService points;
  late MockViewerActions actions;
  late MockCommunity community;

  setUp(() {
    points = MockPointsService();
    actions = MockViewerActions();
    community = MockCommunity();
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const CommunityPointsContext(balance: 1200));
    when(
      () => actions.claimDrop(
        dropInstanceId: any(named: 'dropInstanceId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => DropClaimResult.claimed);
  });

  Future<void> pump(WidgetTester tester, Object body) async {
    when(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => DropCampaign.listFrom(body));
    final store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
      client: MockHermesClient(),
      pointsService: points,
      viewerActionsService: actions,
      communityService: community,
      tokenProvider: () async => 'tok',
    );
    await store.refreshPoints();
    await store.refreshDrops();
    await tester.runAsync(pumpEventQueue);
    tester.view
      ..physicalSize = const Size(800, 1600)
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

  testWidgets('no card when the channel has no Drops', (tester) async {
    await pump(tester, noDropCampaignsResponse);

    expect(find.text('Drops available'), findsNothing);
  });

  testWidgets('shows progress, the claimed state and a claim button', (
    tester,
  ) async {
    await pump(tester, signedInDropCampaignsResponse());

    expect(find.text('Drops available'), findsOneWidget);
    expect(find.text('Season Rewards · Some Game'), findsOneWidget);
    expect(find.text('Banner reward'), findsOneWidget);
    expect(find.text('90 minutes left'), findsOneWidget);
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.byKey(DropsCard.claimKey('drop-a')), findsOneWidget);
    expect(find.byKey(DropsCard.claimKey('drop-b')), findsNothing);
    expect(find.byKey(DropsCard.linkKey('campaign-2')), findsNothing);
  });

  testWidgets('claiming sends the drop instance and says so', (tester) async {
    await pump(tester, signedInDropCampaignsResponse());

    await tester.ensureVisible(find.byKey(DropsCard.claimKey('drop-a')));
    await tester.tap(find.byKey(DropsCard.claimKey('drop-a')));
    await tester.pumpAndSettle();

    verify(
      () => actions.claimDrop(dropInstanceId: 'instance-a', authToken: 'tok'),
    ).called(1);
    expect(find.text('Reward claimed.'), findsOneWidget);
  });

  testWidgets('offers to link the game account when it is not', (tester) async {
    await pump(tester, signedInDropCampaignsResponse(connected: false));

    expect(find.byKey(DropsCard.linkKey('campaign-2')), findsOneWidget);
    expect(find.text('Link your game account'), findsOneWidget);
  });

  testWidgets('a logged-out viewer is told to log in', (tester) async {
    await pump(tester, anonymousDropCampaignsResponse);

    expect(find.text('Finals Supporter'), findsOneWidget);
    expect(
      find.text('Log in to see your progress and claim rewards.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the community goals row opens the goals', (tester) async {
    when(
      () => community.getCommunityGoals(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => CommunityGoal.listFrom(
        communityGoalsResponse([communityGoalFixture()]),
      ),
    );
    await pump(tester, noDropCampaignsResponse);

    await tester.ensureVisible(
      find.byKey(const ValueKey('points-community-goals')),
    );
    await tester.tap(find.byKey(const ValueKey('points-community-goals')));
    await tester.pumpAndSettle();

    expect(find.text('Kids cam'), findsOneWidget);
    expect(find.text('Contribute'), findsOneWidget);
  });

  testWidgets('the community row opens the Community sheet', (tester) async {
    when(
      () => community.getCommunityGoals(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => community.getLeaderboards(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    await pump(tester, noDropCampaignsResponse);

    await tester.ensureVisible(find.byKey(const ValueKey('points-community')));
    await tester.tap(find.byKey(const ValueKey('points-community')));
    await tester.pumpAndSettle();

    expect(find.text('Top supporters'), findsOneWidget);
    expect(find.text('Challenges'), findsOneWidget);
  });

  group('communityDropsLine', () {
    final l = AppLocalizationsEn();
    DropCampaign one(Map<String, Object?> drop) => DropCampaign.listFrom(
      signedInDropCampaignsResponse(drops: [drop]),
    )!.single;

    test('words each kind of offer', () {
      expect(
        communityDropsLine(
          one(timedDropFixture(id: 'w', minutes: 45)),
          'Ami',
          l,
        ),
        'Ami turned on Drops for the community! Watch for 45 minutes to '
        'claim the reward.',
      );
      expect(
        communityDropsLine(one(timedDropFixture(id: 's', subs: 1)), 'Ami', l),
        'Ami turned on Drops for the community! Buy or gift 1 sub while the '
        'channel is live to get the reward.',
      );
      expect(
        communityDropsLine(one(timedDropFixture(id: 't', turbo: 1)), 'Ami', l),
        'Ami turned on Drops for the community! Get Turbo to earn the rewards.',
      );
      expect(
        communityDropsLine(
          DropCampaign.listFrom(signedInDropCampaignsResponse())!.single,
          'Ami',
          l,
        ),
        'Ami turned on Drops for the community! Watch the stream and buy subs '
        'to claim the rewards.',
      );
    });
  });
}
