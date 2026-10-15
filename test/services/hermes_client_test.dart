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
