import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

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
}
