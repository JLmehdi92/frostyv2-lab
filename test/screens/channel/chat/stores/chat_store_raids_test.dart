import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/raid_arrival.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart' show autorun;
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/irc_messages.dart';
import '../../../../helpers/chat_store_harness.dart';

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showRecentMessages = false
      ..autoSyncChatDelay = false
      ..chatDelay = 0;
  });

  ChatStore create() =>
      createTestChatStore(settings: settings, sockets: sockets);

  Iterable<IRCMessage> lines(ChatStore store) => [
    ...store.messages,
    ...store.messageBuffer,
  ];

  test('a live raid on this channel is handed to the pin', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      expect(store.latestIncomingRaid, isNull);

      sockets.single.receive(raidNotice);
      async.flushMicrotasks();
      expect(store.latestIncomingRaid!.raiderName, 'Raider');
      expect(store.latestIncomingRaid!.viewers, 15);
      // The chat notice row is still there, as before.
      expect(
        lines(store).where((m) => m.command == Command.userNotice),
        hasLength(1),
      );

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a replayed raid is not', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      sockets.single.receive(raidNotice.replaceFirst('@', '@historical=1;'));
      async.flushMicrotasks();
      expect(store.latestIncomingRaid, isNull);
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a local notice joins the chat; none after dispose', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      store.addLocalNotice('Celebration: Fireworks');
      expect(
        lines(store).where((m) => m.message == 'Celebration: Fireworks'),
        hasLength(1),
      );
      store.dispose();
      store.addLocalNotice('late');
      expect(lines(store).where((m) => m.message == 'late'), isEmpty);
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('the raid welcome shows right after joining, once', () {
    fakeAsync((async) {
      final store = create();
      async.flushMicrotasks();
      final arrival = RaidArrival(
        fromName: 'Nisqyy',
        targetName: 'Channel',
        viewers: 3,
        at: DateTime.utc(2026, 10, 28),
      );
      store.addArrivalNotice(arrival);
      expect(lines(store).where((m) => m.raidArrival != null), isEmpty);

      sockets.single.receive(':tmi.twitch.tv 001 justinfan :Welcome, GLHF!');
      async.flushMicrotasks();
      final all = lines(store).toList();
      final welcome = all.indexWhere(
        (m) => m.message?.startsWith('Welcome to') ?? false,
      );
      expect(welcome, isNot(-1));
      expect(all[welcome + 1].raidArrival, same(arrival));

      // Joined: a later one shows at once.
      store.addArrivalNotice(arrival);
      expect(lines(store).where((m) => m.raidArrival != null), hasLength(2));

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a local notice waits like chat while chat is delayed', () {
    fakeAsync((async) {
      settings
        ..showVideo = true
        ..chatDelay = 3;
      final store = create();
      async.flushMicrotasks();
      store.addLocalNotice('Celebration: Rain');
      store.addMessages();
      expect(
        lines(store).where((m) => m.message == 'Celebration: Rain'),
        isEmpty,
      );
      async.elapse(const Duration(seconds: 3));
      store.addMessages();
      expect(
        lines(store).where((m) => m.message == 'Celebration: Rain'),
        hasLength(1),
      );
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a held local notice released outside an action is still fine', () {
    fakeAsync((async) {
      settings
        ..showVideo = true
        ..chatDelay = 3;
      final store = create();
      async.flushMicrotasks();
      // Observed, as the chat list does: a write outside an action asserts.
      final observe = autorun((_) => store.messageBuffer.length);
      store.addLocalNotice('Celebration: Rain');
      // The delay drops under a second: nothing releases the held lines
      // until the next chat line, from the socket listener (not an
      // action).
      settings.chatDelay = 0.5;
      sockets.single.receive(raidNotice);
      async.flushMicrotasks();
      expect(
        lines(store).where((m) => m.message == 'Celebration: Rain'),
        hasLength(1),
      );
      observe();
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('recent messages count as history: a raid in them pins nothing', () {
    fakeAsync((async) {
      settings.showRecentMessages = true;
      final api = MockTwitchApi();
      when(
        () => api.getRecentMessages(userLogin: any(named: 'userLogin')),
      ).thenAnswer(
        (_) async => [
          raidNotice,
          ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :old',
        ],
      );
      final store = createTestChatStore(
        settings: settings,
        sockets: sockets,
        api: api,
      );
      async.flushMicrotasks();
      expect(store.latestIncomingRaid, isNull);
      final old = lines(store).where((m) => m.message == 'old');
      expect(old.single.tags['historical'], '1');
      expect(
        lines(store)
            .where((m) => m.command == Command.userNotice)
            .single
            .tags['historical'],
        '1',
      );
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('history already marked is left as it is', () {
    expect(
      ChatStoreBase.markHistorical('@historical=1;id=a :x PRIVMSG #c :hi'),
      '@historical=1;id=a :x PRIVMSG #c :hi',
    );
    expect(
      ChatStoreBase.markHistorical('@id=a;historical=1 :x PRIVMSG #c :hi'),
      '@id=a;historical=1 :x PRIVMSG #c :hi',
    );
    expect(
      ChatStoreBase.markHistorical('@id=a :x PRIVMSG #c :historical=0'),
      '@historical=1;id=a :x PRIVMSG #c :historical=0',
    );
    expect(
      ChatStoreBase.markHistorical(':x PRIVMSG #c :hi'),
      '@historical=1 :x PRIVMSG #c :hi',
    );
  });
}
