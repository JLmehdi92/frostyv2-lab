// Trimmed from live anonymous GQL answers (2026-10-13). Tokens and
// signatures are fakes; the shapes are Twitch's.

const clipNode = {
  'id': '2308545921',
  'slug': 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC',
  'title': 'breakup advice',
  'viewCount': 16337,
  'createdAt': '2026-10-10T20:30:36Z',
  'durationSeconds': 60,
  'thumbnailURL':
      'https://static-cdn.jtvnw.net/twitch-video-assets/x/landscape/thumb/thumb-0000000000-1920x1080.jpg',
  'url':
      'https://www.twitch.tv/xqc/clip/InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC',
  'videoOffsetSeconds': 1077,
  'language': 'EN',
  'curator': {
    'id': '900000201',
    'login': 'clipper_1',
    'displayName': 'clipper_1',
  },
  'broadcaster': {'id': '71092938', 'login': 'xqc', 'displayName': 'xQc'},
  'game': {'id': '509658', 'name': 'Just Chatting'},
  'video': {'id': '2897283075'},
};

/// A clip whose VOD is gone and whose clipper deleted their account.
const clipNodeOrphan = {
  'id': '1066051531',
  'slug': 'SmokyArtsyFloofResidentSleeper',
  'title': 'Jean Paul Wick',
  'viewCount': 7994,
  'createdAt': '2026-10-07T22:46:13Z',
  'durationSeconds': 36,
  'thumbnailURL': null,
  'url': 'https://www.twitch.tv/xqc/clip/SmokyArtsyFloofResidentSleeper',
  'videoOffsetSeconds': null,
  'language': 'EN',
  'curator': null,
  'broadcaster': {'id': '71092938', 'login': 'xqc', 'displayName': 'xQc'},
  'game': null,
  'video': null,
};

const clipListResponse = {
  'data': {
    'user': {
      'id': '71092938',
      'clips': {
        'edges': [
          {'cursor': null, 'node': clipNode},
          {'cursor': 'Mw==', 'node': clipNodeOrphan},
        ],
        'pageInfo': {'hasNextPage': true},
      },
    },
  },
};

const clipListEmptyResponse = {
  'data': {
    'user': {
      'id': '1',
      'clips': {
        'edges': <Object>[],
        'pageInfo': {'hasNextPage': false},
      },
    },
  },
};

const clipUserNotFoundResponse = {
  'data': {'user': null},
};

const clipServerErrorResponse = {
  'errors': [
    {
      'message': 'server error',
      'path': ['user', 'clips'],
    },
  ],
  'data': {
    'user': {'clips': null},
  },
};

const clipIntegrityResponse = {
  'errors': [
    {
      'message': 'failed integrity check',
      'path': ['user', 'clips'],
      'extensions': {'code': 'IntegrityCheckFailed'},
    },
  ],
  'data': {
    'user': {'clips': null},
  },
};

const clipMetadataResponse = {
  'data': {'clip': clipNode},
};

const clipNotFoundResponse = {
  'data': {'clip': null},
};

const _cdn = 'https://d1ndex63qxojbr.cloudfront.net/nauth/fd8f521e';

const clipTokenValue =
    '{"authorization":{"forbidden":false,"reason":""},'
    '"clip_uri":"$_cdn/landscape/h264/720/index.mp4",'
    '"clip_slug":"InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC",'
    '"device_id":null,"expires":1791993096,"user_id":"","version":3}';

Map<String, Object?> clipPlaybackResponse({
  String tokenValue = clipTokenValue,
  List<Object?>? assets,
  List<Object?>? videoQualities,
}) => {
  'data': {
    'clip': {
      'id': '2308545921',
      'slug': 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC',
      'playbackAccessToken': {'signature': 'fakesig', 'value': tokenValue},
      'videoQualities':
          videoQualities ??
          [
            {
              'quality': '1080',
              'frameRate': 60,
              'sourceURL': '$_cdn/landscape/1080/index.mp4',
            },
            {
              'quality': '720',
              'frameRate': 60.011,
              'sourceURL': '$_cdn/landscape/720/index.mp4',
            },
            {
              'quality': '360',
              'frameRate': 30.0055,
              'sourceURL': '$_cdn/landscape/360/index.mp4',
            },
          ],
      'assets':
          assets ??
          [
            {
              'type': 'SOURCE',
              'aspectRatio': 1.7777,
              'videoQualities': [
                {
                  'quality': '1080',
                  'frameRate': 60,
                  'codecs': 'avc1.4D402A',
                  'sourceURL': '$_cdn/landscape/1080/index.mp4',
                },
                {
                  'quality': '720',
                  'frameRate': 60.011,
                  'codecs': 'avc1.64002A,mp4a.40.2',
                  'sourceURL': '$_cdn/landscape/720/index.mp4',
                },
                {
                  'quality': '480',
                  'frameRate': 30.0055,
                  'codecs': 'avc1.64002A,mp4a.40.2',
                  'sourceURL': '$_cdn/landscape/480/index.mp4',
                },
              ],
            },
            {
              'type': 'RECOMPOSED',
              'aspectRatio': 0.5625,
              'videoQualities': [
                {
                  'quality': '972',
                  'frameRate': 60,
                  'codecs': 'avc1.4D402A',
                  'sourceURL': '$_cdn/portrait/972/index.mp4',
                },
              ],
            },
          ],
    },
  },
};

const clipForbiddenTokenValue =
    '{"authorization":{"forbidden":true,"reason":"geoblocked"},'
    '"clip_slug":"x","expires":1791993096,"version":3}';
