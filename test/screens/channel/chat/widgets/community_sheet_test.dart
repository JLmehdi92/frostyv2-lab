import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/screens/channel/chat/widgets/community_goals_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/community_sheet.dart';

import '../../../../fixtures/community_goal_payloads.dart';
import '../../../../fixtures/community_gql_payloads.dart';
import '../../../../helpers/l10n.dart';

void main() {
  late int seeAll;

  setUp(() => seeAll = 0);

  Future<void> pump(
    WidgetTester tester, {
    List<CommunityGoal>? challenges = const [],
    ChannelLeaderboards? boards,
    List<CreatorGoal> creatorGoals = const [],
    Size size = const Size(800, 1600),
  }) async {
    tester.view
      ..physicalSize = size
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

  testWidgets('a supporter row fits a small phone at double text size', (
    tester,
  ) async {
    await tester.runAsync(loadInter);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      boards: ChannelLeaderboards.tryParse(leaderboardsResponse),
      size: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('at normal text size the score sits at the end and the name '
      'takes the rest', (tester) async {
    await tester.runAsync(loadInter);
    await pump(
      tester,
      boards: ChannelLeaderboards.tryParse(leaderboardsResponse),
      size: const Size(360, 640),
    );
    final score = find.text('1,100 Bits cheered');
    final name = find.text('cheer_three');
    final row = find.ancestor(of: score, matching: find.byType(Row)).first;
    expect(tester.getRect(score).right, tester.getRect(row).right);
    expect(tester.getRect(name).right + 10, tester.getRect(score).left);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: name, matching: find.byType(RichText)),
    );
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width),
    );
  });
}
