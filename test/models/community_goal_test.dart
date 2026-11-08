import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_goal.dart';

import '../fixtures/community_goal_payloads.dart';

void main() {
  group('CommunityGoal.listFrom', () {
    test('reads a running goal', () {
      final goal = CommunityGoal.listFrom(
        communityGoalsResponse([communityGoalFixture()]),
      )!.single;

      expect(goal.id, 'goal-1');
      expect(goal.title, 'Kids cam');
      expect(goal.description, 'At 10 million the kids cam turns on.');
      expect(goal.status, CommunityGoalStatus.started);
      expect(goal.amountNeeded, 10000000);
      expect(goal.pointsContributed, 2500000);
      expect(goal.percentRaised, 25);
      expect(goal.smallContribution, 250);
      expect(goal.perStreamMaximum, 2000);
      expect(goal.isOpen, isTrue);
      expect(
        goal.imageUrl,
        Uri.parse(
          'https://static-cdn.jtvnw.net/community-goal-images/1/goal-2.png',
        ),
      );
      expect(goal.color, 0xFFFF84F9);
    });

    test('reads the challenge goals of the channel query', () {
      final goal = CommunityGoal.listFrom(
        communityChallengeGoalsResponse,
      )!.single;

      expect(goal.percentRaised, 25);
      expect(goal.isOpen, isFalse);
    });

    test('hides goals that have not started or were archived', () {
      expect(CommunityGoal.listFrom(unstartedCommunityGoalResponse), isEmpty);
      expect(
        CommunityGoal.listFrom(
          communityGoalsResponse([communityGoalFixture(status: 'ARCHIVED')]),
        ),
        isEmpty,
      );
      final ended = CommunityGoal.listFrom(
        communityGoalsResponse([
          communityGoalFixture(status: 'FULFILLED', contributed: 10000000),
        ]),
      )!.single;
      expect(ended.status, CommunityGoalStatus.fulfilled);
      expect(ended.isOpen, isFalse);
      expect(ended.percentRaised, 100);
    });

    test('a failed or odd answer is null, an empty list is empty', () {
      expect(CommunityGoal.listFrom(noCommunityGoalsResponse), isEmpty);
      expect(
        CommunityGoal.listFrom({
          'errors': [
            {'message': 'boom'},
          ],
        }),
        isNull,
      );
      expect(CommunityGoal.listFrom(null), isNull);
      expect(
        CommunityGoal.listFrom(
          communityGoalsResponse([
            {'id': 'x', 'status': 'STARTED'},
            {'title': 'no id'},
          ]),
        ),
        isEmpty,
      );
    });
  });

  group('contributions', () {
    test('reads what the viewer gave this stream', () {
      expect(
        CommunityGoal.contributionsFrom(
          goalContributionsResponse({'goal-1': 500}),
        ),
        {'goal-1': 500},
      );
      expect(CommunityGoal.contributionsFrom({'data': null}), isEmpty);
    });

    test('caps a contribution by balance, stream limit and what is left', () {
      final goal = CommunityGoal.listFrom(
        communityGoalsResponse([communityGoalFixture()]),
      )!.single.withContributedThisStream(500);

      expect(goal.maxContribution(balance: 100000), 1500);
      expect(goal.maxContribution(balance: 300), 300);
      expect(goal.isMaxedThisStream, isFalse);
      expect(goal.withContributedThisStream(2000).isMaxedThisStream, isTrue);
      expect(
        goal.withContributedThisStream(2000).maxContribution(balance: 9),
        0,
      );

      final nearlyDone = CommunityGoal.listFrom(
        communityGoalsResponse([
          communityGoalFixture(needed: 1000, contributed: 900, perStream: 0),
        ]),
      )!.single;
      expect(nearlyDone.maxContribution(balance: 5000), 100);
    });
  });

  group('GoalContributionResult.fromBody', () {
    test('maps the error codes', () {
      expect(
        GoalContributionResult.fromBody(goalContributionResponse()),
        GoalContributionResult.contributed,
      );
      expect(
        GoalContributionResult.fromBody(
          goalContributionResponse(errorCode: 'NOT_ENOUGH_POINTS'),
        ),
        GoalContributionResult.notEnoughPoints,
      );
      expect(
        GoalContributionResult.fromBody(
          goalContributionResponse(errorCode: 'MAX_PER_STREAM'),
        ),
        GoalContributionResult.maxPerStream,
      );
      expect(
        GoalContributionResult.fromBody(
          goalContributionResponse(errorCode: 'NOT_CURRENTLY_REDEEMABLE'),
        ),
        GoalContributionResult.notOpen,
      );
      expect(
        GoalContributionResult.fromBody(
          goalContributionResponse(errorCode: 'USER_BANNED'),
        ),
        GoalContributionResult.refused,
      );
    });

    test('an integrity error or an odd body is no contribution', () {
      expect(
        GoalContributionResult.fromBody({
          'errors': [
            {'message': 'failed integrity'},
          ],
        }),
        GoalContributionResult.integrityRefused,
      );
      expect(
        GoalContributionResult.fromBody({'data': {}}),
        GoalContributionResult.failed,
      );
    });
  });
}
