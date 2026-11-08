import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/screens/channel/chat/widgets/community_goals_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/community_sheet.dart';

import '../../../../fixtures/community_goal_payloads.dart';
import '../../../../fixtures/community_gql_payloads.dart';

void main() {
  late int seeAll;

  setUp(() => seeAll = 0);

  Future<void> pump(
    WidgetTester tester, {
    List<CommunityGoal>? challenges = const [],
    ChannelLeaderboards? boards,
    List<CreatorGoal> creatorGoals = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunitySheet(
            loadChallenges: () async => challenges,
            loadLeaderboards: () async => boards,
            creatorGoals: () => creatorGoals,
            balance: () => 1000,
            contribute: (_, _) async => GoalContributionResult.contributed,
            onSeeAllSupporters: () => seeAll++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows challenges, goals and the top supporters', (tester) async {
    await pump(
      tester,
      challenges: CommunityGoal.listFrom(
        communityGoalsResponse([communityGoalFixture()]),
      ),
      boards: ChannelLeaderboards.tryParse(leaderboardsResponse),
      creatorGoals: const [
        CreatorGoal(
          id: 'g',
          kind: CreatorGoalKind.followers,
          state: CreatorGoalState.active,
          description: 'Road to 1k',
          current: 640,
          target: 1000,
        ),
      ],
    );

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Challenges'), findsOneWidget);
    expect(find.text('Kids cam'), findsOneWidget);
    expect(
      find.byKey(CommunityGoalTile.contributeKey('goal-1')),
      findsOneWidget,
    );
    expect(find.text('640 / 1,000'), findsOneWidget);
    expect(find.text('Top supporters'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.ensureVisible(find.byKey(CommunitySheet.seeAllKey));
    await tester.tap(find.byKey(CommunitySheet.seeAllKey));
    expect(seeAll, 1);
  });

  testWidgets('says when a section is empty or failed', (tester) async {
    await pump(tester, challenges: null);

    expect(find.text('Couldn’t load this section.'), findsNWidgets(2));
    expect(find.text('Nothing here right now.'), findsOneWidget);
    expect(find.byKey(CommunitySheet.seeAllKey), findsNothing);
  });
}
