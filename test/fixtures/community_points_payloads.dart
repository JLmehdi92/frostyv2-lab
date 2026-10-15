// Shapes of the OnsetCommunityPoints GQL reply, modelled on a live channel.
// Ids, names and URLs are placeholders.

const pointsContextFull = {
  'data': {
    'channel': {
      'id': '42',
      'self': {
        'communityPoints': {
          'balance': 12345,
          'availableClaim': {'id': 'claim-1'},
        },
      },
      'communityPointsSettings': {
        'name': 'Tomcoins',
        'image': {'url': 'https://static-cdn.example/points/icon-1.png'},
        'automaticRewards': [
          {
            'id': 'auto-highlight',
            'type': 'SEND_HIGHLIGHTED_MESSAGE',
            'cost': 300,
            'isEnabled': true,
            'defaultImage': {'url': 'https://static-cdn.example/hl.png'},
          },
          {
            // A power-up, bought with bits: no points cost.
            'id': 'auto-gigantify',
            'type': 'GIGANTIFY_AN_EMOTE',
            'cost': null,
            'isEnabled': true,
            'defaultImage': null,
          },
          {
            'id': 'auto-disabled',
            'type': 'RANDOM_SUB_EMOTE_UNLOCK',
            'cost': 50,
            'isEnabled': false,
            'defaultImage': null,
          },
        ],
        'customRewards': [
          {
            'id': 'custom-big',
            'title': 'Pick the next game',
            'cost': 10000,
            'isEnabled': true,
            'isUserInputRequired': true,
            'backgroundColor': '#1F69FF',
            'image': {'url': 'https://static-cdn.example/game.png'},
          },
          {
            'id': 'custom-small',
            'title': 'Hydrate',
            'cost': 80,
            'isEnabled': true,
            'isUserInputRequired': false,
            'backgroundColor': null,
            'image': null,
          },
          {
            'id': 'custom-off',
            'title': 'Paused reward',
            'cost': 10,
            'isEnabled': false,
            'isUserInputRequired': false,
            'backgroundColor': null,
            'image': null,
          },
        ],
      },
      'activePredictionEvents': [
        {
          'id': 'pred-1',
          'title': 'Will he win?',
          'status': 'ACTIVE',
          'outcomes': [
            {
              'id': 'o-yes',
              'title': 'Yes',
              'color': 'BLUE',
              'totalPoints': 3000,
              'totalUsers': 12,
            },
            {
              'id': 'o-no',
              'title': 'No',
              'color': 'PINK',
              'totalPoints': 1000,
              'totalUsers': 4,
            },
          ],
        },
      ],
    },
  },
};

/// Signed out: Twitch answers `self: null` rather than an error.
const pointsContextSignedOut = {
  'data': {
    'channel': {
      'id': '42',
      'self': null,
      'communityPointsSettings': {
        'name': null,
        'image': null,
        'automaticRewards': [],
        'customRewards': [],
      },
      'activePredictionEvents': [],
    },
  },
};

/// An unknown login.
const pointsContextNoChannel = {
  'data': {'channel': null},
};
