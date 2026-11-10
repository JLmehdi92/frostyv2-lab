import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/third_party_events.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_store_harness.dart';

const _welcome = ':tmi.twitch.tv 001 justinfan :Welcome, GLHF!';

const _privmsg =
    '@id=m1;display-name=Fan;user-id=5;room-id=12345;'
    'tmi-sent-ts=1700000000000 :fan!fan@fan.tmi.twitch.tv PRIVMSG #channel '
    ':hello';

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

String _sevenTv(String type, Map<String, dynamic> body) => jsonEncode({
  'op': 0,
  'd': {'type': type, 'body': body},
});

String _bttv(String name, Map<String, dynamic> data) =>
    jsonEncode({'name': name, 'data': data});

const _bttvEmote = Emote(
  name: 'catJAM',
  zeroWidth: false,
  url: 'https://cdn.betterttv.net/emote/e1/3x',
  type: EmoteType.bttvChannel,
  providerId: 'e1',
);

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;

  setUpAll(() {
    registerFallbackValue(_bttvEmote);
    registerFallbackValue(const SevenTvEmoteSetChange(setId: 'x'));
    registerFallbackValue(const SevenTvCosmeticCreated(id: 'x'));
    registerFallbackValue(
      const SevenTvEntitlement(
        kind: SevenTvEntitlementKind.badge,
        refId: 'x',
        twitchUserId: 'x',
        granted: true,
      ),
    );
    registerFallbackValue(const BttvProUser('x', pro: false));
  });

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showRecentMessages = false
      ..autoSyncChatDelay = false
      ..chatDelay = 0;
  });

  Iterable<String> notices(ChatStore store) => [
    for (final line in [...store.messages, ...store.messageBuffer])
      if (line.command == Command.notice &&
          (line.message ?? '').contains('emote'))
        line.message!,
  ];

  ChatStore open(FakeAsync async) {
    final store = createTestChatStore(settings: settings, sockets: sockets);
    final assets = store.assetsStore;
    when(() => assets.sevenTvEmoteSetId).thenReturn('set1');
    when(() => assets.sevenTvUserId).thenReturn('7u');
    when(() => assets.bttvChannelId).thenReturn('12345');
    when(() => assets.switchSevenTvSet(any())).thenAnswer((_) async => true);
    when(
      () => assets.renameChannelEmote(
        where: any(named: 'where'),
        to: any(named: 'to'),
      ),
    ).thenReturn(_bttvEmote);
    when(() => assets.removeChannelEmoteWhere(any())).thenReturn(_bttvEmote);
    when(() => assets.applySevenTvEntitlement(any())).thenAnswer((_) async {});
    async.flushMicrotasks();
    sockets.first.receive(_welcome);
    async.flushMicrotasks();
    return store;
  }

  FakeSocket socketFor(String host) =>
      sockets.lastWhere((socket) => socket.uri.host == host);

  List<Map<String, dynamic>> subscriptions(FakeSocket socket) => [
    for (final frame in socket.sent)
      (jsonDecode(frame as String) as Map).cast<String, dynamic>(),
  ];

  void finish(ChatStore store, FakeAsync async) {
    store.dispose();
    async.elapse(const Duration(seconds: 30));
  }

  test('the 7TV socket follows the set, the channel user and cosmetics', () {
    fakeAsync((async) {
      final store = open(async);
      final sent = subscriptions(socketFor('events.7tv.io'));

      expect(sent.map((frame) => frame['d']['type']), [
        'emote_set.update',
        'user.update',
        'cosmetic.create',
        'entitlement.create',
        'entitlement.delete',
      ]);
      expect(sent[1]['d']['condition'], {'object_id': '7u'});
      expect(sent[2]['d']['condition'], {
        'ctx': 'channel',
        'platform': 'TWITCH',
        'id': '12345',
      });
      finish(store, async);
    });
  });

  test('without 7TV cosmetics, only emotes are followed', () {
    settings
      ..show7TVBadges = false
      ..show7TVPaints = false
      ..show7TVPersonalEmotes = false;
    fakeAsync((async) {
      final store = open(async);
      expect(
        subscriptions(
          socketFor('events.7tv.io'),
        ).map((frame) => frame['d']['type']),
        ['emote_set.update', 'user.update'],
      );
      finish(store, async);
    });
  });

  test('7TV adds, renames and removals all reach the chat', () {
    fakeAsync((async) {
      final store = open(async);
      socketFor('events.7tv.io').receive(
        _sevenTv('emote_set.update', {
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
          ],
        }),
      );
      async.flushMicrotasks();

      final assets = store.assetsStore;
      verify(() => assets.addChannelEmote(any())).called(3);
      verify(() => assets.removeChannelEmote('OMEGALUL')).called(1);
      verify(() => assets.removeChannelEmote('oldName')).called(1);
      expect(notices(store), [
        'Editor removed the 7TV emote “OMEGALUL” from chat.',
        'Editor renamed the 7TV emote “oldName” to “newName”.',
        'Editor added the 7TV emote “catJAM” to chat.',
        'Editor added the 7TV emote “KEKW” to chat.',
      ]);
      finish(store, async);
    });
  });

  test('with emote notices off, emotes still change silently', () {
    settings.showEmoteChangeNotices = false;
    fakeAsync((async) {
      final store = open(async);
      socketFor('events.7tv.io').receive(
        _sevenTv('emote_set.update', {
          'id': 'set1',
          'pushed': [
            {'key': 'emotes', 'value': _activeEmote('a', 'catJAM')},
          ],
        }),
      );
      async.flushMicrotasks();
      verify(() => store.assetsStore.addChannelEmote(any())).called(1);
      expect(notices(store), isEmpty);
      finish(store, async);
    });
  });

  test('a change to someone’s personal set goes to their emotes', () {
    fakeAsync((async) {
      final store = open(async);
      socketFor('events.7tv.io').receive(
        _sevenTv('emote_set.update', {
          'id': 'personal',
          'pushed': [
            {'key': 'emotes', 'value': _activeEmote('a', 'mine')},
          ],
        }),
      );
      async.flushMicrotasks();
      verify(
        () => store.assetsStore.applyPersonalEmoteSetChange(any()),
      ).called(1);
      verifyNever(() => store.assetsStore.addChannelEmote(any()));
      finish(store, async);
    });
  });

  test('the channel switching its 7TV set swaps the emotes and says so', () {
    fakeAsync((async) {
      final store = open(async);
      final socket = socketFor('events.7tv.io');
      final before = socket.sent.length;
      socket.receive(
        _sevenTv('user.update', {
          'id': '7u',
          'actor': {'username': 'boss', 'display_name': 'Boss'},
          'updated': [
            {
              'key': 'connections',
              'value': [
                {
                  'key': 'emote_set',
                  'value': {'id': 'set2', 'name': 'Summer'},
                },
              ],
            },
          ],
        }),
      );
      async.flushMicrotasks();

      verify(() => store.assetsStore.switchSevenTvSet('set2')).called(1);
      expect(
        notices(store),
        contains(
          'Boss switched this channel’s 7TV emotes to the set “Summer”.',
        ),
      );
      final frame = jsonDecode(socket.sent[before] as String) as Map;
      expect(frame['d']['condition'], {'object_id': 'set2'});
      finish(store, async);
    });
  });

  test('another 7TV user’s update is ignored', () {
    fakeAsync((async) {
      final store = open(async);
      socketFor('events.7tv.io').receive(
        _sevenTv('user.update', {
          'id': 'someone-else',
          'updated': [
            {
              'key': 'connections',
              'value': [
                {
                  'key': 'emote_set',
                  'value': {'id': 'set2', 'name': 'Summer'},
                },
              ],
            },
          ],
        }),
      );
      async.flushMicrotasks();
      verifyNever(() => store.assetsStore.switchSevenTvSet(any()));
      finish(store, async);
    });
  });

  test('cosmetics and entitlements go to the assets', () {
    fakeAsync((async) {
      final store = open(async);
      final socket = socketFor('events.7tv.io');
      socket
        ..receive(
          _sevenTv('cosmetic.create', {
            'object': {
              'kind': 'PAINT',
              'data': {
                'id': 'p1',
                'function': 'LINEAR_GRADIENT',
                'stops': [
                  {'at': 0, 'color': -1},
                  {'at': 1, 'color': 255},
                ],
              },
            },
          }),
        )
        ..receive(
          _sevenTv('entitlement.create', {
            'object': {
              'kind': 'PAINT',
              'ref_id': 'p1',
              'user': {
                'connections': [
                  {'platform': 'TWITCH', 'id': '5'},
                ],
              },
            },
          }),
        )
        ..receive('not json');
      async.flushMicrotasks();

      verify(() => store.assetsStore.defineSevenTvCosmetic(any())).called(1);
      verify(() => store.assetsStore.applySevenTvEntitlement(any())).called(1);
      finish(store, async);
    });
  });

  test('each chatter is handed to the cosmetics lookup', () {
    fakeAsync((async) {
      final store = open(async);
      sockets.first.receive(_privmsg);
      async.flushMicrotasks();
      verify(() => store.assetsStore.noteChatter('5')).called(1);
      finish(store, async);
    });
  });

  test('the BTTV socket joins the channel', () {
    fakeAsync((async) {
      final store = open(async);
      final socket = socketFor('sockets.betterttv.net');
      expect(jsonDecode(socket.sent.single as String), {
        'name': 'join_channel',
        'data': {'name': 'twitch:12345'},
      });
      finish(store, async);
    });
  });

  test('BTTV adds, renames and removals reach the chat', () {
    fakeAsync((async) {
      final store = open(async);
      socketFor('sockets.betterttv.net')
        ..receive(
          _bttv('emote_create', {
            'channel': 'twitch:12345',
            'emote': {'id': 'e2', 'code': 'pepeD', 'animated': true},
          }),
        )
        ..receive(
          _bttv('emote_update', {
            'channel': 'twitch:12345',
            'emote': {'id': 'e1', 'code': 'catDance'},
          }),
        )
        ..receive(
          _bttv('emote_delete', {'channel': 'twitch:12345', 'emoteId': 'e1'}),
        )
        ..receive(
          _bttv('emote_delete', {'channel': 'twitch:999', 'emoteId': 'e1'}),
        );
      async.flushMicrotasks();

      final added = verify(
        () => store.assetsStore.addChannelEmote(captureAny()),
      ).captured;
      expect((added.single as Emote).name, 'pepeD');
      expect((added.single as Emote).providerId, 'e2');
      verify(() => store.assetsStore.removeChannelEmoteWhere(any())).called(1);
      expect(notices(store), [
        'The BTTV emote “pepeD” was added to chat.',
        'The BTTV emote “catJAM” was renamed “catDance”.',
        'The BTTV emote “catJAM” was removed from chat.',
      ]);
      finish(store, async);
    });
  });

  test('a BTTV Pro user goes to the personal emotes', () {
    fakeAsync((async) {
      final store = open(async);
      socketFor('sockets.betterttv.net').receive(
        _bttv('lookup_user', {
          'providerId': '5',
          'pro': true,
          'emotes': [
            {'id': 'p', 'code': 'mine'},
          ],
        }),
      );
      async.flushMicrotasks();
      verify(() => store.assetsStore.applyBttvProUser(any())).called(1);
      finish(store, async);
    });
  });

  test('BTTV updates wait for the chat delay like the messages', () {
    settings.chatDelay = 3;
    fakeAsync((async) {
      final store = open(async);
      async.elapse(const Duration(seconds: 4));
      store.addMessages();
      async.flushMicrotasks();
      socketFor('sockets.betterttv.net').receive(
        _bttv('emote_create', {
          'channel': 'twitch:12345',
          'emote': {'id': 'e2', 'code': 'pepeD'},
        }),
      );
      async.flushMicrotasks();
      verifyNever(() => store.assetsStore.addChannelEmote(any()));

      async.elapse(const Duration(seconds: 4));
      store.addMessages();
      verify(() => store.assetsStore.addChannelEmote(any())).called(1);
      finish(store, async);
    });
  });

  test('turning BTTV emotes off closes its socket', () {
    fakeAsync((async) {
      final store = open(async);
      final socket = socketFor('sockets.betterttv.net');
      settings.showBTTVEmotes = false;
      async.flushMicrotasks();
      expect(socket.closeCode, 1000);
      finish(store, async);
    });
  });

  test('without BTTV for this channel, no BTTV socket opens', () {
    fakeAsync((async) {
      final store = createTestChatStore(settings: settings, sockets: sockets);
      async.flushMicrotasks();
      sockets.first.receive(_welcome);
      async.flushMicrotasks();
      expect(
        sockets.where((socket) => socket.uri.host == 'sockets.betterttv.net'),
        isEmpty,
      );
      finish(store, async);
    });
  });

  test('cosmetic settings are handed to the assets, and follow changes', () {
    fakeAsync((async) {
      final store = open(async);
      settings.show7TVPaints = false;
      async.flushMicrotasks();
      verify(
        () => store.assetsStore.configureCosmetics(
          sevenTvBadges: true,
          sevenTvPaints: false,
          sevenTvPersonalEmotes: true,
          bttvPersonalEmotes: true,
          ffzRoomBadges: true,
        ),
      ).called(1);
      finish(store, async);
    });
  });
}
