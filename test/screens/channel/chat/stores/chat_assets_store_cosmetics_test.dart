import 'package:fake_async/fake_async.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableMap;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/bttv_api.dart';
import 'package:onset/apis/ffz_api.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/models/third_party_events.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/services/seventv_cosmetics_cache.dart';
import 'package:onset/stores/global_assets_store.dart';

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockBttvApi extends Mock implements BTTVApi {}

class _MockFfzApi extends Mock implements FFZApi {}

class _MockSevenTvApi extends Mock implements SevenTVApi {}

class _MockGlobalAssetsStore extends Mock implements GlobalAssetsStore {}

const _badge = ChatBadge(
  name: 'Sub',
  url: 'https://cdn.7tv.app/badge/b/3x.webp',
  type: BadgeType.sevenTV,
);

const _paint = NamePaint(
  id: 'p1',
  kind: NamePaintKind.solid,
  color: Color(0xFFC8FF3D),
);

Emote _emote(String name, EmoteType type, {String? id}) => Emote(
  name: name,
  zeroWidth: false,
  url: 'https://cdn.example/$name.webp',
  type: type,
  providerId: id,
);

void main() {
  late _MockSevenTvApi sevenTv;
  late _MockGlobalAssetsStore global;
  late ChatAssetsStore store;

  setUp(() {
    sevenTv = _MockSevenTvApi();
    global = _MockGlobalAssetsStore();
    when(() => global.globalEmoteMap).thenReturn({});
    when(
      () => global.sevenTvCosmetics,
    ).thenReturn(SevenTvCosmeticsCache(sevenTv));
    store = ChatAssetsStore(
      twitchApi: _MockTwitchApi(),
      bttvApi: _MockBttvApi(),
      ffzApi: _MockFfzApi(),
      sevenTVApi: sevenTv,
      globalAssetsStore: global,
    );
  });

  void configure({
    bool badges = true,
    bool paints = true,
    bool personal = true,
    bool bttvPersonal = true,
    bool ffzRoom = true,
  }) => store.configureCosmetics(
    sevenTvBadges: badges,
    sevenTvPaints: paints,
    sevenTvPersonalEmotes: personal,
    bttvPersonalEmotes: bttvPersonal,
    ffzRoomBadges: ffzRoom,
  );

  test('a chatter’s 7TV badge, paint and personal emotes are looked up', () {
    when(() => sevenTv.getUsersCosmetics(['42'])).thenAnswer(
      (_) async => {
        '42': SevenTvUserCosmetics(
          badge: _badge,
          paint: _paint,
          personalSetId: 'set1',
          personalEmotes: [_emote('myPet', EmoteType.sevenTVPersonal)],
        ),
      },
    );
    final seenSets = <String>[];
    store.onPersonalEmoteSetSeen = seenSets.add;
    fakeAsync((async) {
      store.noteChatter('42');
      store.noteChatter('42');
      async.elapse(const Duration(seconds: 1));
    });

    expect(store.userTo7TVBadges['42'], [_badge]);
    expect(store.paintFor('42'), _paint);
    expect(store.personalEmotesFor('42')!.keys, ['myPet']);
    expect(seenSets, ['set1']);
    verify(() => sevenTv.getUsersCosmetics(['42'])).called(1);
  });

  test('with every 7TV cosmetic off, nothing is looked up', () {
    configure(badges: false, paints: false, personal: false);
    store.noteChatter('42');
    verifyNever(() => sevenTv.getUsersCosmetics(any()));
  });

  test('turning a cosmetic off forgets it, others stay', () {
    store.defineSevenTvCosmetic(
      const SevenTvCosmeticCreated(id: 'b', badge: _badge),
    );
    store.defineSevenTvCosmetic(
      const SevenTvCosmeticCreated(id: 'p', paint: _paint),
    );
    for (final (kind, ref) in [
      (SevenTvEntitlementKind.badge, 'b'),
      (SevenTvEntitlementKind.paint, 'p'),
    ]) {
      store.applySevenTvEntitlement(
        SevenTvEntitlement(
          kind: kind,
          refId: ref,
          twitchUserId: '42',
          granted: true,
        ),
      );
    }
    expect(store.paintFor('42'), _paint);

    configure(paints: false);

    expect(store.paintFor('42'), isNull);
    expect(store.userTo7TVBadges['42'], [_badge]);
  });

  test('a revoked entitlement takes the cosmetic away', () {
    store.defineSevenTvCosmetic(
      const SevenTvCosmeticCreated(id: 'b', badge: _badge),
    );
    SevenTvEntitlement badge({required bool granted}) => SevenTvEntitlement(
      kind: SevenTvEntitlementKind.badge,
      refId: 'b',
      twitchUserId: '42',
      granted: granted,
    );
    store.applySevenTvEntitlement(badge(granted: true));
    expect(store.userTo7TVBadges['42'], [_badge]);
    store.applySevenTvEntitlement(badge(granted: false));
    expect(store.userTo7TVBadges['42'], isNull);
  });

  test('a personal emote set entitlement loads the set', () async {
    when(
      () => sevenTv.getEmoteSet(id: 'set9', type: EmoteType.sevenTVPersonal),
    ).thenAnswer((_) async => [_emote('mine', EmoteType.sevenTVPersonal)]);

    await store.applySevenTvEntitlement(
      const SevenTvEntitlement(
        kind: SevenTvEntitlementKind.emoteSet,
        refId: 'set9',
        twitchUserId: '42',
        granted: true,
      ),
    );

    expect(store.personalEmotesFor('42')!.keys, ['mine']);
    expect(store.sevenTvPersonalSetIds, {'set9'});
  });

  test('a personal set change updates every owner', () async {
    when(
      () => sevenTv.getEmoteSet(id: 'set9', type: EmoteType.sevenTVPersonal),
    ).thenAnswer((_) async => [_emote('mine', EmoteType.sevenTVPersonal)]);
    await store.applySevenTvEntitlement(
      const SevenTvEntitlement(
        kind: SevenTvEntitlementKind.emoteSet,
        refId: 'set9',
        twitchUserId: '42',
        granted: true,
      ),
    );

    store.applyPersonalEmoteSetChange(
      const SevenTvEmoteSetChange(setId: 'set9', removed: ['mine']),
    );

    expect(store.personalEmotesFor('42'), isNull);
  });

  test('BTTV Pro personal emotes follow the toggle', () {
    store.applyBttvProUser(
      BttvProUser(
        '42',
        pro: true,
        emotes: [
          EmoteBTTV.fromJson({'id': 'x', 'code': 'proEmote'}),
        ],
      ),
    );
    final emote = store.personalEmotesFor('42')!['proEmote']!;
    expect(emote.type, EmoteType.bttvPersonal);
    expect(emote.providerId, 'x');

    configure(bttvPersonal: false);
    expect(store.personalEmotesFor('42'), isNull);

    store.applyBttvProUser(
      BttvProUser(
        '42',
        pro: true,
        emotes: [
          EmoteBTTV.fromJson({'id': 'x', 'code': 'proEmote'}),
        ],
      ),
    );
    expect(store.personalEmotesFor('42'), isNull);
  });

  test('channel emotes can be renamed, removed and swapped by set', () {
    store.addChannelEmote(_emote('catJAM', EmoteType.bttvChannel, id: 'e1'));
    store.addChannelEmote(_emote('Clap', EmoteType.sevenTVChannel));
    store.addChannelEmote(_emote('Kappa', EmoteType.twitchChannel));

    final before = store.renameChannelEmote(
      where: (emote) => emote.providerId == 'e1',
      to: (emote) => emote.renamed('catDance'),
    );
    expect(before!.name, 'catJAM');
    expect(store.channelEmoteToObject['catDance']!.realName, 'catJAM');

    store.replaceSevenTvChannelEmotes([
      _emote('NewSet', EmoteType.sevenTVChannel),
    ]);
    expect(store.channelEmoteToObject.keys, {'catDance', 'Kappa', 'NewSet'});

    final removed = store.removeChannelEmoteWhere(
      (emote) => emote.providerId == 'e1',
    );
    expect(removed!.name, 'catDance');
    expect(store.channelEmoteToObject.keys, {'Kappa', 'NewSet'});
  });

  test('switching the 7TV set replaces the channel’s 7TV emotes', () async {
    when(
      () => sevenTv.getEmoteSet(id: 'next', type: EmoteType.sevenTVChannel),
    ).thenAnswer((_) async => [_emote('Fresh', EmoteType.sevenTVChannel)]);
    store.addChannelEmote(_emote('Old', EmoteType.sevenTVChannel));

    expect(await store.switchSevenTvSet('next'), isTrue);
    expect(store.channelEmoteToObject.keys, ['Fresh']);
    expect(store.sevenTvEmoteSetId, 'next');

    when(
      () => sevenTv.getEmoteSet(id: 'gone', type: EmoteType.sevenTVChannel),
    ).thenThrow(Exception('404'));
    expect(await store.switchSevenTvSet('gone'), isFalse);
    expect(store.channelEmoteToObject.keys, ['Fresh']);
  });

  test('FFZ room badges follow their toggle', () {
    store.ffzRoomInfo = const RoomFFZ(1, null, null);
    expect(store.ffzRoomBadges, isNotNull);
    configure(ffzRoom: false);
    expect(store.ffzRoomBadges, isNull);
  });

  test('the badge map is observable for the chat lines', () {
    expect(
      store.userTo7TVBadges,
      isA<ObservableMap<String, List<ChatBadge>>>(),
    );
  });
}
