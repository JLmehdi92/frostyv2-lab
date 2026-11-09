Map<String, Object?> personalSectionsResponse() => {
  'data': {
    'personalSections': [
      {
        'type': 'POPULAR_SECTION',
        'title': {'localizedFallback': 'Popular Channels'},
        'items': [
          {
            '__typename': 'PersonalSectionChannel',
            'user': {
              'id': '1001',
              'login': 'alpha_live',
              'displayName': 'Alpha_Live',
              'profileImageURL':
                  'https://static-cdn.jtvnw.net/jtv_user_pictures/a-profile_image-70x70.png',
            },
            'content': {
              '__typename': 'Stream',
              'id': '9001',
              'broadcaster': {
                'id': '1001',
                'broadcastSettings': {'id': '1001', 'title': 'Morning run'},
              },
              'codec': 'avc1.64002A',
              'isDualFormat': false,
              'viewersCount': 23790,
              'game': {'displayName': 'Just Chatting'},
            },
          },
          {
            '__typename': 'PersonalSectionChannel',
            'user': {
              'id': '1002',
              'login': 'beta',
              'displayName': 'beta',
              'profileImageURL':
                  'https://static-cdn.jtvnw.net/jtv_user_pictures/b-profile_image-70x70.png',
            },
            'content': {
              '__typename': 'Stream',
              'id': '9002',
              'broadcaster': {
                'id': '1002',
                'broadcastSettings': {'id': '1002', 'title': 'Ranked'},
              },
              'codec': 'avc1.64002A',
              'isDualFormat': false,
              'viewersCount': 1200,
              'game': {'displayName': 'Chess'},
            },
          },
        ],
      },
    ],
  },
  'extensions': {'operationName': 'PersonalSections'},
};

Map<String, Object?> whisperMessageNode({
  required String id,
  required String fromId,
  required String fromLogin,
  required String text,
  required String sentAt,
}) => {
  '__typename': 'WhisperMessage',
  'id': id,
  'from': {
    'login': fromLogin,
    'displayName': fromLogin,
    'id': fromId,
    'chatColor': '#FF0000',
    'displayBadges': <Object?>[],
  },
  'sentAt': sentAt,
  'content': {'content': text, 'emotes': <Object?>[]},
};

Map<String, Object?> whisperThreadsResponse() => {
  'data': {
    'currentUser': {
      'whisperThreads': {
        'edges': [
          {
            'cursor': 'c1',
            'node': {
              '__typename': 'WhisperThread',
              'id': '100_200',
              'participants': [
                {
                  'login': 'me',
                  'displayName': 'Me',
                  'id': '100',
                  'chatColor': null,
                },
                {
                  'login': 'friend',
                  'displayName': 'Friend',
                  'id': '200',
                  'chatColor': null,
                },
              ],
              'messages': {
                'edges': [
                  {
                    'node': whisperMessageNode(
                      id: 'm2',
                      fromId: '200',
                      fromLogin: 'friend',
                      text: 'See you tonight',
                      sentAt: '2026-11-08T20:00:00Z',
                    ),
                  },
                ],
              },
              'unreadMessagesCount': 2,
              'isArchived': false,
              'isMuted': false,
            },
          },
        ],
        'pageInfo': {'hasNextPage': false, 'hasPreviousPage': false},
        'totalCount': 1,
        'totalUnreadCount': 2,
      },
    },
  },
};

Map<String, Object?> whisperMessagesResponse() => {
  'data': {
    'whisperThread': {
      'messages': {
        'edges': [
          {
            'cursor': 'x2',
            'node': whisperMessageNode(
              id: 'm2',
              fromId: '200',
              fromLogin: 'friend',
              text: 'See you tonight',
              sentAt: '2026-11-08T20:00:00Z',
            ),
          },
          {
            'cursor': 'x1',
            'node': whisperMessageNode(
              id: 'm1',
              fromId: '100',
              fromLogin: 'me',
              text: 'Ready?',
              sentAt: '2026-11-08T19:58:00Z',
            ),
          },
        ],
        'pageInfo': {'hasNextPage': false},
      },
      'lastMessage': null,
    },
  },
};

Map<String, Object?> whisperPrivacyResponse({required bool block}) => {
  'data': {
    'currentUser': {
      'login': 'me',
      'whisperSettings': {
        'isWhisperBanned': false,
        'isBlockingWhispersFromStrangers': block,
        'isWhispersDisabledByParent': false,
      },
    },
  },
};

Map<String, Object?> onsiteNotificationNode({
  String id = 'n1',
  bool isRead = false,
  String body = '<b>Friend</b> is live: Morning run',
}) => {
  '__typename': 'OnsiteNotification',
  'actions': [
    {'body': 'Watch', 'type': 'click', 'url': 'https://www.twitch.tv/friend'},
  ],
  'body': body,
  'category': 'live',
  'createdAt': '2026-11-08T20:00:00Z',
  'creators': [
    {
      'profileImageURL':
          'https://static-cdn.jtvnw.net/jtv_user_pictures/f-profile_image-70x70.png',
      'id': '200',
      'displayName': 'Friend',
    },
  ],
  'destinationType': 'channel',
  'displayType': 'standard',
  'extra': {'__typename': 'User', 'login': 'friend', 'id': '200'},
  'id': id,
  'isRead': isRead,
  'thumbnailURL': null,
  'type': 'stream_up',
  'updatedAt': '2026-11-08T20:00:00Z',
};

Map<String, Object?> onsiteNotificationsResponse(
  List<Map<String, Object?>> nodes,
) => {
  'data': {
    'user': {
      'notifications': {
        'edges': [
          for (final (i, node) in nodes.indexed) {'cursor': 'cur$i', 'node': node},
        ],
      },
    },
  },
};

Map<String, Object?> notificationSettingsResponse() => {
  'data': {
    'user': {
      'notificationSettings': [
        {
          'category': 'live',
          'platforms': [
            {'platformName': 'push', 'settingState': 'ON', 'isEnabled': true},
            {
              'platformName': 'email',
              'settingState': 'OFF',
              'isEnabled': false,
            },
          ],
        },
        {
          'category': 'whispers',
          'platforms': [
            {
              'platformName': 'push',
              'settingState': 'OFF',
              'isEnabled': false,
            },
          ],
        },
      ],
    },
  },
};
