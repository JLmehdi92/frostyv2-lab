import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hermes.dart';
import 'package:frosty/services/hermes_client.dart';
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
    ]);
  });
}
