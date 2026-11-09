Map<String, Object?> _badge(String set, String version, String title) => {
  '__typename': 'Badge',
  'setID': set,
  'imageUrlNormal': 'https://static-cdn.jtvnw.net/badges/v1/$set-1',
  'imageUrlDouble': 'https://static-cdn.jtvnw.net/badges/v1/$set-2',
  'imageUrlQuadruple': 'https://static-cdn.jtvnw.net/badges/v1/$set-3',
  'version': version,
  'title': title,
};

const chatIdentityAnonymousResponse = {
  'data': {
    'user': null,
    'channel': {'id': '1000', 'displayName': 'ThisChannel', 'self': null},
    'channelFlair': {
      'creatorBadgeFlair': {'setting': 'DEFAULT'},
    },
  },
};

Map<String, Object?> chatIdentityResponse({bool flairHidden = false}) => {
  'data': {
    'user': {
      'id': '2000',
      'login': 'viewer',
      'displayName': 'Viewer',
      'chatColor': '#FF0000',
      'availableBadges': [
        _badge('premium', '1', 'Prime Gaming'),
        _badge('glhf-pledge', '1', 'GLHF Pledge'),
      ],
      'selectedBadge': _badge('premium', '1', 'Prime Gaming'),
      'subscriptionSettings': {'isBadgeModifierHidden': flairHidden},
    },
    'channel': {
      'id': '1000',
      'displayName': 'ThisChannel',
      'self': {
        'displayBadges': [_badge('subscriber', '3012', 'Subscriber')],
        'availableBadges': [
          _badge('subscriber', '3012', 'Subscriber'),
          _badge('sub-gifter', '5', '5 Gift Subs'),
        ],
        'availableChannelAuthorityBadges': [],
        'selectedBadge': _badge('subscriber', '3012', 'Subscriber'),
        'selectedChannelAuthorityBadge': null,
        'isFounder': false,
        'isModerator': false,
        'isVIP': false,
        'subscriptionBenefit': {'tier': '3000'},
        'subscriptionTenure': {'months': 12},
      },
    },
    'channelFlair': {
      'creatorBadgeFlair': {'setting': 'DEFAULT'},
    },
  },
};
