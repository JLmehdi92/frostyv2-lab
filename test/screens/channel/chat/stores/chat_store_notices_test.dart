import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';

import '../../../../helpers/chat_store_harness.dart';

class _MockUserStore extends Mock implements UserStore {}

class _MockViewerActions extends Mock implements TwitchViewerActionsService {}

const _welcome = ':tmi.twitch.tv 001 justinfan :Welcome, GLHF!';

String _notice(String id, String text) =>
    '@msg-id=$id;room-id=12345 :tmi.twitch.tv NOTICE #channel :$text';

String _gift({String id = 'g1', String count = '3'}) =>
    '@display-name=Giver;login=giver;id=$id;msg-id=subgift;'
    'msg-param-sub-plan=1000;msg-param-recipient-display-name=Lucky;'
    'msg-param-recipient-user-name=lucky;msg-param-sender-count=$count;'
    'room-id=12345;system-msg=Giver\\sgifted\\sa\\ssub!;'
    'tmi-sent-ts=1700000000000 :tmi.twitch.tv USERNOTICE #channel';

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

  UserStore me() {
    final user = _MockUserStore();
    when(() => user.details).thenReturn(const UserTwitch('1', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList.of([]));
    return user;
  }

  void finish(ChatStore store, FakeAsync async) {
    store.dispose();
    async.elapse(const Duration(seconds: 30));
  }

  group('a refused message', () {
    for (final id in [
      'msg_channel_suspended',
      'msg_invalid_reply_parent',
      'msg_banned_email_alias',
      'msg_banned_phone_number_alias',
      'msg_user_has_consequence',
      'msg_channel_has_consequence',
      'msg_unexpected_error',
    ]) {
      test('$id stops the sending state at once, the text kept', () {
        fakeAsync((async) {
          final store = createTestChatStore(
            settings: settings,
            sockets: sockets,
          );
          async.flushMicrotasks();
          sockets.single.receive(_welcome);
          async.flushMicrotasks();
          store.textController.text = 'hello';
          store.sendMessage('hello');
          expect(store.isWaitingForAck, isTrue);

          sockets.single.receive(_notice(id, 'Twitch words.'));
          async.flushMicrotasks();
          expect(store.isWaitingForAck, isFalse);
          expect(store.textController.text, 'hello');
          expect(store.notification, isNot('Twitch words.'));
          expect(store.notification, isNotEmpty);
          finish(store, async);
        });
      });
    }

    test('for a verified phone number shows why above the input', () {
      fakeAsync((async) {
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        sockets.single.receive(_welcome);
        async.flushMicrotasks();
        store.sendMessage('hello');
        sockets.single.receive(
          _notice('msg_requires_verified_phone_number', 'Verify.'),
        );
        async.flushMicrotasks();
        expect(store.restriction?.kind, ChatRestrictionKind.verifiedPhone);
        expect(store.restriction!.showsBar, isTrue);

        sockets.single.receive(_welcome);
        async.flushMicrotasks();
        expect(store.restriction, isNull);
        finish(store, async);
      });
    });
  });

  group('a warning', () {
    ChatStore warned(FakeAsync async, {String? webToken = 'webtok'}) {
      final store = createTestChatStore(
        settings: settings,
        sockets: sockets,
        webToken: webToken,
      );
      async.flushMicrotasks();
      sockets.single.receive(_welcome);
      async.flushMicrotasks();
      store.sendMessage('hello');
      sockets.single.receive(_notice('msg_warned', 'You were warned.'));
      async.flushMicrotasks();
      return store;
    }

    test('shows the acknowledge bar above the input', () {
      fakeAsync((async) {
        final store = warned(async);
        expect(store.restriction?.kind, ChatRestrictionKind.warned);
        expect(store.restriction!.showsBar, isTrue);
        expect(store.restriction!.blocksInput, isFalse);
        finish(store, async);
      });
    });

    test('acknowledged on Twitch, the bar goes', () {
      fakeAsync((async) {
        final actions = _MockViewerActions();
        when(
          () => actions.acknowledgeWarning(
            channelId: '12345',
            authToken: 'webtok',
          ),
        ).thenAnswer((_) async => ViewerActionOutcome.done);
        final store = warned(async);
        ViewerActionOutcome? outcome;
        store.acknowledgeWarning(actions).then((o) => outcome = o);
        async.flushMicrotasks();
        expect(outcome, ViewerActionOutcome.done);
        expect(store.restriction, isNull);
        finish(store, async);
      });
    });

    test('a refusal keeps the bar', () {
      fakeAsync((async) {
        final actions = _MockViewerActions();
        when(
          () => actions.acknowledgeWarning(
            channelId: any(named: 'channelId'),
            authToken: any(named: 'authToken'),
          ),
        ).thenAnswer((_) async => ViewerActionOutcome.failed);
        final store = warned(async);
        ViewerActionOutcome? outcome;
        store.acknowledgeWarning(actions).then((o) => outcome = o);
        async.flushMicrotasks();
        expect(outcome, ViewerActionOutcome.failed);
        expect(store.restriction?.kind, ChatRestrictionKind.warned);
        finish(store, async);
      });
    });

    test('without a web token nothing is sent', () {
      fakeAsync((async) {
        final actions = _MockViewerActions();
        final store = warned(async, webToken: null);
        ViewerActionOutcome? outcome;
        store.acknowledgeWarning(actions).then((o) => outcome = o);
        async.flushMicrotasks();
        expect(outcome, ViewerActionOutcome.signedOut);
        verifyZeroInteractions(actions);
        finish(store, async);
      });
    });

    test('nothing is sent when there is no warning', () {
      fakeAsync((async) {
        final actions = _MockViewerActions();
        final store = createTestChatStore(
          settings: settings,
          sockets: sockets,
          webToken: 'webtok',
        );
        async.flushMicrotasks();
        ViewerActionOutcome? outcome = ViewerActionOutcome.done;
        store.acknowledgeWarning(actions).then((o) => outcome = o);
        async.flushMicrotasks();
        expect(outcome, isNull);
        verifyZeroInteractions(actions);
        finish(store, async);
      });
    });
  });

  test('a channel suspended on joining is not called a refused send', () {
    fakeAsync((async) {
      final store = createTestChatStore(settings: settings, sockets: sockets);
      async.flushMicrotasks();
      sockets.single.receive(
        _notice('msg_channel_suspended', 'This channel has been suspended.'),
      );
      async.flushMicrotasks();
      expect(
        lines(store).map((m) => m.message),
        contains('This channel doesn’t exist or is suspended.'),
      );
      expect(store.notification, isNull);
      finish(store, async);
    });
  });

  test('“Follow to chat” goes once followers-only mode is off', () {
    fakeAsync((async) {
      final store = createTestChatStore(settings: settings, sockets: sockets);
      async.flushMicrotasks();
      sockets.single.receive(_welcome);
      sockets.single.receive(
        '@followers-only=10;room-id=12345 :tmi.twitch.tv ROOMSTATE #channel',
      );
      async.flushMicrotasks();
      store.sendMessage('hello');
      sockets.single.receive(_notice('msg_followersonly', 'Follow.'));
      async.flushMicrotasks();
      expect(store.restriction?.kind, ChatRestrictionKind.followRequired);

      sockets.single.receive(
        '@followers-only=-1;room-id=12345 :tmi.twitch.tv ROOMSTATE #channel',
      );
      async.flushMicrotasks();
      expect(store.restriction, isNull);
      finish(store, async);
    });
  });

  test('a server notice is worded in the language on screen', () {
    fakeAsync((async) {
      L10n.use(const Locale('fr'));
      addTearDown(() => L10n.use(const Locale('en')));
      final store = createTestChatStore(settings: settings, sockets: sockets);
      async.flushMicrotasks();
      sockets.single.receive(
        _notice('msg_duplicate', 'Your message was not sent.'),
      );
      sockets.single.receive(
        _notice('slow_on', 'This room is now in slow mode.'),
      );
      async.flushMicrotasks();
      final texts = lines(store).map((m) => m.message).toList();
      expect(
        texts,
        contains(
          'Impossible d’envoyer votre message. Il est identique à un message '
          'envoyé il y a moins de 30\u00a0secondes.',
        ),
      );
      expect(texts, contains('This room is now in slow mode.'));
      finish(store, async);
    });
  });

  group('a deleted message', () {
    test('of the viewer is said, with its text', () {
      fakeAsync((async) {
        final store = createTestChatStore(
          settings: settings,
          sockets: sockets,
          user: me(),
        );
        async.flushMicrotasks();
        sockets.single.receive(
          '@login=me;room-id=12345;target-msg-id=m1;tmi-sent-ts=1 '
          ':tmi.twitch.tv CLEARMSG #channel :my words',
        );
        async.flushMicrotasks();
        expect(
          lines(store).map((m) => m.message),
          contains('Your message was deleted: “my words”.'),
        );
        finish(store, async);
      });
    });

    test('of someone else, or replayed, is not', () {
      fakeAsync((async) {
        final store = createTestChatStore(
          settings: settings,
          sockets: sockets,
          user: me(),
        );
        async.flushMicrotasks();
        sockets.single.receive(
          '@login=other;room-id=12345;target-msg-id=m1;tmi-sent-ts=1 '
          ':tmi.twitch.tv CLEARMSG #channel :their words',
        );
        sockets.single.receive(
          '@historical=1;login=me;room-id=12345;target-msg-id=m2;'
          'tmi-sent-ts=1 :tmi.twitch.tv CLEARMSG #channel :old words',
        );
        async.flushMicrotasks();
        expect(
          lines(store).where(
            (m) => m.message?.startsWith('Your message was deleted') ?? false,
          ),
          isEmpty,
        );
        finish(store, async);
      });
    });
  });

  group('gift subs', () {
    test('show by default', () {
      fakeAsync((async) {
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        sockets.single.receive(_gift());
        async.flushMicrotasks();
        expect(
          lines(store).where((m) => m.command == Command.userNotice),
          hasLength(1),
        );
        finish(store, async);
      });
    });

    test('stay out of chat when the viewer hides them', () {
      fakeAsync((async) {
        settings.hideGiftSubNotices = true;
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        sockets.single.receive(_gift());
        sockets.single.receive(
          '@display-name=Fan;login=fan;id=s1;msg-id=sub;msg-param-sub-plan=1000;'
          'room-id=12345;system-msg=Fan\\ssubscribed.;tmi-sent-ts=1 '
          ':tmi.twitch.tv USERNOTICE #channel',
        );
        async.flushMicrotasks();
        final notices = lines(
          store,
        ).where((m) => m.command == Command.userNotice).toList();
        expect(notices.map((m) => m.tags['id']), ['s1']);
        finish(store, async);
      });
    });
  });

  group('commands', () {
    test('/user opens the card of the user it names', () {
      fakeAsync((async) {
        final api = MockTwitchApi();
        when(() => api.getUser(userLogin: 'friend')).thenAnswer(
          (_) async => const UserTwitch('9', 'friend', 'Friend', ''),
        );
        final store = createTestChatStore(
          settings: settings,
          sockets: sockets,
          api: api,
        );
        final opened = <ChatUserCardRequest>[];
        store.userCardRequests.listen(opened.add);
        async.flushMicrotasks();
        store.textController.text = '/user friend';
        store.sendMessage('/user friend');
        async.flushMicrotasks();
        expect(opened, [(login: 'friend', id: '9', displayName: 'Friend')]);
        expect(store.textController.text, isEmpty);
        finish(store, async);
      });
    });

    test('/user says when nobody has that name', () {
      fakeAsync((async) {
        final api = MockTwitchApi();
        when(
          () => api.getUser(userLogin: 'ghost'),
        ).thenThrow(const NotFoundException('no user'));
        final store = createTestChatStore(
          settings: settings,
          sockets: sockets,
          api: api,
        );
        async.flushMicrotasks();
        store.sendMessage('/user ghost');
        async.flushMicrotasks();
        expect(
          lines(store).map((m) => m.message),
          contains('Couldn’t open the user card: no user named ghost.'),
        );
        finish(store, async);
      });
    });

    test('/disconnect closes the connection to reconnect', () {
      fakeAsync((async) {
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        store.sendMessage('/disconnect');
        async.flushMicrotasks();
        expect(sockets.single.closeCode, 1000);
        finish(store, async);
      });
    });
  });
}
