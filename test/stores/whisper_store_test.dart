import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';

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

  group('WhisperStore', () {
    late MockTwitchApi api;
    late Observable<String?> user;
    late List<EventSubTopic> topics;
    late List<StreamController<EventSubTopicEvent>> streams;
    late int cancelled;
    late WhisperStore store;

    setUp(() {
      api = MockTwitchApi();
      user = Observable<String?>('7');
      topics = [];
      streams = [];
      cancelled = 0;
      store = WhisperStore(
        twitchApi: api,
        currentUserId: () => user.value,
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
        const EventSubUnavailable('Forbidden', permanent: true),
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
        await store.send(thread, 'hi'),
        "Couldn't whisper: You need a verified phone number.",
      );
      expect(thread.whispers, isEmpty);

      when(
        () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hi'),
      ).thenThrow(const UnauthorizedException('Please log in'));
      expect(
        await store.send(thread, 'hi'),
        'Log in again to whisper from this app.',
      );
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
}
