const clipExtrasLiveResponse = {
  'data': {
    'clip': {
      'id': '1000',
      'isAutoCurated': false,
      'assets': [
        {'type': 'SOURCE', 'aspectRatio': 1.7777777777777777},
        {'type': 'RECOMPOSED', 'aspectRatio': 0.5625},
      ],
    },
  },
  'extensions': {'operationName': 'ClipExtras'},
};

const clipExtrasAutoLandscapeResponse = {
  'data': {
    'clip': {
      'id': '1000',
      'isAutoCurated': true,
      'assets': [
        {'type': 'SOURCE', 'aspectRatio': 1.7777777777777777},
      ],
    },
  },
};

const clipCommentsLiveResponse = {
  'data': {
    'clip': {
      'comments': {
        'edges': [
          {
            'cursor': '',
            'node': {
              '__typename': 'ClipComment',
              'id': 'comment-1',
              'body': 'who is eggbert',
              'likeCount': 3,
              'replyCount': 1,
              'isHeartedByCreator': false,
              'isLikedByViewer': false,
              'isDownvotedByViewer': false,
              'isCollapsedByCommunity': false,
              'createdAt': '2026-11-06T03:35:43.361Z',
              'editedAt': null,
              'author': {
                'id': '1001',
                'login': 'viewer_one',
                'displayName': 'viewer_one',
                'profileImageURL':
                    'https://static-cdn.jtvnw.net/jtv_user_pictures/x-profile_image-70x70.png',
              },
              'authorBadges': <Object>[],
              'emotes': <Object>[],
              'parentComment': null,
            },
          },
          {
            'cursor': 'cursor-2',
            'node': {
              '__typename': 'ClipComment',
              'id': 'comment-2',
              'body': 'Egbert is a legend. LUL',
              'likeCount': 2,
              'replyCount': 0,
              'isHeartedByCreator': true,
              'isLikedByViewer': false,
              'isDownvotedByViewer': false,
              'isCollapsedByCommunity': true,
              'createdAt': '2026-11-08T04:14:08.608Z',
              'editedAt': null,
              'author': {
                'id': '1002',
                'login': 'viewer_two',
                'displayName': 'ViewerTwo',
                'profileImageURL':
                    'https://static-cdn.jtvnw.net/user-default-pictures-uv/x-profile_image-70x70.png',
              },
              'authorBadges': [
                {
                  '__typename': 'Badge',
                  'setID': 'share-the-love',
                  'version': '1',
                  'title': 'Share the Love',
                },
              ],
              'emotes': [
                {'emoteID': '425618', 'from': 20, 'to': 22},
              ],
              'parentComment': null,
            },
          },
        ],
        'pageInfo': {'hasNextPage': true, 'endCursor': 'cursor-2'},
      },
    },
  },
  'extensions': {'operationName': 'ClipCommentsQuery'},
};

Map<String, Object?> recapNode({
  String id = '2cca905c-0000-0000-0000-000000000000',
  String state = 'PUBLISHED',
}) => {
  'id': id,
  'title': 'Warzone night',
  'state': state,
  'streamStartAt': '2026-11-09T09:21:00Z',
  'postedAt': '2026-11-09T12:01:15Z',
  'channel': {'id': '1000', 'login': 'caster', 'displayName': 'Caster'},
  'clips': [
    {
      'position': 0,
      'clip': {
        'id': '2000',
        'slug': 'AmusedPlainTaro-yCRO7oUZG8QUP-yO',
        'title': 'im down',
        'viewCount': 1,
        'createdAt': '2026-11-09T12:04:40Z',
        'durationSeconds': 46,
        'thumbnailURL':
            'https://static-cdn.jtvnw.net/twitch-video-assets/x/landscape/thumb/thumb-0000000000-1920x1080.jpg',
        'videoOffsetSeconds': 6224,
        'curator': {'id': '1000', 'login': 'caster', 'displayName': 'Caster'},
        'broadcaster': {
          'id': '1000',
          'login': 'caster',
          'displayName': 'Caster',
        },
        'game': {'id': '1494', 'name': 'Call of Duty'},
        'video': {'id': '3000'},
      },
    },
    {
      'position': 0,
      'clip': {
        'id': '2001',
        'slug': 'WittyShySalamander-db_btRylMHE1bcIP',
        'title': 'second',
        'viewCount': 1,
        'createdAt': '2026-11-09T12:01:07Z',
        'durationSeconds': 49,
        'thumbnailURL': null,
        'videoOffsetSeconds': 6226,
        'curator': null,
        'broadcaster': {
          'id': '1000',
          'login': 'caster',
          'displayName': 'Caster',
        },
        'game': null,
        'video': null,
      },
    },
  ],
};

Map<String, Object?> channelRecapsResponse(List<Map<String, Object?>> nodes) =>
    {
      'data': {
        'recaps': {
          'edges': [
            for (final node in nodes) {'node': node},
          ],
        },
      },
      'extensions': {'operationName': 'ChannelRecaps'},
    };

Map<String, Object?> recapsByIdsResponse(List<Map<String, Object?>> nodes) => {
  'data': {'recapsByIDs': nodes},
  'extensions': {'operationName': 'RecapById'},
};
