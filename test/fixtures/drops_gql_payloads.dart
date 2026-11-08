const anonymousDropCampaignsResponse = {
  'data': {
    'user': {
      'id': '1',
      'channel': {
        'viewerDropCampaigns': [
          {
            '__typename': 'DropCampaign',
            'id': 'campaign-1',
            'name': 'Finals Chat Badge',
            'game': {
              'id': '2',
              'name': 'Some Game',
              'boxArtURL':
                  'https://static-cdn.jtvnw.net/ttv-boxart/2-285x380.jpg',
            },
            'owner': {'name': 'Some Publisher'},
            'imageURL': 'https://static-cdn.jtvnw.net/campaign.png',
            'accountLinkURL': 'https://www.twitch.tv/',
            'detailsURL': 'https://help.twitch.tv/details',
            'startAt': '2026-10-14T19:00:00Z',
            'endAt': '2026-11-15T18:59:59.999Z',
            'status': 'ACTIVE',
            'summary': {'isPermanentlyDismissible': false},
            'timeBasedDrops': [
              {
                '__typename': 'TimeBasedDrop',
                'id': 'drop-1',
                'name': 'Finals Supporter',
                'requiredMinutesWatched': 0,
                'requiredSubs': 1,
                'requiredTurboSubs': 0,
                'startAt': '2026-10-14T19:00:00Z',
                'endAt': '2026-11-15T18:59:59.999Z',
                'preconditionDrops': null,
                'benefitEdges': [
                  {
                    '__typename': 'DropBenefitEdge',
                    'benefit': {
                      'id': 'benefit-1',
                      'game': {'name': 'Some Game'},
                      'imageAssetURL':
                          'https://static-cdn.jtvnw.net/reward.png',
                      'name': 'Finals Supporter',
                      'entitlementLimit': 1,
                      'distributionType': 'BADGE',
                    },
                    'entitlementLimit': 1,
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  },
};

const anonymousDropCampaignsSelfError = {
  'errors': [
    {
      'message': 'graphql: got nil for non-null "TimeBasedDropSelfEdge"',
      'path': ['user', 'channel', 'viewerDropCampaigns', 0, 'timeBasedDrops'],
    },
  ],
  'data': {
    'user': {
      'id': '1',
      'channel': {'viewerDropCampaigns': null},
    },
  },
};

const noDropCampaignsResponse = {
  'data': {
    'user': {
      'id': '1',
      'channel': {'viewerDropCampaigns': null},
    },
  },
};

Map<String, Object?> _timedDrop({
  required String id,
  required String name,
  int minutes = 0,
  int subs = 0,
  int turbo = 0,
  Map<String, Object?>? self,
}) => {
  '__typename': 'TimeBasedDrop',
  'id': id,
  'name': name,
  'requiredMinutesWatched': minutes,
  'requiredSubs': subs,
  'requiredTurboSubs': turbo,
  'startAt': '2026-10-14T19:00:00Z',
  'endAt': '2026-11-15T18:59:59.999Z',
  'preconditionDrops': null,
  'benefitEdges': [
    {
      '__typename': 'DropBenefitEdge',
      'benefit': {
        'id': 'benefit-$id',
        'game': {'name': 'Some Game'},
        'imageAssetURL': 'https://static-cdn.jtvnw.net/$id.png',
        'name': '$name reward',
        'entitlementLimit': 1,
        'distributionType': 'DIRECT_ENTITLEMENT',
      },
      'entitlementLimit': 1,
    },
  ],
  'self': self,
};

Map<String, Object?> signedInDropCampaignsResponse({
  bool connected = true,
  List<Map<String, Object?>>? drops,
}) => {
  'data': {
    'user': {
      'id': '1',
      'channel': {
        'viewerDropCampaigns': [
          {
            '__typename': 'DropCampaign',
            'id': 'campaign-2',
            'name': 'Season Rewards',
            'game': {
              'id': '2',
              'name': 'Some Game',
              'boxArtURL':
                  'https://static-cdn.jtvnw.net/ttv-boxart/2-285x380.jpg',
            },
            'owner': {'name': 'Some Publisher'},
            'imageURL': 'https://static-cdn.jtvnw.net/campaign2.png',
            'accountLinkURL': 'https://example.com/link',
            'detailsURL': 'https://example.com/details',
            'startAt': '2026-10-14T19:00:00Z',
            'endAt': '2026-11-15T18:59:59.999Z',
            'status': 'ACTIVE',
            'self': {'isAccountConnected': connected},
            'summary': {'isPermanentlyDismissible': true},
            'timeBasedDrops':
                drops ??
                [
                  _timedDrop(
                    id: 'drop-a',
                    name: 'Banner',
                    minutes: 60,
                    self: {
                      'currentMinutesWatched': 60,
                      'currentSubs': 0,
                      'currentTurboSubs': 0,
                      'hasPreconditionsMet': true,
                      'isClaimed': false,
                      'dropInstanceID': 'instance-a',
                    },
                  ),
                  _timedDrop(
                    id: 'drop-b',
                    name: 'Spray',
                    minutes: 120,
                    self: {
                      'currentMinutesWatched': 30,
                      'currentSubs': 0,
                      'currentTurboSubs': 0,
                      'hasPreconditionsMet': true,
                      'isClaimed': false,
                      'dropInstanceID': null,
                    },
                  ),
                  _timedDrop(
                    id: 'drop-c',
                    name: 'Skin',
                    minutes: 30,
                    self: {
                      'currentMinutesWatched': 30,
                      'currentSubs': 0,
                      'currentTurboSubs': 0,
                      'hasPreconditionsMet': true,
                      'isClaimed': true,
                      'dropInstanceID': null,
                    },
                  ),
                ],
          },
        ],
      },
    },
  },
};

Map<String, Object?> timedDropFixture({
  required String id,
  int minutes = 0,
  int subs = 0,
  int turbo = 0,
}) => _timedDrop(id: id, name: id, minutes: minutes, subs: subs, turbo: turbo);

Map<String, Object?> claimDropResponse({
  String status = 'ELIGIBLE_FOR_ALL',
  bool connected = true,
}) => {
  'data': {
    'claimDropRewards': {
      'dropInstanceID': 'instance-a',
      'status': status,
      'dropType': {
        'id': 'drop-a',
        'campaign': {'id': 'campaign-2'},
      },
      'isUserAccountConnected': connected,
    },
  },
};
