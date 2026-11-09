const channelRestrictionLiveResponse = {
  'data': {
    'user': {'id': '1000', 'channelSafetyStatus': <String>[]},
  },
  'extensions': {'operationName': 'ChannelProfileRestriction'},
};

Map<String, Object?> channelRestrictionResponse(List<String> statuses) => {
  'data': {
    'user': {'id': '1000', 'channelSafetyStatus': statuses},
  },
};

Map<String, Object?> followUserResponse({String? errorCode}) => {
  'data': {
    'followUser': {
      'follow': errorCode == null ? {'disableNotifications': false} : null,
      'error': errorCode == null ? null : {'code': errorCode},
    },
  },
};

const unfollowUserResponse = {
  'data': {
    'unfollowUser': {
      'follow': {'disableNotifications': false},
    },
  },
};

Map<String, Object?> followGameResponse(String field) => {
  'data': {
    field: {
      'game': {'__typename': 'Game', 'id': '509658', 'name': 'Just Chatting'},
    },
  },
};

const integrityRefusedResponse = {
  'errors': [
    {
      'message': 'failed integrity check',
      'path': ['followUser'],
    },
  ],
  'data': {'followUser': null},
};

Map<String, Object?> giftSettingsResponse({
  bool followedOnly = false,
  bool hidden = false,
}) => {
  'data': {
    'currentUser': {
      'id': '77',
      'subscriptionSettings': {
        'giftsToFollowedChannelsOnly': followedOnly,
        'isGiftCountHidden': hidden,
      },
    },
  },
};

Map<String, Object?> updateGiftSettingsResponse({
  bool followedOnly = false,
  bool hidden = false,
}) => {
  'data': {
    'updateUserSubscriptionSettings': {
      'subscriptionSettings': {
        'giftsToFollowedChannelsOnly': followedOnly,
        'isGiftCountHidden': hidden,
      },
    },
  },
};
