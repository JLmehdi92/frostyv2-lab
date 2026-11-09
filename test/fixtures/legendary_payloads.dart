const noLegendarySeasonResponse = {
  'data': {'legendaryEmoteSeason': null},
};

Map<String, Object?> legendarySeasonResponse({int unopened = 2}) => {
  'data': {
    'legendaryEmoteSeason': {
      'id': 'season-1',
      'campaign': {
        'id': 'c1',
        'name': 'Winter Chests',
        'imageURL': 'https://static-cdn.jtvnw.net/campaign.png',
      },
      'emotePool': [
        {
          'tier': 'COMMON',
          'isOwned': true,
          'emote': {'id': 'e1', 'token': 'chestOne'},
        },
        {
          'tier': 'LEGENDARY',
          'isOwned': false,
          'emote': {'id': 'e2', 'token': 'chestTwo'},
        },
        {
          'tier': 'RARE',
          'isOwned': true,
          'emote': {'id': 'e3', 'token': 'chestThree'},
        },
        {
          'tier': 'RARE',
          'isOwned': false,
          'emote': {'id': 'bad id', 'token': 'chestBad'},
        },
      ],
      'userProgress': {
        'chestInventory': [
          {'chestType': 'HYPE', 'unopenedCount': unopened},
          {'chestType': 'OTHER', 'unopenedCount': 1},
        ],
      },
    },
  },
};
