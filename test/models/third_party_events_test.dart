import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/third_party_events.dart';

Map<String, dynamic> _activeEmote(String id, String name) => {
  'id': id,
  'name': name,
  'data': {
    'id': id,
    'name': name,
    'flags': 0,
    'host': {
      'url': '//cdn.7tv.app/emote/$id',
      'files': [
        {'name': '1x.webp', 'width': 32, 'height': 32, 'format': 'WEBP'},
      ],
    },
  },
};

Map<String, dynamic> _dispatch(String type, Map<String, dynamic> body) => {
  'op': 0,
  'd': {'type': type, 'body': body},
};

void main() {
  group('7TV emote set changes', () {
    test('every added, removed and renamed emote is read', () {
      final change =
          SevenTvDispatch.parse(
                _dispatch('emote_set.update', {
                  'id': 'set1',
                  'actor': {'username': 'editor', 'display_name': 'Editor'},
                  'pushed': [
                    {'key': 'emotes', 'value': _activeEmote('a', 'catJAM')},
                    {'key': 'emotes', 'value': _activeEmote('b', 'KEKW')},
                  ],
                  'pulled': [
                    {
                      'key': 'emotes',
                      'old_value': {'id': 'c', 'name': 'OMEGALUL'},
                    },
                  ],
                  'updated': [
                    {
                      'key': 'emotes',
                      'old_value': {'id': 'd', 'name': 'oldName'},
                      'value': _activeEmote('d', 'newName'),
                    },
                    {'key': 'name', 'old_value': 'Set', 'value': 'Set 2'},
                  ],
                }),
              )
              as SevenTvEmoteSetChange;

      expect(change.setId, 'set1');
      expect(change.actor!.displayName, 'Editor');
      expect(change.added.map((emote) => emote.name), ['catJAM', 'KEKW']);
      expect(change.removed, ['OMEGALUL']);
      expect(change.renamed.single.oldName, 'oldName');
      expect(change.renamed.single.emote.name, 'newName');
    });

    test('a change without an actor still reads', () {
      final change =
          SevenTvDispatch.parse(
                _dispatch('emote_set.update', {
                  'id': 'set1',
                  'pushed': [
                    {'key': 'emotes', 'value': _activeEmote('a', 'catJAM')},
                  ],
                }),
              )
              as SevenTvEmoteSetChange;
      expect(change.actor, isNull);
      expect(change.added, hasLength(1));
    });
  });

  test('a user.update that changes the connection’s set is a switch', () {
    final change =
        SevenTvDispatch.parse(
              _dispatch('user.update', {
                'id': 'u7',
                'actor': {'username': 'boss', 'display_name': 'Boss'},
                'updated': [
                  {
                    'key': 'connections',
                    'index': 0,
                    'nested': true,
                    'value': [
                      {
                        'key': 'emote_set',
                        'old_value': {'id': 'old', 'name': 'Old'},
                        'value': {'id': 'new', 'name': 'Summer'},
                      },
                    ],
                  },
                ],
              }),
            )
            as SevenTvActiveSetSwitch;
    expect(change.userId, 'u7');
    expect(change.setId, 'new');
    expect(change.setName, 'Summer');
  });

  test('a user.update about anything else is ignored', () {
    expect(
      SevenTvDispatch.parse(
        _dispatch('user.update', {
          'id': 'u7',
          'updated': [
            {'key': 'username', 'value': 'x'},
          ],
        }),
      ),
      isNull,
    );
  });

  test('cosmetic.create defines a paint or a badge', () {
    final paint =
        SevenTvDispatch.parse(
              _dispatch('cosmetic.create', {
                'object': {
                  'kind': 'PAINT',
                  'data': {
                    'id': 'p1',
                    'function': 'LINEAR_GRADIENT',
                    'stops': [
                      {'at': 0, 'color': -16776961},
                      {'at': 1, 'color': 16711935},
                    ],
                  },
                },
              }),
            )
            as SevenTvCosmeticCreated;
    expect(paint.id, 'p1');
    expect(paint.paint, isNotNull);

    final badge =
        SevenTvDispatch.parse(
              _dispatch('cosmetic.create', {
                'object': {
                  'kind': 'BADGE',
                  'data': {
                    'id': 'b1',
                    'tooltip': 'Sub',
                    'host': {
                      'url': '//cdn.7tv.app/badge/b1',
                      'files': [
                        {'name': '3x.webp', 'format': 'WEBP'},
                      ],
                    },
                  },
                },
              }),
            )
            as SevenTvCosmeticCreated;
    expect(badge.badge!.url, 'https://cdn.7tv.app/badge/b1/3x.webp');
  });

  test('entitlements name the Twitch user and the cosmetic', () {
    Map<String, dynamic> body(String kind) => {
      'object': {
        'kind': kind,
        'ref_id': 'ref',
        'user': {
          'id': '7tv-user',
          'connections': [
            {'platform': 'YOUTUBE', 'id': 'yt'},
            {'platform': 'TWITCH', 'id': '42'},
          ],
        },
      },
    };

    final granted =
        SevenTvDispatch.parse(_dispatch('entitlement.create', body('PAINT')))
            as SevenTvEntitlement;
    expect(granted.kind, SevenTvEntitlementKind.paint);
    expect(granted.twitchUserId, '42');
    expect(granted.granted, isTrue);

    final revoked =
        SevenTvDispatch.parse(
              _dispatch('entitlement.delete', body('EMOTE_SET')),
            )
            as SevenTvEntitlement;
    expect(revoked.kind, SevenTvEntitlementKind.emoteSet);
    expect(revoked.granted, isFalse);

    expect(
      SevenTvDispatch.parse(_dispatch('entitlement.create', body('AVATAR'))),
      isNull,
    );
  });

  test('malformed or non-dispatch frames are ignored', () {
    expect(SevenTvDispatch.parse('text'), isNull);
    expect(
      SevenTvDispatch.parse({
        'op': 1,
        'd': {'heartbeat_interval': 25000},
      }),
      isNull,
    );
    expect(
      SevenTvDispatch.parse(
        _dispatch('emote_set.update', {
          'id': 'set1',
          'pushed': [
            {
              'key': 'emotes',
              'value': {'id': 1, 'data': 'broken'},
            },
          ],
        }),
      ),
      isA<SevenTvEmoteSetChange>(),
    );
  });

  group('BTTV socket events', () {
    test('emote create, update and delete for this channel', () {
      final created =
          BttvSocketEvent.parse({
                'name': 'emote_create',
                'data': {
                  'channel': 'twitch:12345',
                  'emote': {'id': 'e1', 'code': 'catJAM', 'animated': true},
                },
              }, channelId: '12345')
              as BttvEmoteCreated;
      expect(created.emote.code, 'catJAM');
      expect(created.emote.animated, isTrue);

      final updated =
          BttvSocketEvent.parse({
                'name': 'emote_update',
                'data': {
                  'channel': 'twitch:12345',
                  'emote': {'id': 'e1', 'code': 'catDance'},
                },
              }, channelId: '12345')
              as BttvEmoteUpdated;
      expect((updated.id, updated.code), ('e1', 'catDance'));

      final deleted =
          BttvSocketEvent.parse({
                'name': 'emote_delete',
                'data': {'channel': 'twitch:12345', 'emoteId': 'e1'},
              }, channelId: '12345')
              as BttvEmoteDeleted;
      expect(deleted.id, 'e1');
    });

    test('another channel’s events are ignored', () {
      expect(
        BttvSocketEvent.parse({
          'name': 'emote_delete',
          'data': {'channel': 'twitch:999', 'emoteId': 'e1'},
        }, channelId: '12345'),
        isNull,
      );
    });

    test('a Pro user lookup carries their personal emotes', () {
      final user =
          BttvSocketEvent.parse({
                'name': 'lookup_user',
                'data': {
                  'providerId': '42',
                  'pro': true,
                  'emotes': [
                    {'id': 'p1', 'code': 'myEmote'},
                    {'id': 2},
                  ],
                },
              }, channelId: '12345')
              as BttvProUser;
      expect(user.providerId, '42');
      expect(user.pro, isTrue);
      expect(user.emotes.single.code, 'myEmote');
    });
  });
}
