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

const djRoleLive = {
  'data': {
    'user': {
      'id': '594263972',
      'roles': {'isParticipatingDJ': true},
    },
  },
};

const djRoleRejected = {
  'errors': [
    {'message': 'Cannot query field "isParticipatingDJ" on type "Roles".'},
  ],
};
