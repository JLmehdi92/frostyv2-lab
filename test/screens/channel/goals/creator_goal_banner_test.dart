import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/screens/channel/goals/creator_goal_banner.dart';

import '../../../helpers/l10n.dart';

CreatorGoal _goal({
  String id = 'g',
  CreatorGoalKind kind = CreatorGoalKind.subs,
  CreatorGoalState state = CreatorGoalState.active,
  int current = 3,
  int target = 10,
}) => CreatorGoal(
  id: id,
  kind: kind,
  state: state,
  description: 'New camera',
  current: current,
  target: target,
);

void main() {
  testWidgets('shows nothing without a goal', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(body: CreatorGoalBanner(goals: () => const [])),
      locale: en,
    );
    expect(find.byType(CreatorGoalRow), findsNothing);
  });

  testWidgets('shows a single goal without a number', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(body: CreatorGoalBanner(goals: () => [_goal()])),
      locale: en,
    );
    expect(find.text('Sub goal'), findsOneWidget);
    expect(find.text('3 of 10'), findsOneWidget);
  });

  testWidgets('numbers goals when several run at once', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: CreatorGoalBanner(
          goals: () => [
            _goal(id: 'a'),
            _goal(id: 'b', kind: CreatorGoalKind.followers),
          ],
        ),
      ),
      locale: en,
    );
    expect(find.text('Goal 1 of 2 · Sub goal'), findsOneWidget);
    expect(find.text('Goal 2 of 2 · Follower goal'), findsOneWidget);
  });

  testWidgets('follows the store and opens the details', (tester) async {
    final goals = Observable<List<CreatorGoal>>(const []);
    await pumpLocalized(
      tester,
      Scaffold(body: CreatorGoalBanner(goals: () => goals.value)),
      locale: en,
    );
    runInAction(() => goals.value = [_goal(current: 10)]);
    await tester.pumpAndSettle();
    expect(find.text('Goal reached'), findsOneWidget);

    await tester.tap(find.byType(CreatorGoalRow));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorGoalDialog), findsOneWidget);
    expect(find.text('New camera'), findsOneWidget);
    expect(
      find.text(
        'The channel reached this goal. Thanks to everyone who chipped in!',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorGoalDialog), findsNothing);
  });
}
