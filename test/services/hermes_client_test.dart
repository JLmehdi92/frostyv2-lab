import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hermes.dart';
import 'package:onset/services/hermes_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A socket that records what the client sends and whether it was closed.
class _FakeSocket implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  late final _FakeSink _sink = _FakeSink();

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  bool get closed => _sink.closed;

  /// What the client sent, decoded.
  List<Map<String, dynamic>> get frames => [
    for (final frame in _sink.sent)
      jsonDecode(frame as String) as Map<String, dynamic>,
  ];

  List<String> get types => [for (final f in frames) f['type'] as String];

  /// The topics of the subscribe frames sent, in order.
  List<String> get subscribedTopics => [
    for (final f in frames)
      if (f['type'] == 'subscribe')
        (f['subscribe'] as Map)['pubsub']['topic'] as String,
  ];

  void receive(dynamic frame) => _incoming.add(frame);

  /// The server hangs up.
  void hangUp() => unawaited(_incoming.close());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  final sent = <dynamic>[];
  var closed = false;

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The server's answer to the last subscribe [socket] sent for [topic].
String _subscribeOk(_FakeSocket socket, String topic, String subscriptionId) {
  final request = socket.frames.lastWhere(
    (f) =>
        f['type'] == 'subscribe' &&
        (f['subscribe'] as Map)['pubsub']['topic'] == topic,
  );
  return jsonEncode({
    'type': 'subscribeResponse',
    'id': 'resp-$subscriptionId',
    'parentId': request['id'],
    'subscribeResponse': {
      'subscription': {'id': subscriptionId},
      'result': 'ok',
    },
  });
}

/// A notification on [subscriptionId], payload double-encoded as Hermes does.
String _notification(
  String subscriptionId,
  String type, [
  Map<String, dynamic> data = const {},
]) => jsonEncode({
  'type': 'notification',
  'id': 'n-$subscriptionId',
  'notification': {
    'subscription': {'id': subscriptionId},
    'type': 'pubsub',
    'pubsub': jsonEncode({'type': type, 'data': data}),
  },
});

void main() {
  late List<_FakeSocket> sockets;
  late HermesClient client;

  setUp(() {
    sockets = [];
    client = HermesClient(
      connect: (_) {
        final socket = _FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
  });

  tearDown(() => client.dispose());

  HermesClient withToken(Future<String?> Function() tokenProvider) {
    client.dispose();
    return client = HermesClient(
      connect: (_) {
        final socket = _FakeSocket();
        sockets.add(socket);
        return socket;
      },
      tokenProvider: tokenProvider,
    );
  }

  const welcome = '{"type":"welcome","id":"w","welcome":{"keepaliveSec":15}}';
  const hermesKeepaliveFrame = '{"type":"keepalive","id":"k"}';

  /// Opens a session and subscribes [topics], acknowledged as `sub-<i>`.
  Future<_FakeSocket> session(List<String> topics) async {
    await client.subscribeAll(topics);
    final socket = sockets.last;
    socket.receive(welcome);
    await pumpEventQueue();
    for (final (i, topic) in topics.indexed) {
      socket.receive(_subscribeOk(socket, topic, 'sub-$i'));
    }
    await pumpEventQueue();
    return socket;
  }

  group('subscribing', () {
    test('waits for the welcome, then sends each topic once', () async {
      await client.subscribeAll(['a.1', 'b.1']);
      await client.subscribe('a.1');
      final socket = sockets.single;
      await pumpEventQueue();
      expect(socket.types, isEmpty);

      socket.receive(welcome);
      await pumpEventQueue();

      expect(socket.subscribedTopics, ['a.1', 'b.1']);
    });

    test('after the welcome a topic goes out at once, and only once', () async {
      final socket = await session(['a.1']);

      await client.subscribe('b.1');
      await client.subscribe('b.1');
      await client.subscribe('a.1');

      expect(socket.subscribedTopics, ['a.1', 'b.1']);
      expect(sockets, hasLength(1));
    });
  });

  group('subscription lifecycle', () {
    test('unsubscribing before the answer does not leak the topic', () async {
      final received = <HermesEvent>[];
      client.events.listen(received.add);
      await client.subscribe('celebration-events-v1.1');
      final socket = sockets.single;
      socket.receive(welcome);
      await pumpEventQueue();

      // Asked, then dropped before Hermes answered.
      final answer = _subscribeOk(socket, 'celebration-events-v1.1', 'sub-1');
      client.unsubscribe('celebration-events-v1.1');
      socket.receive(answer);
      await pumpEventQueue();
      socket.receive(_notification('sub-1', 'alert_sets_celebration'));
      await pumpEventQueue();

      expect(received, isEmpty);
      // The server-side subscription is released, not left running.
      final unsubscribe = socket.frames.last;
      expect(unsubscribe['type'], 'unsubscribe');
      expect(unsubscribe['unsubscribe'], {'id': 'sub-1'});
    });

    test('a revoked topic is subscribed afresh', () async {
      final received = <HermesEvent>[];
      client.events.listen(received.add);
      final socket = await session(['creator-goals-events-v1.1']);
      expect(socket.subscribedTopics, ['creator-goals-events-v1.1']);

      socket.receive(
        '{"type":"revocation","id":"r",'
        '"revocation":{"subscription":{"id":"sub-0"},"reason":"x"}}',
      );
      await pumpEventQueue();

      expect(socket.subscribedTopics, [
        'creator-goals-events-v1.1',
        'creator-goals-events-v1.1',
      ]);

      // The old id routes nothing; the new one does.
      socket.receive(
        _subscribeOk(socket, 'creator-goals-events-v1.1', 'sub-9'),
      );
      socket.receive(_notification('sub-0', 'goal_updated'));
      socket.receive(_notification('sub-9', 'goal_updated'));
      await pumpEventQueue();

      expect(received.map((e) => e.topic), ['creator-goals-events-v1.1']);
    });

    test('a revocation for an unknown id subscribes nothing', () async {
      final socket = await session(['creator-goals-events-v1.1']);

      socket.receive(
        '{"type":"revocation","id":"r",'
        '"revocation":{"subscription":{"id":"nope"}}}',
      );
      await pumpEventQueue();

      expect(socket.subscribedTopics, hasLength(1));
    });
  });

  group('notifications', () {
    late List<HermesEvent> received;

    setUp(() {
      received = [];
      client.events.listen(received.add);
    });

    test('are routed to their topic by subscription id', () async {
      final socket = await session(['goals.1', 'points.1']);

      socket.receive(_notification('sub-1', 'points-earned', {'n': 5}));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.topic, 'points.1');
      expect(received.single.type, 'points-earned');
      expect(received.single.data, {'n': 5});
    });

    test('a payload sent as an object is read too', () async {
      final socket = await session(['goals.1']);

      socket.receive(
        jsonEncode({
          'type': 'notification',
          'id': 'n',
          'notification': {
            'subscription': {'id': 'sub-0'},
            'type': 'pubsub',
            'pubsub': {
              'type': 'goal_updated',
              'data': {'goal': 1},
            },
          },
        }),
      );
      await pumpEventQueue();

      expect(received.single.type, 'goal_updated');
      expect(received.single.data, {'goal': 1});
    });

    test('an unknown subscription id is dropped', () async {
      final socket = await session(['goals.1']);

      socket.receive(_notification('sub-77', 'goal_updated'));
      await pumpEventQueue();

      expect(received, isEmpty);
    });

    test('a refused subscribe routes nothing afterwards', () async {
      await client.subscribe('bad.1');
      final socket = sockets.single;
      socket.receive(welcome);
      await pumpEventQueue();
      final request = socket.frames.lastWhere((f) => f['type'] == 'subscribe');
      socket.receive(
        jsonEncode({
          'type': 'subscribeResponse',
          'id': 'r',
          'parentId': request['id'],
          'subscribeResponse': {
            'subscription': {'id': 'sub-bad'},
            'result': 'error',
            'error': 'invalid topic',
          },
        }),
      );
      await pumpEventQueue();

      socket.receive(_notification('sub-bad', 'anything'));
      await pumpEventQueue();

      expect(received, isEmpty);
    });

    test('a malformed payload is dropped', () async {
      final socket = await session(['goals.1']);

      for (final pubsub in <Object>[
        'not json',
        '[1]',
        '{"data":{}}',
        '{"type":5}',
        7,
      ]) {
        socket.receive(
          jsonEncode({
            'type': 'notification',
            'id': 'n',
            'notification': {
              'subscription': {'id': 'sub-0'},
              'pubsub': pubsub,
            },
          }),
        );
      }
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(socket.closed, isFalse);
    });

    test('a payload without data arrives with empty data', () async {
      final socket = await session(['goals.1']);

      socket.receive(
        jsonEncode({
          'type': 'notification',
          'id': 'n',
          'notification': {
            'subscription': {'id': 'sub-0'},
            'pubsub': '{"type":"goal_ended"}',
          },
        }),
      );
      await pumpEventQueue();

      expect(received.single.data, isEmpty);
    });
  });

  group('connection upkeep', () {
    /// Lets the reconnect timer run out: the delay is jittered between half
    /// and all of the backoff base.
    void waitBackoff(FakeAsync async, int baseMs, int socketsBefore) {
      async.elapse(Duration(milliseconds: baseMs ~/ 2 - 1));
      expect(sockets, hasLength(socketsBefore), reason: 'too early at $baseMs');
      async.elapse(Duration(milliseconds: baseMs ~/ 2 + 1));
      expect(
        sockets,
        hasLength(socketsBefore + 1),
        reason: 'not reconnected at $baseMs',
      );
    }

    test('backs off exponentially up to a minute, reset by a welcome', () {
      fakeAsync((async) {
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        expect(sockets, hasLength(1));

        var base = 500;
        for (var attempt = 0; attempt < 9; attempt++) {
          sockets.last.hangUp();
          async.flushMicrotasks();
          waitBackoff(async, base, sockets.length);
          base = (base * 2).clamp(0, 60000);
        }
        expect(base, 60000);
        sockets.last.hangUp();
        async.flushMicrotasks();
        waitBackoff(async, 60000, sockets.length);

        // A session that came up starts the count again.
        sockets.last.receive(welcome);
        async.flushMicrotasks();
        sockets.last.hangUp();
        async.flushMicrotasks();
        waitBackoff(async, 500, sockets.length);
      });
    });

    test('a reconnect frame moves without charging the backoff', () {
      fakeAsync((async) {
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          sockets.last.hangUp();
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
        }
        final socket = sockets.last;

        socket.receive(
          '{"type":"reconnect","id":"r","reconnect":{"url":"wss://x"}}',
        );
        async.flushMicrotasks();
        expect(socket.closed, isTrue);
        waitBackoff(async, 500, sockets.length);

        // The new session subscribes the same topics again.
        sockets.last.receive(welcome);
        async.flushMicrotasks();
        expect(sockets.last.subscribedTopics, ['goals.1']);
      });
    });

    test('pings within the keepalive the server asked for', () {
      fakeAsync((async) {
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        final socket = sockets.single;
        socket.receive(
          '{"type":"welcome","id":"w","welcome":{"keepaliveSec":10}}',
        );
        async.flushMicrotasks();

        int pings() => socket.types.where((t) => t == 'ping').length;
        async.elapse(const Duration(milliseconds: 5999));
        expect(pings(), 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(pings(), 1);
        socket.receive(hermesKeepaliveFrame);
        async.elapse(const Duration(seconds: 6));
        expect(pings(), 2);
      });
    });

    test('silence for three keepalives reconnects', () {
      fakeAsync((async) {
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        final socket = sockets.single;
        socket.receive(welcome);
        async.flushMicrotasks();

        // Frames keep it alive...
        for (var i = 0; i < 4; i++) {
          async.elapse(const Duration(seconds: 40));
          socket.receive(hermesKeepaliveFrame);
          async.flushMicrotasks();
        }
        expect(socket.closed, isFalse);

        // ...45 s of nothing does not.
        async.elapse(const Duration(seconds: 45));
        expect(socket.closed, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(sockets, hasLength(2));
      });
    });

    test('pausing cancels a pending reconnect', () {
      fakeAsync((async) {
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        sockets.single.hangUp();
        async.flushMicrotasks();

        client.pause();
        async.elapse(const Duration(minutes: 10));
        expect(sockets, hasLength(1));

        unawaited(client.resume());
        async.flushMicrotasks();
        expect(sockets, hasLength(2));
      });
    });

    test('dispose closes the socket and the event stream for good', () {
      fakeAsync((async) {
        var done = false;
        client.events.listen(null, onDone: () => done = true);
        unawaited(client.subscribe('goals.1'));
        async.flushMicrotasks();
        final socket = sockets.single;

        client.dispose();
        async.flushMicrotasks();
        expect(socket.closed, isTrue);
        expect(done, isTrue);

        unawaited(client.subscribe('goals.2'));
        socket.hangUp();
        async.elapse(const Duration(minutes: 5));
        expect(sockets, hasLength(1));
      });
    });
  });

  group('malformed frames', () {
    for (final frame in <Object>[
      'not json',
      '[1]',
      '"just a string"',
      [1, 2, 3],
      '{"type":5}',
      '{"type":"x","id":5}',
      '{"type":"subscribeResponse","id":"a","parentId":7}',
      '{"type":"welcome","id":"w","welcome":5}',
      '{"type":"notification","id":"n","notification":"nope"}',
      '{"type":"revocation","id":"r","revocation":[1]}',
    ]) {
      test('$frame is dropped and the socket kept', () async {
        await client.subscribe('celebration-events-v1.1');
        sockets.single.receive(frame);
        await pumpEventQueue();

        expect(sockets, hasLength(1));
        expect(sockets.single.closed, isFalse);
        expect(client.isConnected, isTrue);
      });
    }

    test('a zero keepalive does not hammer nor drop the socket', () async {
      await client.subscribe('celebration-events-v1.1');
      sockets.single.receive(
        '{"type":"welcome","id":"w","welcome":{"keepaliveSec":0}}',
      );
      await pumpEventQueue();
      sockets.single.receive('{"type":"keepalive","id":"k"}');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sockets.single.closed, isFalse);
      expect(sockets.single.types.where((t) => t == 'ping'), isEmpty);
    });
  });

  test('a parse error logs its code, never the message it echoes', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    await client.subscribe('celebration-events-v1.1');
    sockets.single.receive(
      jsonEncode({
        'type': 'parseError',
        'id': 'p',
        'parseError': {
          'errorCode': 'PE001',
          'error': 'bad frame',
          'message': '{"authenticate":{"token":"SECRET-TOKEN"}}',
        },
      }),
    );
    await pumpEventQueue();

    expect(logs.join('\n'), isNot(contains('SECRET-TOKEN')));
    expect(logs.join('\n'), contains('PE001'));
  });

  group('authentication', () {
    test('is sent before any subscribe after the welcome', () async {
      final token = Completer<String?>();
      withToken(() => token.future);
      await client.subscribeAll([
        'community-points-user-v1.9',
        'celebration-events-v1.1',
      ]);

      sockets.single.receive(welcome);
      await pumpEventQueue();
      // Nothing may go out while the token is still being read: a subscribe
      // ahead of the authenticate frame is refused for user topics.
      expect(sockets.single.types, isEmpty);

      token.complete('tok');
      await pumpEventQueue();

      expect(sockets.single.types, ['authenticate', 'subscribe', 'subscribe']);
      expect(sockets.single.frames.first['authenticate'], {'token': 'tok'});
    });

    test('a topic added while authenticating waits for it', () async {
      final token = Completer<String?>();
      withToken(() => token.future);
      await client.subscribe('celebration-events-v1.1');
      sockets.single.receive(welcome);
      await pumpEventQueue();

      await client.subscribe('community-points-user-v1.9');
      token.complete('tok');
      await pumpEventQueue();

      expect(sockets.single.types.first, 'authenticate');
      expect(sockets.single.subscribedTopics, [
        'celebration-events-v1.1',
        'community-points-user-v1.9',
      ]);
    });

    test('a missing or failing token still subscribes', () async {
      withToken(() async => null);
      await client.subscribe('celebration-events-v1.1');
      sockets.single.receive(welcome);
      await pumpEventQueue();
      expect(sockets.single.types, ['subscribe']);

      withToken(() async => throw StateError('storage'));
      await client.subscribe('celebration-events-v1.1');
      sockets.last.receive(welcome);
      await pumpEventQueue();
      expect(sockets.last.types, ['subscribe']);
    });

    test('without a token provider nothing authenticates', () async {
      await client.subscribe('celebration-events-v1.1');
      sockets.single.receive(welcome);
      await pumpEventQueue();

      expect(sockets.single.types, ['subscribe']);
    });
  });

  test('pausing closes the socket and opens none until resumed', () async {
    await client.subscribe('celebration-events-v1.1');
    expect(sockets, hasLength(1));

    client.pause();
    expect(sockets.single.closed, isTrue);
    expect(client.isConnected, isFalse);

    // Subscribing while paused only remembers the topic.
    await client.subscribe('creator-goals-events-v1.1');
    expect(sockets, hasLength(1));

    await client.resume();
    expect(sockets, hasLength(2));
    expect(client.isConnected, isTrue);
  });

  test('resuming without topics opens nothing', () async {
    client.pause();
    await client.resume();

    expect(sockets, isEmpty);
  });

  test('a channel only subscribes the topics something reads', () {
    expect(HermesTopics.forChannel('1'), [
      'predictions-channel-v1.1',
      'community-points-channel-v1.1',
      'creator-goals-events-v1.1',
      'celebration-events-v1.1',
      'shoutout.1',
      'content-classification-labels-v1.1',
      'video-playback-by-id.1',
      'broadcast-settings-update.1',
      'channel-sub-gifts-v1.1',
      'community-moments-channel-v1.1',
    ]);
  });

  test('a sub gifts payload is delivered flat, with its type', () async {
    final received = <HermesEvent>[];
    client.events.listen(received.add);
    await client.subscribe('channel-sub-gifts-v1.1');
    final socket = sockets.single;
    socket.receive(welcome);
    await pumpEventQueue();
    socket.receive(_subscribeOk(socket, 'channel-sub-gifts-v1.1', 'sub-1'));
    await pumpEventQueue();
    socket.receive(
      jsonEncode({
        'type': 'notification',
        'id': 'n',
        'notification': {
          'subscription': {'id': 'sub-1'},
          'type': 'pubsub',
          'pubsub': jsonEncode({
            'type': 'mystery-gift-purchase',
            'count': 5,
            'uuid': 'u',
            'channel_id': '1',
          }),
        },
      }),
    );
    await pumpEventQueue();
    expect(received.single.type, 'mystery-gift-purchase');
    expect(received.single.data['count'], 5);
  });

  test('a stream state payload is delivered flat, with its type', () async {
    final received = <HermesEvent>[];
    client.events.listen(received.add);
    await client.subscribe('video-playback-by-id.1');
    final socket = sockets.single;
    socket.receive(welcome);
    await pumpEventQueue();
    socket.receive(_subscribeOk(socket, 'video-playback-by-id.1', 'sub-1'));
    await pumpEventQueue();
    socket.receive(
      jsonEncode({
        'type': 'notification',
        'id': 'n',
        'notification': {
          'subscription': {'id': 'sub-1'},
          'type': 'pubsub',
          'pubsub': jsonEncode({
            'type': 'viewcount',
            'server_time': 1,
            'viewers': 77,
          }),
        },
      }),
    );
    await pumpEventQueue();

    expect(received.single.type, 'viewcount');
    expect(received.single.data['viewers'], 77);
  });

  test('a payload without a type is delivered whole', () async {
    final received = <HermesEvent>[];
    client.events.listen(received.add);
    await client.subscribe('content-classification-labels-v1.1');
    final socket = sockets.single;
    socket.receive(welcome);
    await pumpEventQueue();
    socket.receive(
      _subscribeOk(socket, 'content-classification-labels-v1.1', 'sub-1'),
    );
    await pumpEventQueue();
    socket.receive(
      jsonEncode({
        'type': 'notification',
        'id': 'n',
        'notification': {
          'subscription': {'id': 'sub-1'},
          'type': 'pubsub',
          'pubsub': jsonEncode({
            'jitter': 0,
            'content_classification_labels': <Object>[],
          }),
        },
      }),
    );
    await pumpEventQueue();

    expect(received.single.type, '');
    expect(received.single.data['content_classification_labels'], isEmpty);
  });
}
