Map<String, Object?> communityGoalFixture({
  String id = 'goal-1',
  String status = 'STARTED',
  int needed = 10000000,
  int contributed = 2500000,
  int small = 250,
  int perStream = 2000,
  bool inStock = true,
  String title = 'Kids cam',
}) => {
  '__typename': 'CommunityPointsCommunityGoal',
  'id': id,
  'status': status,
  'backgroundColor': '#FF84F9',
  'durationDays': 30,
  'title': title,
  'description': 'At 10 million the kids cam turns on.',
  'image': {
    '__typename': 'CommunityPointsImage',
    'url': 'https://static-cdn.jtvnw.net/community-goal-images/1/goal-1.png',
    'url2x': 'https://static-cdn.jtvnw.net/community-goal-images/1/goal-2.png',
    'url4x': 'https://static-cdn.jtvnw.net/community-goal-images/1/goal-4.png',
  },
  'defaultImage': {
    '__typename': 'CommunityPointsImage',
    'url': 'https://static-cdn.jtvnw.net/community-goal-images/default-1.png',
    'url2x': 'https://static-cdn.jtvnw.net/community-goal-images/default-2.png',
    'url4x': 'https://static-cdn.jtvnw.net/community-goal-images/default-4.png',
  },
  'amountNeeded': needed,
  'pointsContributed': contributed,
  'smallContribution': small,
  'perStreamUserMaximumContribution': perStream,
  'isInStock': inStock,
  'startedAt': status == 'UNSTARTED' ? null : '2026-11-01T18:00:00Z',
  'endedAt': null,
  'type': 'CREATOR',
};

const unstartedCommunityGoalResponse = {
  'data': {
    'user': {
      'channel': {
        'communityPointsSettings': {
          'goals': [
            {
              '__typename': 'CommunityPointsCommunityGoal',
              'id': 'goal-0',
              'status': 'UNSTARTED',
              'backgroundColor': '#FF84F9',
              'durationDays': 30,
              'title': 'Kids cam',
              'description': 'At 10 million the kids cam turns on.',
              'image': {
                '__typename': 'CommunityPointsImage',
                'url':
                    'https://static-cdn.jtvnw.net/community-goal-images/1/goal-1.png',
                'url2x':
                    'https://static-cdn.jtvnw.net/community-goal-images/1/goal-2.png',
                'url4x':
                    'https://static-cdn.jtvnw.net/community-goal-images/1/goal-4.png',
              },
              'defaultImage': {
                '__typename': 'CommunityPointsImage',
                'url':
                    'https://static-cdn.jtvnw.net/community-goal-images/default-1.png',
                'url2x':
                    'https://static-cdn.jtvnw.net/community-goal-images/default-2.png',
                'url4x':
                    'https://static-cdn.jtvnw.net/community-goal-images/default-4.png',
              },
              'amountNeeded': 10000000,
              'pointsContributed': 0,
              'smallContribution': 250,
              'perStreamUserMaximumContribution': 2000,
              'isInStock': false,
              'startedAt': null,
              'endedAt': null,
              'type': 'CREATOR',
            },
          ],
        },
      },
    },
  },
};

Map<String, Object?> communityGoalsResponse(List<Map<String, Object?>> goals) =>
    {
      'data': {
        'user': {
          'channel': {
            'communityPointsSettings': {'goals': goals},
          },
        },
      },
    };

const noCommunityGoalsResponse = {
  'data': {
    'user': {
      'channel': {
        'communityPointsSettings': {'goals': <Object?>[]},
      },
    },
  },
};

const communityChallengeGoalsResponse = {
  'data': {
    'channel': {
      'id': '1',
      'communityPointsSettings': {
        'goals': [
          {
            'id': 'goal-1',
            'title': 'Kids cam',
            'description': 'At 10 million the kids cam turns on.',
            'status': 'STARTED',
            'type': 'CREATOR',
            'amountNeeded': 10000000,
            'pointsContributed': 2500000,
            'startedAt': '2026-11-01T18:00:00Z',
          },
        ],
      },
    },
  },
};

Map<String, Object?> goalContributionsResponse(Map<String, int> byGoal) => {
  'data': {
    'user': {
      'channel': {
        'self': {
          'communityPoints': {
            'goalContributions': [
              for (final entry in byGoal.entries)
                {
                  'goal': {'id': entry.key},
                  'userPointsContributedThisStream': entry.value,
                },
            ],
          },
        },
      },
    },
  },
};

Map<String, Object?> goalContributionResponse({String? errorCode}) => {
  'data': {
    'contributeCommunityPointsCommunityGoal': {
      'error': errorCode == null ? null : {'code': errorCode},
    },
  },
};
