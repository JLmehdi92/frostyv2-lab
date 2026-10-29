import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/realtime/hermes_protocol.dart';
import 'package:onset/services/realtime/twitch_realtime_client.dart';

import '../../fixtures/hermes_frames.dart';
import '../../helpers/fake_realtime_socket.dart';

const _topic = 'hype-train-events-v2.42';
const _other = 'hype-train-events-v2.43';

String _welcome({int keepaliveSec = 15}) =>
    '{"type":"welcome","welcome":{"keepaliveSec":$keepaliveSec,'
    '"sessionId":"s"}}';

void main() {
  late FakeRealtimeSocketFactory sockets;

  TwitchRealtimeClient build() =>
      TwitchRealtimeClient(connect: sockets.call, random: Random(7));

  setUp(() => sockets = FakeRealtimeSocketFactory());

  /// Subscribe frames sent on [socket], as `topic → subscription id`.
  Map<String, String> subscribed(FakeRealtimeSocket socket) => {
    for (final frame in socket.sent.map(jsonDecode).cast<Map>())
      if (frame['type'] == 'subscribe')
        (frame['subscribe'] as Map)['pubsub']['topic'] as String:
            (frame['subscribe'] as Map)['id'] as String,
  };

  List<String> unsubscribed(FakeRealtimeSocket socket) => [
    for (final frame in socket.sent.map(jsonDecode).cast<Map>())
      if (frame['type'] == 'unsubscribe')
        (frame['unsubscribe'] as Map)['id'] as String,
  ];

  String ok(String subscriptionId) =>
      '{"type":"subscribeResponse","subscribeResponse":{"subscription":'
      '{"id":"$subscriptionId"},"result":"ok"}}';

  String notification(String subscriptionId, String payload) => jsonEncode({
    'type': 'notification',
    'timestamp': '2026-10-13T15:50:27.500Z',
    'notification': {
      'subscription': {'id': subscriptionId},
      'type': 'pubsub',
      'pubsub': payload,
    },
  });

  test('creating the client opens nothing', () {
    fakeAsync((async) {
      final client = build();
      async.elapse(const Duration(minutes: 5));

      expect(sockets.sockets, isEmpty);
      expect(client.state, RealtimeConnectionState.idle);
      unawaited(client.dispose());
    });
  });

  test('connects only when something subscribes', () {
    fakeAsync((async) {
      final client = build();
      async.elapse(const Duration(minutes: 1));
      expect(sockets.sockets, isEmpty);

      client.subscribe(_topic);
      async.flushMicrotasks();

      expect(sockets.sockets, hasLength(1));
      expect(sockets.last.uri, hermesEndpoint);
      expect(sockets.last.uri.queryParameters['clientId'], isNotEmpty);
      unawaited(client.dispose());
    });
  });

  test('subscribes after the welcome, once per topic, on one socket', () {
    fakeAsync((async) {
      final client = build();
      client
        ..subscribe(_topic)
        ..subscribe(_topic)
        ..subscribe(_other);
      async.flushMicrotasks();
      expect(sockets.last.sent, isEmpty, reason: 'nothing before welcome');

      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();

      expect(sockets.sockets, hasLength(1));
      expect(subscribed(sockets.last).keys, unorderedEquals([_topic, _other]));
      final frame = jsonDecode(sockets.last.sent.first) as Map;
      expect((frame['subscribe'] as Map)['type'], 'pubsub');
      expect(client.state, RealtimeConnectionState.connected);
      unawaited(client.dispose());
    });
  });

  test('a topic subscribed after the welcome is sent at once', () {
    fakeAsync((async) {
      final client = build()..subscribe(_topic);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();

      client.subscribe(_other);

      expect(subscribed(sockets.last).keys, contains(_other));
      unawaited(client.dispose());
    });
  });

  test('delivers subscribe results and messages to their topic only', () {
    fakeAsync((async) {
      final client = build();
      final a = <RealtimeTopicEvent>[];
      final b = <RealtimeTopicEvent>[];
      client.subscribe(_topic).events.listen(a.add);
      client.subscribe(_other).events.listen(b.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();
      final ids = subscribed(sockets.last);

      sockets.last
        ..serverSend(ok(ids[_topic]!))
        ..serverSend(notification(ids[_topic]!, '{"type":"x"}'))
        ..serverSend(notification('unknown', '{"type":"y"}'))
        ..serverSend('garbage');
      async.flushMicrotasks();

      expect(a.first, isA<RealtimeSubscribed>());
      expect((a.first as RealtimeSubscribed).isResubscribe, isFalse);
      final message = a[1] as RealtimeMessage;
      expect(message.payload, '{"type":"x"}');
      expect(message.serverTime, DateTime.utc(2026, 10, 13, 15, 50, 27, 500));
      expect(b, isEmpty);
      unawaited(client.dispose());
    });
  });

  test('a refused topic is unavailable for good', () {
    fakeAsync((async) {
      final client = build();
      final events = <RealtimeTopicEvent>[];
      client.subscribe(_topic).events.listen(events.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();
      final id = subscribed(sockets.last)[_topic]!;

      sockets.last.serverSend(hermesSubscribeError.replaceAll('sub-2', id));
      async.flushMicrotasks();

      final unavailable = events.single as RealtimeUnavailable;
      expect(unavailable.permanent, isTrue);
      expect(unavailable.reason, 'SUB002');
      unawaited(client.dispose());
    });
  });

  test('a listener that throws does not stop the other topics', () {
    fakeAsync((async) {
      final client = build();
      final b = <RealtimeTopicEvent>[];
      final errors = <Object>[];
      runZonedGuarded(() {
        client.subscribe(_topic).events.listen((_) => throw StateError('x'));
      }, (e, _) => errors.add(e));
      client.subscribe(_other).events.listen(b.add);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();
      final ids = subscribed(sockets.last);

      sockets.last
        ..serverSend(notification(ids[_topic]!, '1'))
        ..serverSend(notification(ids[_other]!, '2'));
      async.flushMicrotasks();

      expect(errors, hasLength(1));
      expect((b.single as RealtimeMessage).payload, '2');
      unawaited(client.dispose());
    });
  });

  group('keepalive watchdog', () {
    test('silence past keepalive + 5 s reconnects', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 19));
        expect(sockets.sockets, hasLength(1));
        async.elapse(const Duration(seconds: 2));
        expect(sockets.sockets.first.closedByClient, isTrue);
        expect(client.state, RealtimeConnectionState.reconnecting);
        async.elapse(const Duration(seconds: 2));
        expect(sockets.sockets, hasLength(2));
        unawaited(client.dispose());
      });
    });

    test('regular keepalives keep the socket', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        for (var i = 0; i < 12; i++) {
          async.elapse(const Duration(seconds: 10));
          sockets.last.serverSend(hermesKeepalive);
          async.flushMicrotasks();
        }

        expect(sockets.sockets, hasLength(1));
        unawaited(client.dispose());
      });
    });

    test('the welcome keepalive sets the window', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome(keepaliveSec: 30));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 34));
        expect(sockets.last.closedByClient, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(sockets.first.closedByClient, isTrue);
        unawaited(client.dispose());
      });
    });
  });

  group('reconnect', () {
    test('backs off 1, 2, 4 s and resubscribes every topic', () {
      fakeAsync((async) {
        final client = build();
        final events = <RealtimeTopicEvent>[];
        client.subscribe(_topic).events.listen(events.add);
        client.subscribe(_other);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();

        for (final seconds in [1, 2, 4]) {
          final before = sockets.sockets.length;
          sockets.last.serverClose(1006);
          async.flushMicrotasks();
          async.elapse(Duration(milliseconds: (seconds * 790).round()));
          expect(sockets.sockets, hasLength(before), reason: '$seconds s');
          async.elapse(Duration(milliseconds: (seconds * 420).round()));
          expect(sockets.sockets, hasLength(before + 1), reason: '$seconds s');
        }

        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        final ids = subscribed(sockets.last);
        expect(ids.keys, unorderedEquals([_topic, _other]));
        sockets.last.serverSend(ok(ids[_topic]!));
        async.flushMicrotasks();
        expect(
          events.whereType<RealtimeSubscribed>().single.isResubscribe,
          isTrue,
        );
        unawaited(client.dispose());
      });
    });

    test('the backoff resets after a healthy minute', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        sockets.last.serverClose(1006);
        async.elapse(const Duration(seconds: 2));
        sockets.last.serverClose(1006);
        async.elapse(const Duration(seconds: 3));
        expect(sockets.sockets, hasLength(3));

        sockets.last.serverSend(_welcome());
        for (var i = 0; i < 7; i++) {
          async.elapse(const Duration(seconds: 10));
          sockets.last.serverSend(hermesKeepalive);
          async.flushMicrotasks();
        }
        sockets.last.serverClose(1006);
        async.elapse(Duration.zero);

        expect(sockets.sockets, hasLength(4), reason: 'immediate retry');
        unawaited(client.dispose());
      });
    });

    test('a ping failure (4100) reconnects', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        sockets.last.serverClose(4100);
        async.elapse(const Duration(seconds: 2));

        expect(sockets.sockets, hasLength(2));
        unawaited(client.dispose());
      });
    });

    test('a fatal close stops until a later subscribe', () {
      fakeAsync((async) {
        final client = build();
        final events = <RealtimeTopicEvent>[];
        client.subscribe(_topic).events.listen(events.add);
        async.flushMicrotasks();
        sockets.last.serverClose(4130);
        async.flushMicrotasks();

        expect(client.state, RealtimeConnectionState.failed);
        expect((events.single as RealtimeUnavailable).permanent, isTrue);
        async.elapse(const Duration(minutes: 10));
        expect(sockets.sockets, hasLength(1));

        client.subscribe(_other);
        async.flushMicrotasks();
        expect(sockets.sockets, hasLength(2));
        unawaited(client.dispose());
      });
    });

    test('a reconnect frame opens a new socket at once', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        sockets.last.serverSend(hermesReconnect);
        async.flushMicrotasks();

        expect(sockets.sockets, hasLength(2));
        expect(sockets.first.closedByClient, isTrue);
        expect(sockets.last.uri, hermesEndpoint);
        unawaited(client.dispose());
      });
    });
  });

  group('reference counting', () {
    test('the last cancel unsubscribes after 500 ms', () {
      fakeAsync((async) {
        final client = build();
        final first = client.subscribe(_topic);
        final second = client.subscribe(_topic);
        client.subscribe(_other);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        final id = subscribed(sockets.last)[_topic]!;

        first.cancel();
        async.elapse(const Duration(seconds: 1));
        expect(unsubscribed(sockets.last), isEmpty);

        second
          ..cancel()
          ..cancel();
        async.elapse(const Duration(milliseconds: 400));
        expect(unsubscribed(sockets.last), isEmpty);
        async.elapse(const Duration(milliseconds: 200));
        expect(unsubscribed(sockets.last), [id]);
        unawaited(client.dispose());
      });
    });

    test('subscribing again within 500 ms keeps the subscription', () {
      fakeAsync((async) {
        final client = build();
        final first = client.subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();

        first.cancel();
        async.elapse(const Duration(milliseconds: 300));
        client.subscribe(_topic);
        async.elapse(const Duration(seconds: 2));

        expect(unsubscribed(sockets.last), isEmpty);
        expect(subscribed(sockets.last), hasLength(1));
        unawaited(client.dispose());
      });
    });

    test('with no topic left the socket closes after 30 s', () {
      fakeAsync((async) {
        final client = build();
        final subscription = client.subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();

        subscription.cancel();
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(seconds: 9));
          sockets.last.serverSend(hermesKeepalive);
        }
        async.elapse(const Duration(seconds: 2));
        expect(sockets.last.closedByClient, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(sockets.last.closedByClient, isTrue);
        expect(client.state, RealtimeConnectionState.idle);

        client.subscribe(_topic);
        async.flushMicrotasks();
        expect(sockets.sockets, hasLength(2));
        unawaited(client.dispose());
      });
    });
  });

  group('app lifecycle', () {
    test('a short background keeps the socket', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());

        client.onAppPaused();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(seconds: 10));
          sockets.last.serverSend(hermesKeepalive);
        }
        async.elapse(const Duration(seconds: 9));
        client.onAppResumed();
        async.elapse(const Duration(seconds: 5));

        expect(sockets.sockets, hasLength(1));
        expect(sockets.last.closedByClient, isFalse);
        unawaited(client.dispose());
      });
    });

    test('a long background closes; resuming resubscribes', () {
      fakeAsync((async) {
        final client = build();
        final events = <RealtimeTopicEvent>[];
        client.subscribe(_topic).events.listen(events.add);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        sockets.last.serverSend(ok(subscribed(sockets.last)[_topic]!));

        client.onAppPaused();
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(seconds: 10));
          sockets.last.serverSend(hermesKeepalive);
        }
        async.elapse(const Duration(seconds: 2));
        expect(sockets.first.closedByClient, isTrue);
        expect(client.state, RealtimeConnectionState.paused);
        async.elapse(const Duration(minutes: 5));
        expect(sockets.sockets, hasLength(1), reason: 'no reconnect paused');

        client.onAppResumed();
        async.flushMicrotasks();
        expect(sockets.sockets, hasLength(2));
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        sockets.last.serverSend(ok(subscribed(sockets.last)[_topic]!));
        async.flushMicrotasks();

        expect(
          events.whereType<RealtimeSubscribed>().map((e) => e.isResubscribe),
          [false, true],
        );
        unawaited(client.dispose());
      });
    });
  });

  group('hardening', () {
    /// Fails [count] connects in a row before any welcome.
    void failConnects(FakeAsync async, int count) {
      for (var i = 0; i < count; i++) {
        sockets.last.serverClose(1006);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 40));
      }
    }

    test('a pending reconnect does not reopen once every topic left', () {
      fakeAsync((async) {
        final client = build();
        final subscription = client.subscribe(_topic);
        async.flushMicrotasks();
        failConnects(async, 5);
        sockets.last.serverClose(1006);
        async.flushMicrotasks();
        final opened = sockets.sockets.length;

        subscription.cancel();
        async.elapse(const Duration(minutes: 2));

        expect(sockets.sockets, hasLength(opened));
        expect(client.state, RealtimeConnectionState.idle);
        unawaited(client.dispose());
      });
    });

    test('reconnect frames in a row back off', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        for (var i = 0; i < 50; i++) {
          sockets.last.serverSend(_welcome());
          sockets.last.serverSend(hermesReconnect);
          async.flushMicrotasks();
        }

        expect(sockets.sockets.length, lessThanOrEqualTo(3));
        unawaited(client.dispose());
      });
    });

    test('a subscriber during the fatal pause is told at once', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverClose(4130);
        async.flushMicrotasks();

        final events = <RealtimeTopicEvent>[];
        client.subscribe(_other).events.listen(events.add);
        async.flushMicrotasks();

        expect(sockets.sockets, hasLength(1));
        expect((events.single as RealtimeUnavailable).permanent, isTrue);
        unawaited(client.dispose());
      });
    });

    test('a late subscriber gets the current status', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        sockets.last.serverSend(ok(subscribed(sockets.last)[_topic]!));
        async.flushMicrotasks();

        final events = <RealtimeTopicEvent>[];
        client.subscribe(_topic).events.listen(events.add);
        async.flushMicrotasks();

        expect(events.map((e) => (e as RealtimeSubscribed).isResubscribe), [
          false,
        ]);
        expect(subscribed(sockets.last), hasLength(1));
        unawaited(client.dispose());
      });
    });

    test('a fatal close in the background is not undone by resuming', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();
        client.onAppPaused();
        async.elapse(const Duration(seconds: 5));
        sockets.last.serverClose(4130);
        async.elapse(const Duration(seconds: 60));

        client.onAppResumed();
        async.flushMicrotasks();

        expect(sockets.sockets, hasLength(1));
        expect(client.state, RealtimeConnectionState.failed);
        async.elapse(const Duration(minutes: 5));
        client.onAppResumed();
        async.flushMicrotasks();
        expect(sockets.sockets, hasLength(2));
        unawaited(client.dispose());
      });
    });

    test('a dropped session does not count as healthy afterwards', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        for (var i = 0; i < 7; i++) {
          async.elapse(const Duration(seconds: 10));
          sockets.last.serverSend(hermesKeepalive);
        }
        // Silence: the watchdog drops the socket, then retries after ~1 s.
        async.elapse(const Duration(seconds: 22));
        final opened = sockets.sockets.length;

        sockets.last.serverClose(1006);
        async.elapse(const Duration(milliseconds: 100));

        expect(sockets.sockets, hasLength(opened), reason: 'backs off');
        unawaited(client.dispose());
      });
    });

    test('a topic first heard in a later session is not a resubscribe', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        sockets.last.serverSend(hermesReconnect);
        async.flushMicrotasks();
        sockets.last.serverSend(_welcome());
        async.flushMicrotasks();

        final events = <RealtimeTopicEvent>[];
        client.subscribe(_other).events.listen(events.add);
        async.flushMicrotasks();
        sockets.last.serverSend(ok(subscribed(sockets.last)[_other]!));
        async.flushMicrotasks();

        expect((events.single as RealtimeSubscribed).isResubscribe, isFalse);
        unawaited(client.dispose());
      });
    });

    test('resuming cuts a pending backoff short', () {
      fakeAsync((async) {
        final client = build()..subscribe(_topic);
        async.flushMicrotasks();
        failConnects(async, 5);
        sockets.last.serverClose(1006);
        async.flushMicrotasks();
        final opened = sockets.sockets.length;

        client.onAppPaused();
        async.elapse(const Duration(seconds: 10));
        client.onAppResumed();
        async.flushMicrotasks();

        expect(sockets.sockets, hasLength(opened + 1));
        unawaited(client.dispose());
      });
    });
  });

  test('refuses malformed and login-only topics', () {
    final client = build();

    expect(() => client.subscribe('bad topic'), throwsArgumentError);
    expect(
      () => client.subscribe('hype-train-events-v1.rewards.1'),
      throwsStateError,
    );
    unawaited(client.dispose());
  });

  test('dispose closes cleanly and leaves no timers', () {
    fakeAsync((async) {
      final client = build();
      final done = Completer<void>();
      client.subscribe(_topic).events.listen(null, onDone: done.complete);
      async.flushMicrotasks();
      sockets.last.serverSend(_welcome());
      async.flushMicrotasks();

      unawaited(client.dispose());
      async.flushMicrotasks();

      expect(sockets.last.clientCloseCode, 1000);
      expect(done.isCompleted, isTrue);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
