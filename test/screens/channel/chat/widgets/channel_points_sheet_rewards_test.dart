import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/weekly_rewards.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/viewer_rewards.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

import '../../../../fixtures/legendary_payloads.dart';
import '../../../../fixtures/weekly_rewards_payloads.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

const _chosen = PointsReward(
  id: 'chosen',
  title: 'Choose an emote to unlock',
  cost: 500,
  automaticType: 'CHOSEN_SUB_EMOTE_UNLOCK',
);

const _modified = PointsReward(
  id: 'modified',
  title: 'Modify a single emote',
  cost: 300,
  automaticType: 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK',
);

void main() {
  late MockPointsService points;
  late MockViewerActions actions;
  late MockCommunity community;
  late MockHermesClient hermes;
  late ChannelEventsStore store;
  late int entitlementChanges;

  setUp(() {
    points = MockPointsService();
    actions = MockViewerActions();
    community = MockCommunity();
    hermes = MockHermesClient();
    entitlementChanges = 0;
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => const CommunityPointsContext(
        balance: 1200,
        rewards: [_chosen, _modified],
      ),
    );
    when(
      () => points.unlockChosenEmote(
        channelId: any(named: 'channelId'),
        cost: any(named: 'cost'),
        emoteId: any(named: 'emoteId'),
        modified: any(named: 'modified'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => community.getWeeklyRewards(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => WeeklyRewards.fromBody(weeklyRewardsResponse()));
    when(
      () => community.getDropCampaigns(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const <DropCampaign>[]);
    when(
      () => community.getLegendaryCollection(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer(
      (_) async => LegendaryCollection.fromBody(legendarySeasonResponse()),
    );
    when(
      () => community.getUnlockableEmotes(channelId: any(named: 'channelId')),
    ).thenAnswer(
      (_) async => UnlockableEmote.listFrom(unlockableEmotesResponse),
    );
    when(
      () => actions.claimMoment(
        momentId: any(named: 'momentId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => MomentClaimResult.claimed);
    store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      channelName: 'Streamer',
      client: hermes,
      pointsService: points,
      viewerActionsService: actions,
      communityService: community,
      tokenProvider: () async => 'tok',
    );
    store.entitlementChanges.listen((_) => entitlementChanges++);
  });

  Future<void> pump(WidgetTester tester) async {
    await store.refreshPoints();
    await store.refreshWeeklyRewards();
    await store.refreshLegendaryCollection();
    tester.view
      ..physicalSize = const Size(800, 2000)
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

  void sendMoment() => store.applyEventForTest(
    const HermesEvent(
      topic: 'community-moments-channel-v1.42',
      type: 'active',
      data: {'moment_id': 'm-1', 'channel_id': '42'},
    ),
  );

  testWidgets('shows the weekly rewards', (tester) async {
    await pump(tester);

    expect(find.text('Weekly rewards'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('2 of 3 days this week'), findsNWidgets(1));
    expect(
      find.text('Watch on 1 more day this week to earn the next reward.'),
      findsOneWidget,
    );
    expect(find.text('Level 2 · 500 points'), findsOneWidget);
  });

  testWidgets('a moment can be claimed once, then the card leaves', (
    tester,
  ) async {
    final announced = <CommunityMoment>[];
    store.communityMoments.listen(announced.add);
    await pump(tester);
    expect(find.byKey(CommunityMomentCard.claimKey), findsNothing);

    sendMoment();
    sendMoment();
    await tester.pump();
    expect(announced, hasLength(1));
    expect(find.text('A community moment just happened'), findsOneWidget);

    await tester.tap(find.byKey(CommunityMomentCard.claimKey));
    await tester.pumpAndSettle();

    verify(
      () => actions.claimMoment(momentId: 'm-1', authToken: 'tok'),
    ).called(1);
    expect(find.byKey(CommunityMomentCard.claimKey), findsNothing);
    expect(find.textContaining('Moment claimed.'), findsOneWidget);
  });

  testWidgets('a chosen emote reward opens the picker and unlocks', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Choose an emote to unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an emote to unlock'), findsNWidgets(2));
    final confirm = find.byKey(EmoteUnlockSheet.confirmKey);
    expect(tester.widget<SheetButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(EmoteUnlockSheet.emoteKey('301')));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    verify(
      () => points.unlockChosenEmote(
        channelId: '42',
        cost: 500,
        emoteId: '301',
        modified: false,
        authToken: 'tok',
      ),
    ).called(1);
    expect(
      find.text('Emote unlocked. It’s in your emote menu.'),
      findsOneWidget,
    );
    expect(entitlementChanges, 1);
  });

  testWidgets('a modified emote needs an effect too', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Modify a single emote'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(EmoteUnlockSheet.emoteKey('emotesv2_aaa')));
    await tester.pump();
    expect(find.text('PICK AN EFFECT'), findsOneWidget);
    await tester.tap(find.byKey(EmoteUnlockSheet.modifierKey('HF')));
    await tester.pump();
    await tester.tap(find.byKey(EmoteUnlockSheet.confirmKey));
    await tester.pumpAndSettle();

    verify(
      () => points.unlockChosenEmote(
        channelId: '42',
        cost: 300,
        emoteId: 'emotesv2_aaa_HF',
        modified: true,
        authToken: 'tok',
      ),
    ).called(1);
  });

  testWidgets('the hype chests card counts and opens the collection', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Emote chests'), findsOneWidget);
    expect(find.text('2 of 3 emotes collected'), findsOneWidget);
    expect(find.text('You have 3 unopened chests.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(HypeChestsCard.seeKey));
    await tester.tap(find.byKey(HypeChestsCard.seeKey));
    await tester.pumpAndSettle();

    expect(find.text('LEGENDARY'), findsOneWidget);
    expect(find.text('RARE'), findsOneWidget);
    expect(
      find.bySemanticsLabel('chestTwo, not collected yet'),
      findsOneWidget,
    );
  });
}
