import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/bttv_api.dart';
import 'package:onset/apis/ffz_api.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/stores/global_assets_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockBttvApi extends Mock implements BTTVApi {}

class MockFfzApi extends Mock implements FFZApi {}

class MockSevenTvApi extends Mock implements SevenTVApi {}

class MockGlobalAssetsStore extends Mock implements GlobalAssetsStore {}

Emote _emote(String name, EmoteType type, String owner) => Emote(
  name: name,
  zeroWidth: false,
  url: 'https://static-cdn.jtvnw.net/emoticons/v2/$name/default/dark/3.0',
  type: type,
  ownerId: owner,
);

void main() {
  late MockTwitchApi api;
  late ChatAssetsStore store;

  setUp(() {
    api = MockTwitchApi();
    store = ChatAssetsStore(
      twitchApi: api,
      bttvApi: MockBttvApi(),
      ffzApi: MockFfzApi(),
      sevenTVApi: MockSevenTvApi(),
      globalAssetsStore: MockGlobalAssetsStore(),
    );
  });

  test('the menu gets every usable emote, by channel', () async {
    when(() => api.getUserEmotes(userId: '7', broadcasterId: '42')).thenAnswer(
      (_) async => [
        _emote('Kappa', EmoteType.twitchGlobal, '0'),
        _emote('pogFollow', EmoteType.twitchFollower, '42'),
        _emote('subHype', EmoteType.twitchSub, '99'),
        _emote('subWow', EmoteType.twitchSub, '99'),
        _emote('Prime', EmoteType.twitchUnlocked, '0'),
      ],
    );
    when(() => api.getUsersByIds(any())).thenAnswer(
      (_) async => const [
        UserTwitch('42', 'here', 'Here', ''),
        UserTwitch('99', 'fave', 'Fave', ''),
      ],
    );

    expect(
      await store.userEmotesFromHelix(userId: '7', broadcasterId: '42'),
      isTrue,
    );

    final sections = store.userEmoteSectionToEmotes;
    expect(sections['Here']!.map((e) => e.name), ['pogFollow']);
    expect(sections['Fave']!.map((e) => e.name), ['subHype', 'subWow']);
    expect(sections['Global Emotes']!.single.name, 'Kappa');
    expect(sections['Unlocked Emotes']!.single.name, 'Prime');
    expect(store.userEmoteToObject.keys, hasLength(5));
  });

  test('a token without the scope falls back', () async {
    when(
      () => api.getUserEmotes(userId: '7', broadcasterId: '42'),
    ).thenThrow(const UnauthorizedException('missing scope'));

    expect(
      await store.userEmotesFromHelix(userId: '7', broadcasterId: '42'),
      isFalse,
    );
    expect(store.userEmoteSectionToEmotes, isEmpty);
  });

  test('a channel without a name still gets a section', () async {
    when(
      () => api.getUserEmotes(userId: '7', broadcasterId: '42'),
    ).thenAnswer((_) async => [_emote('subX', EmoteType.twitchSub, '5')]);
    when(() => api.getUsersByIds(any())).thenAnswer((_) async => const []);

    await store.userEmotesFromHelix(userId: '7', broadcasterId: '42');
    expect(store.userEmoteSectionToEmotes['Other Channels'], hasLength(1));
  });

  test('a failed name lookup keeps the emotes', () async {
    when(() => api.getUserEmotes(userId: '7', broadcasterId: '42')).thenAnswer(
      (_) async => [
        _emote('subX', EmoteType.twitchSub, '5'),
        _emote('odd', EmoteType.twitchSub, ''),
      ],
    );
    when(
      () => api.getUsersByIds(any()),
    ).thenThrow(const ServerException('down', 503));

    expect(
      await store.userEmotesFromHelix(userId: '7', broadcasterId: '42'),
      isTrue,
    );
    expect(store.userEmoteSectionToEmotes['Other Channels'], hasLength(2));
    // Only real ids were asked for.
    verify(() => api.getUsersByIds(['5'])).called(1);
  });

  test('a shared chat that ended clears its channels', () async {
    when(
      () => api.getSharedChatSession(broadcasterId: '42'),
    ).thenAnswer((_) async => null);
    store.sharedChatChannelIds.addAll(['42', '777']);
    await store.populateSharedChatParticipants(
      channelId: '42',
      onBadgeError: (_) {},
    );
    expect(store.sharedChatChannelIds, isEmpty);
  });

  test('loading the channel again keeps one copy of its emotes', () async {
    final global = MockGlobalAssetsStore();
    store = ChatAssetsStore(
      twitchApi: api,
      bttvApi: MockBttvApi(),
      ffzApi: MockFfzApi(),
      sevenTVApi: MockSevenTvApi(),
      globalAssetsStore: global,
    );
    when(
      () => global.ensureLoaded(
        showTwitchEmotes: any(named: 'showTwitchEmotes'),
        showTwitchBadges: any(named: 'showTwitchBadges'),
        show7TVEmotes: any(named: 'show7TVEmotes'),
        showBTTVEmotes: any(named: 'showBTTVEmotes'),
        showBTTVBadges: any(named: 'showBTTVBadges'),
        showFFZEmotes: any(named: 'showFFZEmotes'),
        showFFZBadges: any(named: 'showFFZBadges'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => api.getEmotesChannel(id: '42'),
    ).thenAnswer((_) async => [_emote('pogFollow', EmoteType.twitchSub, '42')]);
    when(
      () => api.getCheermotes(broadcasterId: '42'),
    ).thenAnswer((_) async => throw Exception('none'));

    for (var i = 0; i < 2; i++) {
      await store.assetsFuture(
        channelId: '42',
        headers: const {},
        onEmoteError: (Object _) => <Emote>[],
        onBadgeError: (Object _) {},
        showTwitchBadges: false,
        show7TVEmotes: false,
        showBTTVEmotes: false,
        showFFZEmotes: false,
      );
    }

    expect(
      store.userEmoteSectionToEmotes['Channel Emotes']!.map((e) => e.name),
      ['pogFollow'],
    );
  });

  test('the fallback emote sets loaded again keep one copy', () async {
    when(
      () => api.getEmotesSets(setId: 'g'),
    ).thenAnswer((_) async => [_emote('Kappa', EmoteType.twitchGlobal, '0')]);
    when(
      () => api.getEmotesSets(setId: 'u'),
    ).thenAnswer((_) async => [_emote('Prime', EmoteType.twitchUnlocked, '0')]);

    for (var i = 0; i < 2; i++) {
      await store.userEmotesFuture(
        emoteSets: const ['g', 'u'],
        headers: const {},
        onError: (Object _) => <Emote>[],
      );
    }

    final sections = store.userEmoteSectionToEmotes;
    expect(sections['Global Emotes']!.map((e) => e.name), ['Kappa']);
    expect(sections['Unlocked Emotes']!.map((e) => e.name), ['Prime']);
  });
}
