import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

Map<String, Object?> _event({
  String from = '8',
  String login = 'Friend',
  String name = 'Friend',
  String to = '7',
  String text = 'hey',
  String id = 'w1',
}) => {
  'from_user_id': from,
  'from_user_login': login,
  'from_user_name': name,
  'to_user_id': to,
  'to_user_login': 'me',
  'to_user_name': 'Me',
  'whisper_id': id,
  'whisper': {'text': text},
};

void main() {
  group('whisperFromEvent', () {
    test('reads a whisper sent to the viewer', () {
      final whisper = whisperFromEvent(_event(), me: '7')!;
      expect(whisper.fromUserId, '8');
      expect(whisper.fromLogin, 'friend');
      expect(whisper.fromName, 'Friend');
      expect(whisper.whisper.text, 'hey');
      expect(whisper.whisper.mine, isFalse);
      expect(whisper.whisper.id, 'w1');
    });

    test('skips what cannot be read or is not for the viewer', () {
      expect(whisperFromEvent(_event(to: '9'), me: '7'), isNull);
      expect(whisperFromEvent(_event(from: 'x'), me: '7'), isNull);
      expect(whisperFromEvent(_event(login: 'a b'), me: '7'), isNull);
      expect(whisperFromEvent(_event(text: ''), me: '7'), isNull);
      expect(whisperFromEvent(_event(text: 'a' * 10001), me: '7'), isNull);
      expect(whisperFromEvent({'whisper': 'x'}, me: '7'), isNull);
    });

    test('a missing display name falls back to the login', () {
      expect(whisperFromEvent(_event(name: ''), me: '7')!.fromName, 'Friend');
    });
  });

  test('whisperPreview keeps a whisper on one plain line', () {
    expect(whisperPreview('hi\nTwitch Staff: click'), 'hi Twitch Staff: click');
    expect(whisperPreview('a\u202Eevil\u202C b'), 'a evil b');
    expect(whisperPreview('  tab\there  '), 'tab here');
  });

  test('whisperPreview flattens Unicode line breaks and drops invisible '
      'characters', () {
    expect(whisperPreview('hi\u2028Staff\u2029: x'), 'hi Staff : x');
    expect(whisperPreview('a\u061Cb'), 'a b');
    expect(whisperPreview('St\u200Baf\u2060f\uFEFF'), 'Staff');
  });

  test('whisperPreview keeps the joiners that emoji and scripts need', () {
    // A family emoji is joined by U+200D; a Persian word needs U+200C.
    const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
    const persian = '\u0645\u06CC\u200C\u062E\u0648\u0627\u0647\u0645';
    expect(whisperPreview('hi $family'), 'hi $family');
    expect(whisperPreview(persian), persian);
    expect(whisperPreview('a\u200Bb\u2060c\uFEFFd'), 'abcd');
  });

  test('whisperPreview drops a joiner beside Latin letters, where it only '
      'hides a difference', () {
    expect(whisperPreview('m\u200Cod'), 'mod');
    expect(whisperPreview('adm\u200Din'), 'admin');
    expect(whisperPreview('Staff\u200D'), 'Staff');
    // Another invisible beside it does not shield it.
    expect(whisperPreview('Ivan\u2060\u200C\u043E\u0432'), 'Ivan\u043E\u0432');
    expect(whisperPreview('m\u200B\u200Cod'), 'mod');
    expect(whisperPreview('m\u200C\u200Dod'), 'mod');
    // A run of joiners goes as one.
    expect(whisperPreview('Ivan\u200C\u200C\u043E\u0432'), 'Ivan\u043E\u0432');
    expect(
      whisperPreview('Ivan\u200D\u200C\u200D\u043E\u0432'),
      'Ivan\u043E\u0432',
    );
    expect(whisperPreview('\u043E\u0432\u200D\u200Cad'), '\u043E\u0432ad');
    expect(whisperPreview('ad\u200Cm\uFEFF\u200Din'), 'admin');
    // Beside an emoji or another script it stays.
    const flag = '\u{1F3F3}\uFE0F\u200D\u{1F308}';
    expect(whisperPreview('go $flag'), 'go $flag');
  });

  group('WhisperStore', () {
    late MockTwitchApi api;
    late Observable<String?> user;
    late Observable<String?> token;
    late List<EventSubTopic> topics;
    late List<StreamController<EventSubTopicEvent>> streams;
    late int cancelled;
    late WhisperStore store;

    setUp(() {
      api = MockTwitchApi();
      user = Observable<String?>('7');
      token = Observable<String?>('t1');
      topics = [];
      streams = [];
      cancelled = 0;
      store = WhisperStore(
        twitchApi: api,
        currentUserId: () => user.value,
        credentials: () => token.value,
        listen: (topic) {
          topics.add(topic);
          final stream = StreamController<EventSubTopicEvent>.broadcast();
          streams.add(stream);
          return EventSubHandle.forTesting(
            topic,
            stream.stream,
            () => cancelled++,
          );
        },
      );
    });

    tearDown(() => store.dispose());

    test(
      'a muted conversation sends no notice and is left out of the unread count',
      () async {
        final notices = <IncomingWhisper>[];
        store.incoming.listen(notices.add);
        streams.single.add(EventSubData(_event()));
        await pumpEventQueue();

        store.toggleMute('8');
        expect(store.isMuted('8'), isTrue);
        streams.single.add(EventSubData(_event(id: 'w2')));
        await pumpEventQueue();

        expect(notices, hasLength(1));
        expect(store.threads.single.unread, 2);
        expect(store.unreadCount, 0);

        store.toggleMute('8');
        expect(store.isMuted('8'), isFalse);
        expect(store.unreadCount, 2);
      },
    );

    test(
      'an archived conversation leaves the list until a whisper brings it back',
      () async {
        streams.single.add(EventSubData(_event()));
        await pumpEventQueue();

        store.archive('8');
        expect(store.threads, isEmpty);
        expect(store.archivedThreads.single.userId, '8');
        expect(store.unreadCount, 0);

        streams.single.add(EventSubData(_event(id: 'w2')));
        await pumpEventQueue();
        expect(store.threads.single.userId, '8');
        expect(store.archivedThreads, isEmpty);

        store.archive('8');
        store.unarchive('8');
        expect(store.threads.single.userId, '8');
      },
    );

    test('hiding a conversation removes it and its whispers', () async {
      streams.single.add(EventSubData(_event()));
      await pumpEventQueue();
      store.open(userId: '8', login: 'friend', displayName: 'Friend');
      store.archive('8');

      store.hide('8');

      expect(store.threads, isEmpty);
      expect(store.archivedThreads, isEmpty);
      expect(store.openUserId, isNull);
      streams.single.add(EventSubData(_event(id: 'w2')));
      await pumpEventQueue();
      expect(store.threads.single.whispers.map((w) => w.id), ['w2']);
    });

    test('mute and archive choices are restored and reported', () async {
      final saved = <({Set<String> muted, Set<String> archived})>[];
      final restored = WhisperStore(
        twitchApi: api,
        currentUserId: () => user.value,
        listen: (topic) {
          final stream = StreamController<EventSubTopicEvent>.broadcast();
          streams.add(stream);
          return EventSubHandle.forTesting(topic, stream.stream, () {});
        },
        mutedUserIds: {'8'},
        archivedUserIds: {'9'},
        onPreferencesChanged: (muted, archived) =>
            saved.add((muted: muted, archived: archived)),
      );
      addTearDown(restored.dispose);

      expect(restored.isMuted('8'), isTrue);
      restored.archive('8');
      restored.toggleMute('8');

      expect(saved.last.muted, isEmpty);
      expect(saved.last.archived, {'9', '8'});
    });

    test('listens to the logged-in viewer\'s whispers', () async {
      expect(topics.single.type, 'user.whisper.message');
      expect(topics.single.condition, {'user_id': '7'});
      expect(store.status, WhisperStatus.connecting);

      streams.single.add(const EventSubListening(afterGap: false));
      await pumpEventQueue();
      expect(store.status, WhisperStatus.listening);

      streams.single.add(const EventSubUnavailable('reconnecting'));
      await pumpEventQueue();
      expect(store.status, WhisperStatus.interrupted);

      streams.single.add(
        const EventSubUnavailable(
          'Forbidden',
          permanent: true,
          unauthorized: true,
        ),
      );
      await pumpEventQueue();
      expect(store.status, WhisperStatus.refused);
    });

    test('a whisper starts a conversation, unread until opened', () async {
      final notices = <IncomingWhisper>[];
      store.incoming.listen(notices.add);

      streams.single
        ..add(EventSubData(_event()))
        // The same whisper twice is kept once.
        ..add(EventSubData(_event()))
        ..add(EventSubData(_event(id: 'w2', text: 'you there?')));
      await pumpEventQueue();

      final thread = store.threads.single;
      expect(thread.login, 'friend');
      expect(thread.whispers.map((w) => w.text), ['hey', 'you there?']);
      expect(store.unreadCount, 2);
      expect(notices, hasLength(2));

      store.open(userId: '8', login: 'friend', displayName: 'Friend');
      expect(store.unreadCount, 0);
      streams.single.add(EventSubData(_event(id: 'w3')));
      await pumpEventQueue();
      // Read on arrival while open.
      expect(store.unreadCount, 0);

      store.close('8');
      streams.single.add(EventSubData(_event(id: 'w4')));
      await pumpEventQueue();
      expect(store.unreadCount, 1);
    });

    test('the most recent conversation comes first', () async {
      streams.single
        ..add(EventSubData(_event(), sentAt: DateTime(2026, 2, 3)))
        ..add(
          EventSubData(
            _event(from: '9', login: 'other', id: 'w2'),
            sentAt: DateTime(2026, 2, 4),
          ),
        );
      await pumpEventQueue();
      expect(store.threads.map((t) => t.login), ['other', 'friend']);
    });

    test('sending adds the whisper once Twitch took it', () async {
      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hi'),
      ).thenAnswer((_) async {});
      final thread = store.open(
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      );

      expect(await store.send(thread, '  hi  '), isNull);
      expect(thread.whispers.single.text, 'hi');
      expect(thread.whispers.single.mine, isTrue);
      expect(store.threads.single, same(thread));
    });

    test("a refused whisper says why and isn't added", () async {
      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hi'),
      ).thenThrow(const ApiException('You need a verified phone number.', 403));
      final thread = store.open(
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      );

      expect(
        (await store.send(thread, 'hi'))?.text(L10n.english),
        'Couldn’t whisper: You need a verified phone number.',
      );
      expect(thread.whispers, isEmpty);

      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hi'),
      ).thenThrow(const UnauthorizedException('Please log in'));
      expect(
        (await store.send(thread, 'hi'))?.text(L10n.english),
        'Log in again to whisper from this app.',
      );
    });

    test('thread() gives a conversation without opening it', () async {
      final thread = store.thread(
        userId: '8',
        login: 'friend',
        displayName: 'Friend',
      );
      expect(store.openUserId, isNull);
      streams.single.add(EventSubData(_event()));
      await pumpEventQueue();
      expect(thread.unread, 1);
    });

    test('at most 50 conversations: the least recent go first', () async {
      for (var i = 0; i < WhisperStoreBase.maxThreads + 5; i++) {
        streams.single.add(
          EventSubData(
            _event(from: '${100 + i}', login: 'user$i', id: 'w$i'),
            sentAt: DateTime(2026, 2, 3).add(Duration(minutes: i)),
          ),
        );
      }
      await pumpEventQueue();

      expect(store.threads, hasLength(WhisperStoreBase.maxThreads));
      expect(store.threads.first.login, 'user54');
      expect(store.threads.map((t) => t.login), isNot(contains('user0')));
    });

    test('a conversation of another account cannot be sent to', () async {
      final old = store.open(userId: '8', login: 'friend', displayName: 'F');
      runInAction(() => user.value = '10');

      expect(
        (await store.send(old, 'hi'))?.text(L10n.english),
        'This conversation belongs to another account.',
      );
      verifyNever(
        () => api.sendWhisper(
          fromUserId: any(named: 'fromUserId'),
          toUserId: any(named: 'toUserId'),
          message: any(named: 'message'),
        ),
      );
    });

    test('logging in again as the same viewer listens anew', () async {
      streams.single
        ..add(
          const EventSubUnavailable('no', permanent: true, unauthorized: true),
        )
        ..add(EventSubData(_event()));
      await pumpEventQueue();
      expect(store.status, WhisperStatus.refused);

      runInAction(() => token.value = 't2');
      expect(topics, hasLength(2));
      // The old handle goes after the new one took the topic.
      expect(cancelled, 1);
      expect(store.status, WhisperStatus.connecting);
      // Same account: the conversations stay.
      expect(store.threads, hasLength(1));

      streams.last.add(const EventSubListening(afterGap: true));
      await pumpEventQueue();
      expect(store.status, WhisperStatus.listening);
    });

    test('a refusal not about the token is not a login problem', () async {
      streams.single.add(const EventSubUnavailable('gone', permanent: true));
      await pumpEventQueue();
      expect(store.status, WhisperStatus.unavailable);
    });

    test('a conversation opened over another hands back to it', () {
      store
        ..open(userId: '8', login: 'friend', displayName: 'Friend')
        ..open(userId: '9', login: 'other', displayName: 'Other');
      expect(store.openUserId, '9');
      store.close('9');
      expect(store.openUserId, '8');
      store.close('8');
      expect(store.openUserId, isNull);
    });

    test('/w keeps a conversation only once the whisper went', () async {
      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '9', message: 'yo'),
      ).thenThrow(const ApiException('Nope', 400));
      expect(
        (await store.sendTo(
          userId: '9',
          login: 'other',
          displayName: 'Other',
          text: 'yo',
        ))?.text(L10n.english),
        'Couldn’t whisper: Nope',
      );
      expect(store.threads, isEmpty);

      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '9', message: 'yo'),
      ).thenAnswer((_) async {});
      expect(
        await store.sendTo(
          userId: '9',
          login: 'other',
          displayName: 'Other',
          text: 'yo',
        ),
        isNull,
      );
      expect(store.threads.single.whispers.single.text, 'yo');
    });

    test('logging out stops listening and forgets the whispers', () async {
      streams.single.add(EventSubData(_event()));
      await pumpEventQueue();
      expect(store.threads, hasLength(1));

      runInAction(() => user.value = null);
      expect(cancelled, 1);
      expect(store.threads, isEmpty);
      expect(store.status, WhisperStatus.off);

      // Another account listens to its own whispers.
      runInAction(() => user.value = '10');
      expect(topics.last.condition, {'user_id': '10'});
    });
  });

  test('every reason a whisper was not sent reads in both languages', () {
    final french = lookupAppLocalizations(const Locale('fr'));
    const refused = ApiException(
      'The recipient blocks whispers.',
      400,
      null,
      ApiErrorKind.badRequest,
      'The recipient blocks whispers.',
    );
    final failures = <WhisperFailure>[
      const WhisperLoggedOut(),
      const WhisperOtherAccount(),
      const WhisperTooLong(500),
      const WhisperLogInAgain(),
      const WhisperRefused(refused),
      const WhisperUnexpected(),
    ];
    expect(
      [for (final f in failures) f.text(L10n.english)],
      [
        'Log in to whisper.',
        'This conversation belongs to another account.',
        'Whispers can be 500 characters at most.',
        'Log in again to whisper from this app.',
        'Couldn’t whisper: The recipient blocks whispers.',
        'Couldn’t whisper (unexpected error).',
      ],
    );
    expect(
      [for (final f in failures) f.text(french)],
      [
        'Connectez-vous pour chuchoter.',
        'Cette conversation appartient à un autre compte.',
        'Les chuchotements sont limités à 500\u00a0caractères.',
        'Reconnectez-vous pour chuchoter depuis cette application.',
        'Impossible de chuchoter. Requête non valide. Raison de '
            'Twitch\u00a0: «\u00a0The recipient blocks whispers.\u00a0»',
        'Impossible de chuchoter (erreur inattendue).',
      ],
    );
  });
}
