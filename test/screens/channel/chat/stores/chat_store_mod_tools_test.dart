import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

import '../../../../helpers/chat_store_harness.dart';

class _MockUserStore extends Mock implements UserStore {}

class _MockModApi extends Mock implements TwitchModApi {}

const _shoutout = ShoutoutNotice(
  id: 's-1',
  targetId: '33',
  targetLogin: 'kai',
  targetName: 'Kai',
);

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

  Iterable<IRCMessage> lines(ChatStore store) => [
    ...store.messages,
    ...store.messageBuffer,
  ];

  UserStore owner() {
    final user = _MockUserStore();
    when(
      () => user.details,
    ).thenReturn(const UserTwitch('12345', 'channel', 'Channel', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList.of([]));
    return user;
  }

  void finish(ChatStore store, FakeAsync async) {
    store.dispose();
    async.elapse(const Duration(seconds: 30));
  }

  test('a shoutout is said once, and opens the shoutout card', () {
    fakeAsync((async) {
      final store = createTestChatStore(settings: settings, sockets: sockets);
      final opened = <ShoutoutNotice>[];
      store.shoutoutRequests.listen(opened.add);
      store.addShoutout(_shoutout);
      store.addShoutout(_shoutout);
      async.flushMicrotasks();
      final notices = lines(
        store,
      ).where((m) => m.message == 'Shoutout to Kai! Check out their channel.');
      expect(notices, hasLength(1));
      expect(notices.single.actionLabel, 'View');
      notices.single.actionCallback!();
      async.flushMicrotasks();
      expect(opened.map((notice) => notice.targetLogin), ['kai']);
      finish(store, async);
    });
  });

  test('/mods lists the moderators with a link to the list', () {
    fakeAsync((async) {
      final api = MockTwitchApi();
      final mod = _MockModApi();
      when(() => api.moderation).thenReturn(mod);
      when(() => api.getTokenScopes()).thenAnswer((_) async => {});
      when(
        () => mod.getRoleUsers(
          broadcasterId: '12345',
          role: ChannelRole.moderator,
        ),
      ).thenAnswer(
        (_) async => const [
          ChannelRoleUser(userId: '1', userLogin: 'mira', userName: 'Mira'),
        ],
      );
      final store = createTestChatStore(
        settings: settings,
        sockets: sockets,
        api: api,
        user: owner(),
      );
      final requested = <ModToolsView>[];
      store.modToolsRequests.listen(requested.add);
      async.flushMicrotasks();
      store.sendMessage('/mods');
      async.flushMicrotasks();
      final line = lines(
        store,
      ).singleWhere((m) => m.message == 'Moderator (1): Mira');
      expect(line.actionLabel, 'View list');
      line.actionCallback!();
      async.flushMicrotasks();
      expect(requested, [ModToolsView.moderators]);
      finish(store, async);
    });
  });

  test('the owner\'s chat starts the mod tools; a viewer\'s does not', () {
    fakeAsync((async) {
      final api = MockTwitchApi();
      when(() => api.getTokenScopes()).thenAnswer((_) async => {});
      final store = createTestChatStore(
        settings: settings,
        sockets: sockets,
        api: api,
        user: owner(),
      );
      async.flushMicrotasks();
      expect(store.modTools.moderatorId, '12345');
      expect(store.shieldModeActive, isFalse);
      store.modTools.noteShieldMode(true);
      expect(store.shieldModeActive, isTrue);
      finish(store, async);

      final viewer = createTestChatStore(settings: settings, sockets: sockets);
      async.flushMicrotasks();
      expect(viewer.modTools.moderatorId, isNull);
      viewer.modTools.noteShieldMode(true);
      expect(viewer.shieldModeActive, isFalse);
      finish(viewer, async);
    });
  });

  test('a CLEARCHAT marks the user for the moderators\' card', () {
    fakeAsync((async) {
      final api = MockTwitchApi();
      when(() => api.getTokenScopes()).thenAnswer((_) async => {});
      final store = createTestChatStore(
        settings: settings,
        sockets: sockets,
        api: api,
        user: owner(),
      );
      settings.showModerationNotices = false;
      async.flushMicrotasks();
      sockets.single.receive(':tmi.twitch.tv 001 justinfan :Welcome, GLHF!');
      sockets.single.receive(
        '@ban-duration=600;room-id=12345;target-user-id=33 '
        ':tmi.twitch.tv CLEARCHAT #channel :ana',
      );
      async.elapse(const Duration(milliseconds: 500));
      expect(store.modTools.statusOf('33').timeoutUntil, isNotNull);
      expect(settings.showModerationNotices, isFalse);
      finish(store, async);
    });
  });
}
