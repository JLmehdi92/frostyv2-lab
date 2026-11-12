import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_store_harness.dart';

class _FullJitter implements Random {
  @override
  double nextDouble() => 0.999;

  @override
  bool nextBool() => true;

  @override
  int nextInt(int max) => max - 1;
}

const _welcome = ':tmi.twitch.tv 001 justinfan :Welcome, GLHF!';

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showRecentMessages = false
      ..autoSyncChatDelay = false
      ..chatDelay = 0
      ..showBTTVEmotes = false;
  });

  ChatStore open(FakeAsync async, {bool sevenTv = false}) {
    settings.show7TVEmotes = sevenTv;
    final store = createTestChatStore(settings: settings, sockets: sockets);
    final assets = store.assetsStore;
    when(() => assets.sevenTvEmoteSetId).thenReturn(sevenTv ? 'set1' : null);
    when(() => assets.sevenTvUserId).thenReturn(null);
    when(() => assets.bttvChannelId).thenReturn(null);
    async.flushMicrotasks();
    sockets.first.receive(_welcome);
    async.flushMicrotasks();
    return store;
  }

  List<FakeSocket> irc() =>
      sockets.where((s) => s.uri.host == 'irc-ws.chat.twitch.tv').toList();

  List<FakeSocket> sevenTv() =>
      sockets.where((s) => s.uri.host == 'events.7tv.io').toList();

  void finish(ChatStore store, FakeAsync async) {
    store.dispose();
    async.elapse(const Duration(seconds: 30));
  }

  test('a silent chat socket is pinged, then closed and reopened once', () {
    fakeAsync((async) {
      final store = open(async);
      final first = irc().single;

      async.elapse(ChatStoreBase.ircSilenceLimit - const Duration(seconds: 1));
      expect(first.sent, isNot(contains('PING :tmi.twitch.tv')));
      async.elapse(const Duration(seconds: 2));
      expect(first.sent, contains('PING :tmi.twitch.tv'));
      expect(first.closeCode, isNull);

      async.elapse(ChatStoreBase.ircPongLimit);
      expect(first.closeCode, isNotNull);
      expect(irc(), hasLength(2));

      async.elapse(const Duration(seconds: 20));
      expect(irc(), hasLength(2), reason: 'no duplicate socket');
      finish(store, async);
    });
  });

  test('a reply to the ping keeps the chat socket open', () {
    fakeAsync((async) {
      final store = open(async);
      final first = irc().single;
      async.elapse(ChatStoreBase.ircSilenceLimit + const Duration(seconds: 1));
      first.receive(':tmi.twitch.tv PONG tmi.twitch.tv :tmi.twitch.tv');
      async.elapse(ChatStoreBase.ircPongLimit * 2);
      expect(first.closeCode, isNull);
      expect(irc(), hasLength(1));
      finish(store, async);
    });
  });

  test('a silent 7TV socket is closed and reopened', () {
    fakeAsync((async) {
      final store = open(async, sevenTv: true)
        ..thirdPartyJitter = _FullJitter();
      final first = sevenTv().single;
      async.elapse(
        ChatStoreBase.sevenTvSilenceLimit - const Duration(seconds: 1),
      );
      first.receive('{"op":2,"d":{}}');
      async.elapse(const Duration(seconds: 2));
      expect(first.closeCode, isNull, reason: 'a heartbeat re-arms it');
      async.elapse(ChatStoreBase.sevenTvSilenceLimit);
      expect(first.closeCode, 4000);
      async.elapse(const Duration(seconds: 2));
      expect(sevenTv(), hasLength(2));
      finish(store, async);
    });
  });

  test('a 7TV hello does not reset the backoff, a healthy minute does', () {
    fakeAsync((async) {
      final store = open(async, sevenTv: true)
        ..thirdPartyJitter = _FullJitter();
      for (final seconds in [1, 2, 4]) {
        sevenTv().last.receive('{"op":1,"d":{}}');
        async.flushMicrotasks();
        unawaited(sevenTv().last.drop());
        final before = sevenTv().length;
        async.elapse(Duration(milliseconds: seconds * 1000 - 50));
        expect(sevenTv(), hasLength(before), reason: 'backoff grows');
        async.elapse(const Duration(milliseconds: 100));
        expect(sevenTv(), hasLength(before + 1));
      }

      async.elapse(ChatStoreBase.thirdPartyHealthyAfter);
      sevenTv().last.receive('{"op":2,"d":{}}');
      async.flushMicrotasks();
      final before = sevenTv().length;
      unawaited(sevenTv().last.drop());
      async.elapse(const Duration(milliseconds: 1100));
      expect(sevenTv(), hasLength(before + 1));
      finish(store, async);
    });
  });

  test('chat lines wait in the background and show at once on resume', () {
    fakeAsync((async) {
      final store = open(async);
      async.elapse(const Duration(seconds: 1));
      final shown = store.messages.length;

      store.handleAppBackground();
      irc().last.receive(
        '@id=m1;display-name=Fan;user-id=5;room-id=12345;'
        'tmi-sent-ts=1700000000000 :fan!fan@fan.tmi.twitch.tv PRIVMSG '
        '#channel :hello',
      );
      async.elapse(const Duration(seconds: 2));
      expect(store.messages, hasLength(shown));
      expect(store.messageBuffer, hasLength(1));

      store.handleAppResume();
      expect(store.messages, hasLength(shown + 1));
      expect(store.messageBuffer, isEmpty);
      finish(store, async);
    });
  });
}
