import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_store_harness.dart';

const _privmsg =
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=msg-1;room-id=12345;tmi-sent-ts=1;user-id=55555 '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :the answer';

const _clearmsg =
    '@login=viewer;room-id=12345;target-msg-id=msg-1;tmi-sent-ts=2 '
    ':tmi.twitch.tv CLEARMSG #channel :the answer';

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  ChatStore createStore() =>
      createTestChatStore(settings: settings, sockets: sockets);

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showVideo = true
      ..autoSyncChatDelay = false
      ..chatDelay = 3;
  });

  Iterable<IRCMessage> chatLines(ChatStore store) => [
    ...store.messages,
    ...store.messageBuffer,
  ].where((m) => m.tags['id'] == 'msg-1');

  test('held chat survives the connection dropping', () {
    fakeAsync((async) {
      final store = createStore();
      async.flushMicrotasks();
      final irc = sockets.single;

      irc.receive(_privmsg);
      async.elapse(const Duration(seconds: 1));
      unawaited(irc.drop());
      async.elapse(const Duration(seconds: 1));
      store.addMessages();
      expect(chatLines(store), isEmpty, reason: 'still held');

      async.elapse(const Duration(seconds: 2));
      store.addMessages();
      expect(chatLines(store), hasLength(1));
      expect(chatLines(store).single.message, 'the answer');

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a held deletion still deletes after the connection drops', () {
    fakeAsync((async) {
      final store = createStore();
      async.flushMicrotasks();
      final irc = sockets.single;
      irc.receive(_privmsg);
      async.elapse(const Duration(seconds: 4));
      store.addMessages();
      expect(chatLines(store).single.command, Command.privateMessage);

      irc.receive(_clearmsg);
      async.elapse(const Duration(seconds: 1));
      unawaited(irc.drop());
      async.elapse(const Duration(seconds: 3));
      store.addMessages();

      expect(chatLines(store).single.command, Command.clearMessage);

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('bypass lines leave a shared frame, held lines stay held', () {
    final split = ChatStoreBase.splitDelayedIrc(
      'PING :tmi.twitch.tv\r\n$_privmsg\r\n:tmi.twitch.tv RECONNECT\r\n',
    );

    expect(split.now, 'PING :tmi.twitch.tv\r\n:tmi.twitch.tv RECONNECT');
    expect(split.held, _privmsg);
  });

  test('a ping is answered at once while chat is held', () {
    fakeAsync((async) {
      final store = createStore();
      async.flushMicrotasks();
      final irc = sockets.single;
      irc.sent.clear();

      irc.receive('PING :tmi.twitch.tv');
      async.flushMicrotasks();

      expect(irc.sent, contains('PONG :tmi.twitch.tv'));

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });
}
