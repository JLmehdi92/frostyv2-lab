const anonymousResubNotificationResponse = {
  'data': {
    'user': {'login': 'somechannel', 'self': null},
  },
};

const resubNotificationResponse = {
  'data': {
    'user': {
      'login': 'somechannel',
      'self': {
        'resubNotification': {
          'id': 'notification-1',
          'months': 14,
          'token': 'token-1',
          'isGiftSubscription': false,
          'gifter': null,
        },
      },
    },
  },
};

const noResubNotificationResponse = {
  'data': {
    'user': {
      'login': 'somechannel',
      'self': {'resubNotification': null},
    },
  },
};

const leaderboardsResponse = {
  'data': {
    'user': {
      'settings': {
        'leaderboard': {
          'defaultLeaderboard': 'SUBGIFT',
          'isCheerEnabled': true,
          'isSubGiftEnabled': true,
          'isClipEnabled': true,
          'timePeriod': 'WEEK',
        },
      },
      'channel': {
        'leaderboardSet': {
          'bits': {
            '__typename': 'UserLeaderboard',
            'id': 'bits-usage-by-channel-v1-1-WEEK-loggedout',
            'items': {
              'edges': [
                {
                  'node': {
                    '__typename': 'UserLeaderboardItem',
                    'rank': 1,
                    'score': 19800,
                    'user': {'id': '101', 'displayName': 'CheerOne'},
                  },
                },
                {
                  'node': {
                    '__typename': 'UserLeaderboardItem',
                    'rank': 2,
                    'score': 8301,
                    'user': {'id': '102', 'displayName': 'CheerTwo'},
                  },
                },
                {
                  'node': {
                    '__typename': 'UserLeaderboardItem',
                    'rank': 3,
                    'score': 1100,
                    'user': {'id': '103', 'displayName': 'cheer_three'},
                  },
                },
              ],
            },
            'myPosition': null,
          },
          'subGift': {
            '__typename': 'UserLeaderboard',
            'id': 'sub-gifts-sent-1-WEEK-loggedout',
            'items': {
              'edges': [
                {
                  'node': {
                    '__typename': 'UserLeaderboardItem',
                    'rank': 1,
                    'score': 161,
                    'user': {'id': '201', 'displayName': 'GifterOne'},
                  },
                },
                {
                  'node': {
                    '__typename': 'UserLeaderboardItem',
                    'rank': 2,
                    'score': 40,
                    'user': {'id': '202', 'displayName': 'GifterTwo'},
                  },
                },
              ],
            },
            'myPosition': null,
          },
          'clip': {
            '__typename': 'ClipLeaderboard',
            'id': 'clips-1',
            'items': {'edges': []},
            'myPosition': null,
          },
        },
      },
    },
  },
};

const shoutoutResponse = {
  'data': {
    'channel': {'id': '1', 'name': 'somechannel'},
    'user': {
      'id': '2',
      'displayName': 'Target',
      'profileImageURL':
          'https://static-cdn.jtvnw.net/jtv_user_pictures/target-profile_image-300x300.png',
      'primaryColorHex': 'E10F21',
      'channel': {
        'id': '2',
        'name': 'target',
        'home': {
          'shelves': {
            'categoryShelf': {
              'edges': [
                {
                  'node': {
                    'id': '10',
                    'boxArtURL':
                        'https://static-cdn.jtvnw.net/ttv-boxart/10-285x380.jpg',
                    'displayName': 'First Game',
                  },
                },
                {
                  'node': {
                    'id': '11',
                    'boxArtURL':
                        'https://static-cdn.jtvnw.net/ttv-boxart/11-285x380.jpg',
                    'displayName': 'VALORANT',
                  },
                },
                {'node': null},
              ],
            },
          },
        },
        'schedule': {'id': 'schedule-2', 'nextSegment': null},
      },
    },
  },
};

const anonymousShoutoutStatusResponse = {
  'data': {
    'user': {'id': '2', 'self': null},
  },
};

const followingShoutoutStatusResponse = {
  'data': {
    'user': {
      'id': '2',
      'self': {
        'follower': {'followedAt': '2025-03-01T10:00:00Z'},
        'canFollow': true,
        'banStatus': null,
      },
    },
  },
};
