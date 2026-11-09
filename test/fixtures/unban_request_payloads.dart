const unbanAnonymousResponse = {
  'errors': [
    {
      'message': 'server error',
      'path': ['channel', 'self', 'lastUnbanRequest'],
    },
    {
      'message': 'unauthenticated',
      'path': ['channel', 'self', 'canRequestUnban'],
      'extensions': {'code': 'Unauthenticated'},
    },
  ],
  'data': {
    'channel': {
      'id': '1000',
      'self': {'id': '1000', 'canRequestUnban': null, 'lastUnbanRequest': null},
      'unbanRequestsSettings': {'cooldownMinutes': 300, 'isEnabled': true},
    },
  },
};

Map<String, Object?> unbanResponse({
  bool canRequest = true,
  bool enabled = true,
  String? status,
  String? note,
}) => {
  'data': {
    'channel': {
      'id': '1000',
      'self': {
        'id': '2000',
        'canRequestUnban': canRequest,
        'lastUnbanRequest': status == null
            ? null
            : {
                'id': 'req-1',
                'status': status,
                'createdAt': '2026-11-02T18:30:00Z',
                'resolverMessage': note,
              },
      },
      'unbanRequestsSettings': {'cooldownMinutes': 300, 'isEnabled': enabled},
    },
  },
};
