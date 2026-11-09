const unrestrictedStreamResponse = {
  'data': {
    'user': {
      'stream': {
        'id': '1',
        'restrictionType': null,
        'restrictionOptions': <String>[],
      },
    },
  },
};

Map<String, Object?> restrictedStreamResponse(List<String> options) => {
  'data': {
    'user': {
      'stream': {
        'id': '1',
        'restrictionType': 'SUB_ONLY_LIVE',
        'restrictionOptions': options,
      },
    },
  },
};

const unlimitedTokenValue =
    '{"chansub":{"restricted_bitrates":[],"view_until":1924905600},'
    '"expires":1794220976}';

String previewTokenValue({required int viewUntil, required int expires}) =>
    '{"chansub":{"restricted_bitrates":[],"view_until":$viewUntil},'
    '"expires":$expires}';
