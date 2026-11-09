import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/screens/channel/chat/widgets/community_goals_sheet.dart';

import '../../../../fixtures/community_goal_payloads.dart';

List<CommunityGoal> _goals(List<Map<String, Object?>> raw) =>
    CommunityGoal.listFrom(communityGoalsResponse(raw))!;

void main() {
  late List<(String, int)> sent;
  late int loads;

  setUp(() {
    sent = [];
    loads = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    List<CommunityGoal>? goals, {
    int? balance = 5000,
    GoalContributionResult result = GoalContributionResult.contributed,
  }) async {
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityGoalsSheet(
            key: UniqueKey(),
            load: () async {
              loads++;
              return goals;
            },
            balance: () => balance,
            contribute: (goal, amount) async {
              sent.add((goal.id, amount));
              return result;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a running goal with its progress', (tester) async {
    await pump(tester, _goals([communityGoalFixture()]));

    expect(find.text('Kids cam'), findsOneWidget);
    expect(find.text('25% raised'), findsOneWidget);
    expect(find.text('2.5M of 10M points'), findsOneWidget);
    expect(
      find.byKey(CommunityGoalTile.contributeKey('goal-1')),
      findsOneWidget,
    );
  });

  testWidgets('contributing asks for the amount, sends it and reloads', (
    tester,
  ) async {
    await pump(tester, _goals([communityGoalFixture()]));

    await tester.tap(find.byKey(CommunityGoalTile.contributeKey('goal-1')));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.text('Max 2,000'), findsOneWidget);
    await tester.tap(find.byKey(GoalContributionDialog.maxKey));
    await tester.pump();
    await tester.tap(find.byKey(GoalContributionDialog.sendKey));
    await tester.pumpAndSettle();

    expect(sent, [('goal-1', 2000)]);
    expect(
      find.text('Thank you! Your points went to the goal.'),
      findsOneWidget,
    );
    expect(loads, 2);
  });

  testWidgets('a contribution in flight cannot be sent again', (tester) async {
    final reply = Completer<GoalContributionResult>();
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityGoalsSheet(
            load: () async => _goals([communityGoalFixture()]),
            balance: () => 5000,
            contribute: (goal, amount) {
              sent.add((goal.id, amount));
              return reply.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CommunityGoalTile.contributeKey('goal-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoalContributionDialog.sendKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CommunityGoalTile.contributeKey('goal-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(GoalContributionDialog.sendKey), findsNothing);
    expect(sent, hasLength(1));
    reply.complete(GoalContributionResult.contributed);
    await tester.pumpAndSettle();
  });

  testWidgets('an amount above the maximum cannot be sent', (tester) async {
    await pump(tester, _goals([communityGoalFixture()]), balance: 300);

    await tester.tap(find.byKey(CommunityGoalTile.contributeKey('goal-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(GoalContributionDialog.amountKey), '301');
    await tester.pump();
    await tester.tap(find.byKey(GoalContributionDialog.sendKey));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });

  testWidgets('a refusal is said and nothing reloads', (tester) async {
    await pump(
      tester,
      _goals([communityGoalFixture()]),
      result: GoalContributionResult.notEnoughPoints,
    );

    await tester.tap(find.byKey(CommunityGoalTile.contributeKey('goal-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoalContributionDialog.sendKey));
    await tester.pumpAndSettle();

    expect(sent, [('goal-1', 250)]);
    expect(find.text('You don’t have enough points for this.'), findsOneWidget);
    expect(loads, 1);
  });

  testWidgets('a maxed or ended goal offers no contribution', (tester) async {
    await pump(tester, [
      _goals([communityGoalFixture()]).single.withContributedThisStream(2000),
      ..._goals([communityGoalFixture(id: 'goal-2', status: 'ENDED')]),
    ]);

    expect(find.text('Max contribution per stream reached'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('Contribute'), findsNothing);
  });

  testWidgets('logged out, it says how to contribute', (tester) async {
    await pump(tester, _goals([communityGoalFixture()]), balance: null);

    expect(find.text('Contribute'), findsNothing);
    expect(find.text('Log in to contribute.'), findsOneWidget);
  });

  testWidgets('empty and failed states', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(CommunityGoalsSheet.emptyKey), findsOneWidget);

    await pump(tester, null);
    expect(find.byKey(CommunityGoalsSheet.failedKey), findsOneWidget);
  });
}
