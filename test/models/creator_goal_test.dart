import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/creator_goal.dart';

Map<String, Object?> _raw({
  String id = 'g1',
  String type = 'SUBS',
  String state = 'STARTED',
  num current = 3,
  num target = 10,
}) => {
  'id': id,
  'contributionType': type,
  'state': state,
  'description': '  New camera  ',
  'currentContributions': current,
  'targetContributions': target,
};

void main() {
  test('parses a sub goal', () {
    final goal = CreatorGoal.tryParse(_raw())!;
    expect(goal.kind, CreatorGoalKind.subs);
    expect(goal.state, CreatorGoalState.active);
    expect(goal.description, 'New camera');
    expect(goal.progress, closeTo(0.3, 1e-9));
    expect(goal.isReached, isFalse);
  });

  test('parses every kind and falls back to other', () {
    CreatorGoalKind kind(String type) =>
        CreatorGoal.tryParse(_raw(type: type))!.kind;
    expect(kind('FOLLOWERS'), CreatorGoalKind.followers);
    expect(kind('SUB_POINTS'), CreatorGoalKind.subPoints);
    expect(kind('NEW_SUBS'), CreatorGoalKind.newSubs);
    expect(kind('NEW_SUB_POINTS'), CreatorGoalKind.newSubPoints);
    expect(kind('MANUAL'), CreatorGoalKind.other);
  });

  test('reads reached and ended from the state or the event', () {
    expect(
      CreatorGoal.tryParse(_raw(state: 'ACHIEVED'))!.state,
      CreatorGoalState.reached,
    );
    expect(
      CreatorGoal.tryParse(_raw(), eventType: 'goal_achieved')!.state,
      CreatorGoalState.reached,
    );
    expect(
      CreatorGoal.tryParse(_raw(), eventType: 'goal_ended')!.state,
      CreatorGoalState.ended,
    );
  });

  test('progress is capped and a full count reads as reached', () {
    final goal = CreatorGoal.tryParse(_raw(current: 12))!;
    expect(goal.progress, 1);
    expect(goal.isReached, isTrue);
  });

  test('refuses malformed goals', () {
    expect(CreatorGoal.tryParse('nope'), isNull);
    expect(CreatorGoal.tryParse(_raw(target: 0)), isNull);
    expect(CreatorGoal.tryParse({..._raw(), 'id': ''}), isNull);
    expect(
      CreatorGoal.tryParse({..._raw(), 'currentContributions': 'x'}),
      isNull,
    );
  });

  test('merging keeps order, replaces in place and drops ended goals', () {
    final a = CreatorGoal.tryParse(_raw(id: 'a'))!;
    final b = CreatorGoal.tryParse(_raw(id: 'b'))!;
    var goals = mergeCreatorGoal(const [], a);
    goals = mergeCreatorGoal(goals, b);
    expect(goals.map((g) => g.id), ['a', 'b']);

    goals = mergeCreatorGoal(
      goals,
      CreatorGoal.tryParse(_raw(id: 'a', current: 5))!,
    );
    expect(goals.map((g) => g.id), ['a', 'b']);
    expect(goals.first.current, 5);

    goals = mergeCreatorGoal(
      goals,
      CreatorGoal.tryParse(_raw(id: 'a'), eventType: 'goal_ended')!,
    );
    expect(goals.map((g) => g.id), ['b']);
  });
}
