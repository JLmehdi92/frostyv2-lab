import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/screens/channel/goals/creator_goal_banner.dart';

import '../helpers/l10n.dart';

CreatorGoal _goal(String id, CreatorGoalKind kind, {int current = 420}) =>
    CreatorGoal(
      id: id,
      kind: kind,
      state: CreatorGoalState.active,
      description: 'Nouvelle caméra',
      current: current,
      target: 1000,
    );

Map<String, Widget Function()> lot6Screens() => {
  'the goal banner': () => Scaffold(
    body: CreatorGoalBanner(
      goals: () => [
        _goal('a', CreatorGoalKind.newSubPoints),
        _goal('b', CreatorGoalKind.followers),
      ],
    ),
  ),
  'the goal reached dialog': () => Scaffold(
    body: CreatorGoalDialog(
      goal: _goal('a', CreatorGoalKind.subs, current: 1000),
    ),
  ),
};

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final MapEntry(key: name, value: build) in lot6Screens().entries) {
        testWidgets('$name, $at', (tester) async {
          await pumpLocalized(tester, build(), size: size, textScale: scale);
          await tester.pumpAndSettle();
          await expectFrenchThroughout(
            tester,
            '$name, $at',
            content: const ['Nouvelle caméra'],
          );
        });
      }
    }
  }
}
