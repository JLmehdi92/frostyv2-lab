Map<String, Object?> _user(
  String id,
  String login,
  String name,
  int? viewers,
) => {
  'id': id,
  'login': login,
  'displayName': name,
  'profileImageURL':
      'https://static-cdn.jtvnw.net/jtv_user_pictures/$login-70x70.png',
  'stream': viewers == null ? null : {'id': 's$id', 'viewersCount': viewers},
};

const costreamNoneResponse = {
  'data': {
    'user': {
      'id': '1000',
      'stream': {'id': 's1000', 'costreamDetails': null},
    },
  },
};

Map<String, Object?> costreamResponse({int count = 5}) => {
  'data': {
    'user': {
      'id': '1000',
      'stream': {
        'id': 's1000',
        'costreamDetails': {
          'role': 'GUEST',
          'costreamersCount': count,
          'totalViewersCount': 48210,
          'organizer': _user('2000', 'hostchannel', 'HostChannel', 30120),
          'topCostreamers': [
            _user('2000', 'hostchannel', 'HostChannel', 30120),
            _user('1000', 'thischannel', 'ThisChannel', 12000),
            _user('3000', 'thirdone', 'ThirdOne', 6090),
          ],
        },
      },
    },
  },
};

const guestStarNoneResponse = {
  'data': {
    'channel': {
      'owner': {
        '__typename': 'User',
        'id': '1000',
        'login': 'thischannel',
        'displayName': 'ThisChannel',
        'profileImageURL':
            'https://static-cdn.jtvnw.net/jtv_user_pictures/x-70x70.png',
        'primaryColorHex': 'FA2929',
        'self': null,
        'stream': {'id': 's1000', 'viewersCount': 39802},
      },
      'guestStarSessionCall': null,
    },
  },
};

Map<String, Object?> guestStarResponse() => {
  'data': {
    'channel': {
      'owner': {
        '__typename': 'User',
        ..._user('1000', 'thischannel', 'ThisChannel', 12000),
        'self': null,
      },
      'guestStarSessionCall': {
        'id': 'call-1',
        'guests': [
          {
            'user': {
              '__typename': 'User',
              ..._user('4000', 'guestone', 'GuestOne', null),
              'self': null,
            },
          },
          {
            'user': {
              '__typename': 'User',
              ..._user('5000', 'guesttwo', 'GuestTwo', 210),
              'self': null,
            },
          },
        ],
      },
    },
  },
};
