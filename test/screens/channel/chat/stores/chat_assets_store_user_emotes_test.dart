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
}
