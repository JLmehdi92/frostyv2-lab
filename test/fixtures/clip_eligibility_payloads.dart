const canCreateClipAnonymous = {
  'errors': [
    {
      'message': 'unauthenticated',
      'path': ['canCreateClip'],
      'extensions': {'code': 'Unauthenticated'},
    },
  ],
  'data': {'canCreateClip': null},
};

const canCreateClipAllowed = {
  'canCreateClip': {
    'isAllowed': true,
    'errorCode': null,
    'requiredFollowingLengthMinutes': null,
  },
};

Map<String, Object?> canCreateClipRefused(String code) => {
  'canCreateClip': {
    'isAllowed': false,
    'errorCode': code,
    'requiredFollowingLengthMinutes': 60,
  },
};

const djProfileUser = <String, Object?>{
  'id': '1',
  'login': 'djchannel',
  'roles': {'isParticipatingDJ': true},
};

const nonDjRoles = {'isParticipatingDJ': false};
