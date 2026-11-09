Map<String, Object?> pinataResponse({
  String typename = 'PinataTrainDetails',
  bool active = true,
  bool? eligible = true,
}) => {
  'data': {
    'user': {
      'id': '1000',
      'channel': {
        'id': '1000',
        'hypeTrain': {
          'execution': {
            'id': 'train-1',
            'isActive': active,
            'endedAt': null,
            'expiresAt': '2026-11-09T20:05:00Z',
            'variantTrainDetails': {
              '__typename': typename,
              'id': 'p1',
              'deteriorationStage': 2,
            },
            'self': eligible == null
                ? null
                : {'isEligibleForRewards': eligible},
          },
        },
      },
    },
  },
};

const noPinataResponse = {
  'data': {
    'user': {
      'id': '1000',
      'channel': {
        'id': '1000',
        'hypeTrain': {'execution': null},
      },
    },
  },
};
