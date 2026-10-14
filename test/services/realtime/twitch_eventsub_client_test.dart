import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/services/realtime/eventsub_protocol.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';

import '../../helpers/fake_realtime_socket.dart';

const _whispers = EventSubTopic('user.whisper.message', '1', {'user_id': '7'});

String _welcome(String sessionId, {int keepalive = 10}) => jsonEncode({
  'metadata': {'message_id': 'w-$sessionId', 'message_type': 'session_welcome'},
  'payload': {
    'session': {'id': sessionId, 'keepalive_timeout_seconds': keepalive},
  },
});

String _notification(String messageId, String subscriptionId, String text) =>
    jsonEncode({
      'metadata': {'message_id': messageId, 'message_type': 'notification'},
      'payload': {
        'subscription': {'id': subscriptionId, 'type': 'user.whisper.message'},
        'event': {
          'whisper': {'text': text},
        },
      },
    });

String _reconnect(String url) => jsonEncode({
  'metadata': {'message_id': 'r', 'message_type': 'session_reconnect'},
  'payload': {
    'session': {'id': 's', 'reconnect_url': url},
  },
});

String _revocation(String subscriptionId) => jsonEncode({
  'metadata': {'message_id': 'v', 'message_type': 'revocation'},
  'payload': {
    'subscription': {
      'id': subscriptionId,
      'type': 'user.whisper.message',
      'status': 'authorization_revoked',
    },
  },
});

void main() {
  late FakeRealtimeSocketFactory sockets;
  late List<String> created;
  late List<String> deleted;
  late Object? createError;

  TwitchEventSubClient build() => TwitchEventSubClient(
    connect: sockets.call,
    random: Random(1),
    create: (topic, sessionId) async {
      if (createError case final error?) throw error;
      created.add('${topic.type}@$sessionId');
      return 'sub-${created.length}';
    },
    delete: (id) async => deleted.add(id),
  );

  setUp(() {
    sockets = FakeRealtimeSocketFactory();
    created = [];
    deleted = [];
    createError = null;
  });

  String? texts(EventSubTopicEvent event) => switch (event) {
    EventSubData(:final event) => (event['whisper']! as Map)['text'] as String,
    _ => null,
  };

  test('connects on the first listener, then subscribes the session', () {
    fakeAsync((async) {
      final client = build();
      async.elapse(const Duration(minutes: 1));
      expect(sockets.sockets, isEmpty);

      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      expect(sockets.last.uri, eventSubEndpoint);
      expect(created, isEmpty);

      sockets.last.serverSend(_welcome('s1'));
      async.flushMicrotasks();
      expect(created, ['user.whisper.message@s1']);
      expect(
        events.single,
        isA<EventSubListening>().having((e) => e.afterGap, 'afterGap', false),
      );

      sockets.last
        ..serverSend(_notification('m1', 'sub-1', 'hi'))
        // Twitch may send a message twice.
        ..serverSend(_notification('m1', 'sub-1', 'hi'))
        ..serverSend(_notification('m2', 'other', 'not ours'));
      async.flushMicrotasks();
      expect(events.map(texts).nonNulls, ['hi']);
      // Nothing is ever sent on the socket.
      expect(sockets.last.sent, isEmpty);
      unawaited(client.dispose());
    });
  });

  test('a moved session keeps its subscriptions', () {
    fakeAsync((async) {
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      final first = sockets.last..serverSend(_welcome('s1'));
      async.flushMicrotasks();

      first.serverSend(_reconnect('wss://eventsub.wss.twitch.tv/ws?id=x'));
      async.flushMicrotasks();
      final moved = sockets.last;
      expect(moved, isNot(same(first)));
      expect(moved.uri.queryParameters['id'], 'x');
      // The old socket stays until the new one is welcomed.
      expect(first.isClosed, isFalse);

      moved.serverSend(_welcome('s2'));
      async.flushMicrotasks();
      expect(first.closedByClient, isTrue);
      expect(created, hasLength(1));

      moved.serverSend(_notification('m1', 'sub-1', 'still here'));
      async.flushMicrotasks();
      expect(events.map(texts).nonNulls, ['still here']);
      expect(events.whereType<EventSubUnavailable>(), isEmpty);
      unawaited(client.dispose());
    });
  });

  test('a lost socket reconnects and subscribes the new session', () {
    fakeAsync((async) {
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome('s1'));
      async.flushMicrotasks();

      sockets.last.serverClose(1006);
      async.flushMicrotasks();
      expect(events.last, isA<EventSubUnavailable>());
      async.elapse(const Duration(seconds: 2));
      expect(sockets.sockets, hasLength(2));

      sockets.last.serverSend(_welcome('s2'));
      async.flushMicrotasks();
      expect(created, ['user.whisper.message@s1', 'user.whisper.message@s2']);
      expect(
        events.last,
        isA<EventSubListening>().having((e) => e.afterGap, 'afterGap', true),
      );
      unawaited(client.dispose());
    });
  });

  test('silence past the keepalive counts as a lost socket', () {
    fakeAsync((async) {
      final client = build();
      client.listen(_whispers);
      async.flushMicrotasks();
      final first = sockets.last..serverSend(_welcome('s1'));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 16));
      expect(first.closedByClient, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(sockets.sockets, hasLength(2));
      unawaited(client.dispose());
    });
  });

  test('a refused subscription is permanent, a server error is not', () {
    fakeAsync((async) {
      createError = const ApiException('Forbidden', 403);
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome('s1'));
      async.flushMicrotasks();
      expect(
        events.single,
        isA<EventSubUnavailable>().having(
          (e) => e.permanent,
          'permanent',
          true,
        ),
      );
      unawaited(client.dispose());
    });

    fakeAsync((async) {
      createError = const ServerException('down', 503);
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome('s1'));
      async.flushMicrotasks();
      expect(
        events.single,
        isA<EventSubUnavailable>().having(
          (e) => e.permanent,
          'permanent',
          false,
        ),
      );
      unawaited(client.dispose());
    });
  });

  test('a revoked subscription says so', () {
    fakeAsync((async) {
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome('s1'));
      async.flushMicrotasks();

      sockets.last.serverSend(_revocation('sub-1'));
      async.flushMicrotasks();
      expect(
        events.last,
        isA<EventSubUnavailable>()
            .having((e) => e.reason, 'reason', 'authorization_revoked')
            .having((e) => e.permanent, 'permanent', true),
      );
      unawaited(client.dispose());
    });
  });

  test('the last listener gone: subscription deleted, socket closed', () {
    fakeAsync((async) {
      final client = build();
      final handle = client.listen(_whispers);
      async.flushMicrotasks();
      final socket = sockets.last..serverSend(_welcome('s1'));
      async.flushMicrotasks();

      handle
        ..cancel()
        ..cancel();
      async.elapse(const Duration(seconds: 1));
      expect(deleted, ['sub-1']);
      async.elapse(const Duration(seconds: 5));
      expect(socket.closedByClient, isTrue);
      unawaited(client.dispose());
    });
  });

  test('a close we caused is not retried', () {
    fakeAsync((async) {
      final client = build();
      final events = <EventSubTopicEvent>[];
      client.listen(_whispers).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverClose(4001);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      expect(sockets.sockets, hasLength(1));
      expect(
        events.last,
        isA<EventSubUnavailable>().having(
          (e) => e.permanent,
          'permanent',
          true,
        ),
      );
      unawaited(client.dispose());
    });
  });

  test('sleeps after a minute in the background, wakes on resume', () {
    fakeAsync((async) {
      final client = build();
      client.listen(_whispers);
      async.flushMicrotasks();
      final first = sockets.last..serverSend(_welcome('s1', keepalive: 600));
      async.flushMicrotasks();

      client.onAppPaused();
      async.elapse(const Duration(seconds: 61));
      expect(first.closedByClient, isTrue);
      async.elapse(const Duration(minutes: 5));
      expect(sockets.sockets, hasLength(1));

      client.onAppResumed();
      async.flushMicrotasks();
      expect(sockets.sockets, hasLength(2));
      sockets.last.serverSend(_welcome('s2'));
      async.flushMicrotasks();
      expect(created.last, 'user.whisper.message@s2');
      unawaited(client.dispose());
    });
  });
}
