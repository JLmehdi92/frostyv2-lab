Map<String, Object?> weeklyRewardsResponse({
  int visited = 2,
  int currentTier = 1,
  bool earned = false,
}) => {
  'data': {
    'channel': {
      'id': '1000',
      'self': {
        'id': '1000',
        'weeklyVisitRewards': {
          'daysVisitedThisWeek': visited,
          'accumulatedWeeks': 1,
          'hasEarnedWeeklyRewardThisWeek': earned,
          'hasVisitedToday': true,
          'currentReward': {
            'tier': currentTier,
            'channelPoints': 250,
            'badge': {
              'id': 'b1',
              'image4x': 'https://static-cdn.jtvnw.net/badges/v1/b1/3',
            },
          },
          'eventConfig': {
            'id': 'event-1',
            'daysRequiredPerWeek': 3,
            'endDate': '2026-12-01T00:00:00Z',
            'weekResetDates': [
              '2026-11-15T00:00:00Z',
              '2026-11-08T00:00:00Z',
              '2026-11-22T00:00:00Z',
            ],
            'rewardTiers': [
              {
                'tier': 2,
                'channelPoints': 500,
                'badge': {'id': 'b2', 'image4x': 'http://insecure/b2'},
              },
              {
                'tier': 1,
                'channelPoints': 250,
                'badge': {
                  'id': 'b1',
                  'image4x': 'https://static-cdn.jtvnw.net/badges/v1/b1/3',
                },
              },
            ],
          },
        },
      },
    },
  },
};

const noWeeklyRewardsResponse = {
  'data': {
    'channel': {
      'id': '1000',
      'self': {'id': '1000', 'weeklyVisitRewards': null},
    },
  },
};

const unlockableEmotesResponse = {
  'data': {
    'user': {
      'id': '1000',
      'subscriptionProducts': [
        {
          'id': 'p1',
          'tier': '1000',
          'emotes': [
            {'id': 'emotesv2_aaa', 'token': 'chanHi'},
            {'id': '301', 'token': 'chanGg'},
            {'id': 'bad id!', 'token': 'chanBad'},
          ],
        },
        {
          'id': 'p2',
          'tier': '2000',
          'emotes': [
            {'id': '302', 'token': 'chanTier2'},
          ],
        },
      ],
    },
  },
};
