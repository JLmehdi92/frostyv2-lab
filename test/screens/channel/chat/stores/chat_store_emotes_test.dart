import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList, ObservableMap;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

import '../../../../helpers/chat_store_harness.dart';

class _MockUserStore extends Mock implements UserStore {}

const _welcome = ':tmi.twitch.tv 001 justinfan :Welcome, GLHF!';

String _privmsg(String text, {String id = 'm1', String extra = ''}) =>
    '@id=$id;display-name=Fan;user-id=5;room-id=12345;$extra'
    'tmi-sent-ts=1700000000000 :fan!fan@fan.tmi.twitch.tv PRIVMSG #channel '
    ':$text';

String _userState(String sets) =>
    '@emote-sets=$sets;mod=0;subscriber=0 :tmi.twitch.tv USERSTATE #channel';

String _notice(String msgId, String tags) =>
    '@msg-id=$msgId;$tags;room-id=12345;system-msg=x;'
    'tmi-sent-ts=1700000000000 :tmi.twitch.tv USERNOTICE #channel';

const _catJam = Emote(
  name: 'catJAM',
  zeroWidth: false,
  url: 'https://cdn.example/catJAM.gif',
  type: EmoteType.sevenTVChannel,
  animated: true,
);

const _still = Emote(
  name: 'still',
  zeroWidth: false,
  url: 'https://cdn.example/still.png',
  type: EmoteType.sevenTVChannel,
);

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showRecentMessages = false
      ..autoSyncChatDelay = false
      ..chatDelay = 0;
  });

  UserStore me() {
    final user = _MockUserStore();
    when(() => user.details).thenReturn(const UserTwitch('1', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList.of([]));
    return user;
  }

  Iterable<IRCMessage> lines(ChatStore store) => [
    ...store.messages,
    ...store.messageBuffer,
  ];

  ChatStore open(FakeAsync async, {UserStore? user}) {
    final store = createTestChatStore(
      settings: settings,
      sockets: sockets,
      user: user,
    );
    when(
      () => store.assetsStore.emoteToObject,
    ).thenReturn({'catJAM': _catJam, 'still': _still});
    when(
      () => store.assetsStore.userEmotesFromHelix(
        userId: any(named: 'userId'),
        broadcasterId: any(named: 'broadcasterId'),
      ),
    ).thenAnswer((_) async => true);
    async.flushMicrotasks();
    sockets.single.receive(_welcome);
    async.flushMicrotasks();
    return store;
  }

  void finish(ChatStore store, FakeAsync async) {
    store.dispose();
    async.elapse(const Duration(seconds: 30));
  }

  group('the animated emotes callout', () {
    test('shows once, after the first animated emote', () {
      fakeAsync((async) {
        final store = open(async);
        final requests = <void>[];
        final listening = store.chatSettingsRequests.listen(requests.add);
        sockets.single.receive(_privmsg('still here', id: 'a'));
        async.flushMicrotasks();
        expect(settings.animatedEmotesCalloutShown, isFalse);

        sockets.single.receive(_privmsg('catJAM catJAM', id: 'b'));
        async.flushMicrotasks();
        final callouts = lines(store).where(
          (m) =>
              m.message ==
              'Animated emotes can be turned off in Settings › Chat.',
        );
        expect(callouts, hasLength(1));
        expect(callouts.single.actionLabel, 'Show me');
        expect(settings.animatedEmotesCalloutShown, isTrue);
        expect(
          SettingsStore.fromJson(settings.toJson()).animatedEmotesCalloutShown,
          isTrue,
        );

        callouts.single.actionCallback!();
        async.flushMicrotasks();
        expect(requests, hasLength(1));

        sockets.single.receive(_privmsg('catJAM', id: 'c'));
        async.flushMicrotasks();
        expect(
          lines(store).where((m) => m.actionLabel == 'Show me'),
          hasLength(1),
        );
        unawaited(listening.cancel());
        finish(store, async);
      });
    });

    test('never shows with animations already off', () {
      fakeAsync((async) {
        settings.animateEmotes = false;
        final store = open(async);
        sockets.single.receive(_privmsg('catJAM'));
        async.flushMicrotasks();
        expect(lines(store).where((m) => m.actionLabel != null), isEmpty);
        expect(settings.animatedEmotesCalloutShown, isFalse);
        finish(store, async);
      });
    });
  });

  group('the emote menu follows new entitlements', () {
    void verifyRefreshes(ChatStore store, int times) {
      if (times == 0) {
        verifyNever(
          () => store.assetsStore.userEmotesFromHelix(
            userId: any(named: 'userId'),
            broadcasterId: any(named: 'broadcasterId'),
          ),
        );
        return;
      }
      verify(
        () => store.assetsStore.userEmotesFromHelix(
          userId: '1',
          broadcasterId: '12345',
        ),
      ).called(times);
    }

    test('new emote sets in USERSTATE reload them, once', () {
      fakeAsync((async) {
        final store = open(async, user: me());
        sockets.single.receive(_userState('0,33'));
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 0);

        sockets.single.receive(_userState('33,0'));
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 0);

        sockets.single.receive(_userState('0,33,7001'));
        sockets.single.receive(_userState('0,33,7001,7002'));
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 1);
        finish(store, async);
      });
    });

    test('the viewer’s own sub or a gift to them reloads them', () {
      fakeAsync((async) {
        final store = open(async, user: me());
        sockets.single.receive(_notice('resub', 'user-id=1;login=me'));
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 1);

        sockets.single.receive(
          _notice('subgift', 'user-id=8;login=giver;msg-param-recipient-id=1'),
        );
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 1);

        sockets.single.receive(_notice('sub', 'user-id=9;login=other'));
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 0);
        finish(store, async);
      });
    });

    test('logged out, nothing is asked', () {
      fakeAsync((async) {
        final store = open(async);
        store.scheduleEmoteRefresh();
        async.elapse(emoteRefreshDelay * 2);
        verifyRefreshes(store, 0);
        finish(store, async);
      });
    });
  });

  group('the shared chat banner', () {
    ChatStore openShared(FakeAsync async) {
      final store = open(async);
      final assets = store.assetsStore;
      when(
        () => assets.fetchSharedChatAssets(
          channelId: any(named: 'channelId'),
          headers: any(named: 'headers'),
          onEmoteError: any(named: 'onEmoteError'),
          onBadgeError: any(named: 'onBadgeError'),
          showTwitchEmotes: any(named: 'showTwitchEmotes'),
          showTwitchBadges: any(named: 'showTwitchBadges'),
          show7TVEmotes: any(named: 'show7TVEmotes'),
          showBTTVEmotes: any(named: 'showBTTVEmotes'),
          showFFZEmotes: any(named: 'showFFZEmotes'),
          showFFZBadges: any(named: 'showFFZBadges'),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => assets.sharedChatChannelIds,
      ).thenReturn(ObservableList.of(['12345', '777']));
      when(() => assets.channelIdToUserTwitch).thenReturn(
        ObservableMap.of({
          '777': const UserTwitch('777', 'guest', 'Guest', ''),
          '12345': const UserTwitch('12345', 'channel', 'Channel', ''),
        }),
      );
      return store;
    }

    test('shows when shared chat starts, for a while, once', () {
      fakeAsync((async) {
        final store = openShared(async);
        sockets.single.receive(_privmsg('hello', id: 'a'));
        async.flushMicrotasks();
        expect(store.showSharedChatBanner, isFalse);

        sockets.single.receive(
          _privmsg('hi from there', id: 'b', extra: 'source-room-id=777;'),
        );
        async.flushMicrotasks();
        expect(store.showSharedChatBanner, isTrue);
        expect(store.sharedChatPartners.map((u) => u.login), ['guest']);

        async.elapse(sharedChatBannerDuration);
        expect(store.showSharedChatBanner, isFalse);

        sockets.single.receive(_privmsg('plain', id: 'c'));
        sockets.single.receive(
          _privmsg('again', id: 'd', extra: 'source-room-id=777;'),
        );
        async.flushMicrotasks();
        expect(store.showSharedChatBanner, isFalse);
        finish(store, async);
      });
    });

    test('can be dismissed', () {
      fakeAsync((async) {
        final store = openShared(async);
        sockets.single.receive(_privmsg('hi', extra: 'source-room-id=777;'));
        async.flushMicrotasks();
        store.dismissSharedChatBanner();
        expect(store.showSharedChatBanner, isFalse);
        finish(store, async);
      });
    });
  });
}
