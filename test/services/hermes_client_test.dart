import 'dart:async';

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
