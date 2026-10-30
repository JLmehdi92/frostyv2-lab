import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/services/notifications/mention_alerts.dart';

import '../../../../fixtures/irc_messages.dart';
import '../../../../helpers/chat_store_harness.dart';

class _MockUserStore extends Mock implements UserStore {}

const _welcome = ':tmi.twitch.tv 001 justinfan :Welcome, GLHF!';

String _live(String id, {String text = 'live line', String user = 'viewer'}) =>
    '@badge-info=;badges=;color=#00FF00;display-name=$user;emotes=;'
    'id=$id;room-id=12345;tmi-sent-ts=${DateTime.utc(2026, 10, 30, 13).millisecondsSinceEpoch};'
    'user-id=55555 '
    ':$user!$user@$user.tmi.twitch.tv PRIVMSG #channel :$text';

ChatHistoryMessage _history(
  String id, {
  String text = 'old line',
  String login = 'chatter',
  int minute = 0,
  bool deleted = false,
  String? sourceChannelId,
}) => ChatHistoryMessage(
  id: id,
  sentAt: DateTime.utc(2026, 10, 30, 12, minute),
  deleted: deleted,
  sender: ChatHistoryUser(id: '9$minute', login: login, displayName: login),
  fragments: [ChatHistoryFragment(text: text)],
  sourceChannelId: sourceChannelId,
);

void main() {
  late List<FakeSocket> sockets;
  late SettingsStore settings;
  late MockChatHistoryService service;
  late MockTwitchApi api;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    sockets = [];
    settings = SettingsStore.fromJson({})
      ..showRecentMessages = false
      ..autoSyncChatDelay = false
      ..chatDelay = 0;
    service = MockChatHistoryService();
    api = MockTwitchApi();
  });

  void answerHistory(Future<List<ChatHistoryMessage>> Function() answer) =>
      when(
        () => service.getRecentMessages(
          channelLogin: any(named: 'channelLogin'),
          channelId: any(named: 'channelId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) => answer());

  void answerRobotty(Future<List<dynamic>> Function() answer) => when(
    () => api.getRecentMessages(userLogin: any(named: 'userLogin')),
  ).thenAnswer((_) => answer());

  void verifyNoRobotty() => verifyNever(
    () => api.getRecentMessages(userLogin: any(named: 'userLogin')),
  );

  void verifyNoHistoryRequest() => verifyNever(
    () => service.getRecentMessages(
      channelLogin: any(named: 'channelLogin'),
      channelId: any(named: 'channelId'),
      authToken: any(named: 'authToken'),
    ),
  );

  ChatStore create({
    String? webToken = 'web-token',
    UserStore? user,
    MentionAlerts? mentionAlerts,
  }) => createTestChatStore(
    settings: settings,
    sockets: sockets,
    api: api,
    chatHistory: service,
    webToken: webToken,
    user: user,
    mentionAlerts: mentionAlerts,
  );

  List<String?> ids(ChatStore store) => [
    for (final m in [...store.messages, ...store.messageBuffer])
      m.tags['id'] ?? m.message,
  ];

  test('asks Twitch with the web token, for this channel', () {
    fakeAsync((async) {
      answerHistory(() async => [_history('h1')]);
      final store = create();
      async.flushMicrotasks();
      verify(
        () => service.getRecentMessages(
          channelLogin: 'channel',
          channelId: '12345',
          authToken: 'web-token',
        ),
      ).called(1);
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('nothing is asked without a web token', () {
    fakeAsync((async) {
      answerHistory(() async => [_history('h1')]);
      final store = create(webToken: null);
      async.flushMicrotasks();
      verifyNoHistoryRequest();
      verifyNoRobotty();
      expect(store.messages.where((m) => m.tags['historical'] == '1'), isEmpty);
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('IRC connects at once, never waiting for the history', () {
    fakeAsync((async) {
      // Neither source ever answers.
      settings.showRecentMessages = true;
      answerHistory(() => Completer<List<ChatHistoryMessage>>().future);
      answerRobotty(() => Completer<List<dynamic>>().future);
      final store = create();
      expect(sockets, hasLength(1));
      expect(sockets.single.uri.host, 'irc-ws.chat.twitch.tv');

      final noToken = create(webToken: null);
      expect(sockets, hasLength(2));
      store.dispose();
      noToken.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('history goes on top in one go, oldest first, live lines after', () {
    fakeAsync((async) {
      final history = Completer<List<ChatHistoryMessage>>();
      answerHistory(() => history.future);
      final store = create();
      async.flushMicrotasks();

      sockets.single
        ..receive(_welcome)
        ..receive(_live('live-1'));
      async.elapse(const Duration(milliseconds: 250));
      expect(ids(store), [
        'Connecting to chat...',
        "Welcome to Channel's chat!",
        'live-1',
      ]);

      var changes = 0;
      final stop = store.messages.observe((_) => changes++);
      history.complete([_history('h2', minute: 2), _history('h1', minute: 1)]);
      async.flushMicrotasks();
      stop();

      expect(ids(store), [
        'h1',
        'h2',
        'Connecting to chat...',
        "Welcome to Channel's chat!",
        'live-1',
      ]);
      expect(changes, 1, reason: 'one insert, not one per line');

      sockets.single.receive(_live('live-2'));
      async.elapse(const Duration(milliseconds: 250));
      expect(ids(store).last, 'live-2');
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a live line already shown is not shown again from history', () {
    fakeAsync((async) {
      final history = Completer<List<ChatHistoryMessage>>();
      answerHistory(() => history.future);
      final store = create();
      async.flushMicrotasks();
      sockets.single
        ..receive(_welcome)
        ..receive(_live('same'));
      async.elapse(const Duration(milliseconds: 250));

      history.complete([_history('h1'), _history('same', minute: 1)]);
      async.flushMicrotasks();

      expect(ids(store).where((id) => id == 'same'), hasLength(1));
      expect(ids(store).first, 'h1');
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a history line is not shown again when it arrives live', () {
    fakeAsync((async) {
      answerHistory(() async => [_history('h1'), _history('same', minute: 1)]);
      final store = create();
      async.flushMicrotasks();
      sockets.single
        ..receive(_welcome)
        ..receive(_live('same'))
        ..receive(_live('live-1'));
      async.elapse(const Duration(milliseconds: 250));

      expect(ids(store).where((id) => id == 'same'), hasLength(1));
      final same = store.messages.singleWhere((m) => m.tags['id'] == 'same');
      expect(same.tags['historical'], '1');
      expect(ids(store).last, 'live-1');
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('deleted history lines arrive deleted, for the reveal', () {
    fakeAsync((async) {
      answerHistory(() async => [_history('gone', deleted: true)]);
      final store = create();
      async.flushMicrotasks();
      final gone = store.messages.singleWhere((m) => m.tags['id'] == 'gone');
      expect(gone.command, Command.clearMessage);
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('blocked people stay out of the history', () {
    fakeAsync((async) {
      final user = _MockUserStore();
      when(
        () => user.details,
      ).thenReturn(const UserTwitch('1', 'me', 'Me', ''));
      when(() => user.blockedUsers).thenReturn(
        ObservableList.of([const UserBlockedTwitch('77', 'troll', 'Troll')]),
      );
      answerHistory(
        () async => [_history('h1'), _history('t1', login: 'troll')],
      );
      final store = create(user: user);
      async.flushMicrotasks();
      expect(ids(store), contains('h1'));
      expect(ids(store), isNot(contains('t1')));
      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  group('recent-messages fallback', () {
    final robottyLines = [
      '@historical=1;id=r1;tmi-sent-ts=1 '
          ':old!old@old.tmi.twitch.tv PRIVMSG #channel :from robotty',
      // Robotty does not always mark its lines.
      '@id=r2;tmi-sent-ts=2 :old!old@old.tmi.twitch.tv PRIVMSG #channel :two',
    ];

    test('with the setting on and no web token', () {
      fakeAsync((async) {
        settings.showRecentMessages = true;
        answerRobotty(() async => robottyLines);
        final store = create(webToken: null);
        async.flushMicrotasks();
        expect(ids(store).take(2), ['r1', 'r2']);
        expect(
          store.messages.take(2).map((m) => m.tags['historical']),
          everyElement('1'),
        );
        verifyNoHistoryRequest();
        store.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });

    test('with the setting on and an empty or failed Twitch history', () {
      fakeAsync((async) {
        settings.showRecentMessages = true;
        answerRobotty(() async => robottyLines);
        // The service turns every failure into an empty list.
        answerHistory(() async => const []);
        final store = create();
        async.flushMicrotasks();
        expect(ids(store).take(2), ['r1', 'r2']);
        store.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });

    test('a history request that throws still falls back', () {
      fakeAsync((async) {
        settings.showRecentMessages = true;
        answerRobotty(() async => robottyLines);
        answerHistory(() async => throw StateError('boom'));
        final store = create();
        async.flushMicrotasks();
        expect(ids(store).take(2), ['r1', 'r2']);
        store.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });

    test('never when Twitch gave a history', () {
      fakeAsync((async) {
        settings.showRecentMessages = true;
        answerRobotty(() async => robottyLines);
        answerHistory(() async => [_history('h1')]);
        final store = create();
        async.flushMicrotasks();
        verifyNoRobotty();
        expect(ids(store).first, 'h1');
        store.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });

    test('never with the setting off', () {
      fakeAsync((async) {
        answerRobotty(() async => robottyLines);
        answerHistory(() async => const []);
        final store = create();
        final noToken = create(webToken: null);
        async.flushMicrotasks();
        verifyNoRobotty();
        store.dispose();
        noToken.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });

    test('its lines go on top too, before live lines already shown', () {
      fakeAsync((async) {
        settings.showRecentMessages = true;
        final robotty = Completer<List<dynamic>>();
        answerRobotty(() => robotty.future);
        final store = create(webToken: null);
        async.flushMicrotasks();
        sockets.single
          ..receive(_welcome)
          ..receive(_live('live-1'))
          ..receive(_live('r2'));
        async.elapse(const Duration(milliseconds: 250));

        robotty.complete([...robottyLines, raidNotice]);
        async.flushMicrotasks();
        expect(ids(store).first, 'r1');
        expect(ids(store).where((id) => id == 'r2'), hasLength(1));
        expect(
          ids(store).indexOf('raid-1'),
          lessThan(ids(store).indexOf('live-1')),
        );
        // A raid in the history pins nothing.
        expect(store.latestIncomingRaid, isNull);
        store.dispose();
        async.elapse(const Duration(seconds: 30));
      });
    });
  });

  test('history triggers none of the live effects', () {
    fakeAsync((async) {
      final posted = <MentionNotice>[];
      final alerts = MentionAlerts(
        post: (notice) async => posted.add(notice),
        inFront: () => false,
      );
      final user = _MockUserStore();
      when(
        () => user.details,
      ).thenReturn(const UserTwitch('1', 'me', 'Me', ''));
      when(() => user.blockedUsers).thenReturn(ObservableList());
      settings
        ..mentionNotifications = true
        ..showVideo = true
        ..chatDelay = 5;
      answerHistory(
        () async => [
          _history('mention', text: 'hey @me look'),
          _history('shared', minute: 1, sourceChannelId: '999'),
          _history('gone', minute: 2, deleted: true),
        ],
      );

      final store = create(user: user, mentionAlerts: alerts);
      async.flushMicrotasks();

      // Shown at once: not held by the chat delay, which holds live lines.
      expect(ids(store).take(3), ['mention', 'shared', 'gone']);
      final mention = store.messages.first;
      expect(mention.mention, isTrue, reason: 'still highlighted');
      async.elapse(const Duration(seconds: 1));
      expect(posted, isEmpty, reason: 'no mention notice');
      expect(store.notification, isNull);
      expect(store.latestIncomingRaid, isNull);
      expect(store.latestGiftBomb, isNull);
      expect(store.restriction, isNull);
      expect(store.isInSharedChatMode, isFalse);
      expect(store.isWaitingForAck, isFalse);

      // The same mention said live does notify: the check above can fail.
      settings.chatDelay = 0;
      sockets.single
        ..receive(_welcome)
        ..receive(_live('now', text: 'hey @me now'));
      async.elapse(const Duration(milliseconds: 250));
      expect(posted, hasLength(1));

      store.dispose();
      async.elapse(const Duration(seconds: 30));
    });
  });

  test('a history that comes after the chat closed is dropped', () {
    fakeAsync((async) {
      final history = Completer<List<ChatHistoryMessage>>();
      answerHistory(() => history.future);
      final store = create();
      async.flushMicrotasks();
      store.dispose();
      history.complete([_history('h1')]);
      async.flushMicrotasks();
      expect(ids(store), isNot(contains('h1')));
      async.elapse(const Duration(seconds: 30));
    });
  });
}
