// Trimmed, anonymised GQL/usher responses captured on 2026-10-13 with the
// public web Client-ID (full query text, no user token). Ids, names and URLs
// are fake but keep the real shapes.

const vodNodeArchive = {
  'id': '1000000001',
  'title': 'Morning stream',
  'lengthSeconds': 29580,
  'createdAt': '2026-10-12T17:33:44Z',
  'publishedAt': '2026-10-12T17:33:44Z',
  'viewCount': 25919,
  'status': 'RECORDED',
  'broadcastType': 'ARCHIVE',
  'previewThumbnailURL':
      'https://static-cdn.jtvnw.net/cf_vods/abc/streamer_1//thumb/thumb0-320x180.jpg',
  'game': {'id': '509658', 'name': 'Just Chatting'},
  'owner': {'id': '42', 'login': 'streamer', 'displayName': 'Streamer'},
  'broadcast': {'id': '300000000001'},
  'self': {'isRestricted': false},
};

const vodNodeHighlightNoGame = {
  'id': '1000000002',
  'title': 'Best moments',
  'lengthSeconds': 600,
  'createdAt': '2026-10-10T10:00:00Z',
  'viewCount': 12,
  'status': 'RECORDED',
  'broadcastType': 'HIGHLIGHT',
  'previewThumbnailURL': null,
  'game': null,
  'owner': {'id': '42', 'login': 'streamer', 'displayName': 'Streamer'},
  'self': {'isRestricted': true},
};

const vodNodeRecording = {
  'id': '1000000003',
  'title': 'Live right now',
  'lengthSeconds': 3600,
  'createdAt': '2026-10-13T08:00:00Z',
  'viewCount': 5,
  'status': 'RECORDING',
  'broadcastType': 'ARCHIVE',
  'previewThumbnailURL':
      'https://static-cdn.jtvnw.net/cf_vods/abc/streamer_3//thumb/thumb0-320x180.jpg',
  'game': {'id': '1', 'name': 'Chess'},
  'owner': {'id': '42', 'login': 'streamer', 'displayName': 'Streamer'},
};

const vodListResponse = {
  'data': {
    'user': {
      'id': '42',
      'login': 'streamer',
      'displayName': 'Streamer',
      'videos': {
        'edges': [
          {'cursor': 'cursor-1', 'node': vodNodeArchive},
          {'cursor': 'cursor-2', 'node': vodNodeRecording},
        ],
        'pageInfo': {'hasNextPage': true},
      },
    },
  },
};

const vodListEmptyResponse = {
  'data': {
    'user': {
      'id': '42',
      'login': 'streamer',
      'displayName': 'Streamer',
      'videos': {
        'edges': <Object>[],
        'pageInfo': {'hasNextPage': false},
      },
    },
  },
};

const vodListUnknownUserResponse = {
  'data': {'user': null},
};

const vodDetailResponse = {
  'data': {'video': vodNodeArchive},
};

const vodMissingResponse = {
  'data': {'video': null},
};

const vodCommentsResponse = {
  'data': {
    'video': {
      'comments': {
        'edges': [
          {
            'cursor': 'c1',
            'node': {
              'id': 'comment-1',
              'contentOffsetSeconds': 3591,
              'commenter': {
                'id': '1001',
                'login': 'viewer_one',
                'displayName': 'Viewer_One',
              },
              'message': {
                'fragments': [
                  {'text': 'hello ', 'emote': null},
                  {
                    'text': 'Kappa',
                    'emote': {'emoteID': '25'},
                  },
                  {'text': ' catJAM', 'emote': null},
                ],
                'userBadges': [
                  {'setID': 'subscriber', 'version': '12'},
                  {'setID': 'premium', 'version': '1'},
                ],
                'userColor': '#FF4500',
              },
            },
          },
          {
            'cursor': 'c2',
            'node': {
              'id': 'comment-2',
              'contentOffsetSeconds': 3592,
              'commenter': null,
              'message': {
                'fragments': [
                  {'text': 'from a deleted account', 'emote': null},
                ],
                'userBadges': <Object>[],
                'userColor': null,
              },
            },
          },
        ],
        'pageInfo': {'hasNextPage': true},
      },
    },
  },
};

const vodCommentsIntegrityResponse = {
  'errors': [
    {
      'message': 'failed integrity check',
      'path': ['video', 'comments'],
      'extensions': {'code': 'IntegrityCheckFailed'},
    },
  ],
  'data': {
    'video': {'comments': null},
  },
};

const vodCommentsServiceErrorResponse = {
  'errors': [
    {
      'message': 'service error',
      'path': ['video', 'comments'],
    },
  ],
  'data': {
    'video': {'comments': null},
  },
};

const vodMutedSegmentsResponse = {
  'data': {
    'video': {
      'muteInfo': {
        'mutedSegmentConnection': {
          'nodes': [
            {'offset': 120, 'duration': 360},
            {'offset': 1800, 'duration': 180},
          ],
        },
      },
    },
  },
};

const vodTokenValue =
    '{"authorization":{"forbidden":false,"reason":""},'
    '"chansub":{"restricted_bitrates":[]},"expires":4102444800,'
    '"vod_id":1000000001,"version":3}';

const vodTokenForbiddenValue =
    '{"authorization":{"forbidden":true,"reason":"geoblocked"},'
    '"chansub":{"restricted_bitrates":["chunked","720p60"]},'
    '"expires":4102444800,"vod_id":1000000001}';

/// A token asked with the viewer's web token: it names the viewer.
const vodTokenAuthValue =
    '{"authorization":{"forbidden":false,"reason":""},'
    '"chansub":{"restricted_bitrates":[]},"expires":4102444800,'
    '"user_id":4242,"vod_id":1000000001,"version":3}';

const vodTokenAuthResponse = {
  'data': {
    'videoPlaybackAccessToken': {
      'value': vodTokenAuthValue,
      'signature': 'authsig',
    },
  },
};

const vodTokenResponse = {
  'data': {
    'videoPlaybackAccessToken': {'value': vodTokenValue, 'signature': 'vodsig'},
  },
};

const vodTokenForbiddenResponse = {
  'data': {
    'videoPlaybackAccessToken': {
      'value': vodTokenForbiddenValue,
      'signature': 'vodsig',
    },
  },
};

const usherRestrictedBody = [
  {
    'url': 'https://usher.ttvnw.net/vod/1000000001.m3u8',
    'error': 'This video is only available to subscribers.',
    'error_code': 'vod_manifest_restricted',
    'type': 'error',
  },
];

const usherGeoBlockedBody = [
  {
    'error': 'Content is not available in your region',
    'error_code': 'content_geoblocked',
    'type': 'error',
  },
];
