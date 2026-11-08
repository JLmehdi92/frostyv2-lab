import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

import '../../../fixtures/community_goal_payloads.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

void main() {
  late MockPointsService points;
  late MockViewerActions actions;
  late MockCommunity community;
  final goal = CommunityGoal.listFrom(
    communityGoalsResponse([communityGoalFixture()]),
  )!.single;

  setUp(() {
    points = MockPointsService();
    actions = MockViewerActions();
    community = MockCommunity();
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const CommunityPointsContext(balance: 900));
    when(
      () => community.getCommunityGoals(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => [goal]);
  });

  ChannelEventsStore build({String? token = 'tok'}) => ChannelEventsStore(
    channelId: '42',
    channelLogin: 'streamer',
    client: MockHermesClient(),
    pointsService: points,
    viewerActionsService: actions,
    communityService: community,
    tokenProvider: () async => token,
  );

  void answer(GoalContributionResult result) => when(
    () => actions.contributeToGoal(
      channelId: any(named: 'channelId'),
      goalId: any(named: 'goalId'),
      amount: any(named: 'amount'),
      authToken: any(named: 'authToken'),
    ),
  ).thenAnswer((_) async => result);

  test('loads the goals with the viewer token', () async {
    expect(await build().loadCommunityGoals(), [goal]);
    verify(
      () => community.getCommunityGoals(channelId: '42', authToken: 'tok'),
    ).called(1);
  });

  test('a contribution refreshes the balance', () async {
    answer(GoalContributionResult.contributed);
    final store = build();

    expect(
      await store.contributeToGoal(goal, 250),
      GoalContributionResult.contributed,
    );
    verify(
      () => actions.contributeToGoal(
        channelId: '42',
        goalId: 'goal-1',
        amount: 250,
        authToken: 'tok',
      ),
    ).called(1);
    expect(store.points.balance, 900);
  });

  test('a refusal leaves the balance alone', () async {
    answer(GoalContributionResult.notEnoughPoints);

    expect(
      await build().contributeToGoal(goal, 250),
      GoalContributionResult.notEnoughPoints,
    );
    verifyNever(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    );
  });

  test('no token is signed out and sends nothing', () async {
    expect(
      await build(token: null).contributeToGoal(goal, 250),
      GoalContributionResult.signedOut,
    );
    verifyNever(
      () => actions.contributeToGoal(
        channelId: any(named: 'channelId'),
        goalId: any(named: 'goalId'),
        amount: any(named: 'amount'),
        authToken: any(named: 'authToken'),
      ),
    );
  });
}
