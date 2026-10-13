import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A text websocket, abstracted so the realtime client can be tested
/// without a network.
abstract interface class RealtimeSocket {
  /// Text frames from the server; done when the socket closes.
  Stream<String> get messages;

  void send(String text);

  Future<void> close([int? code, String? reason]);

  /// Set once the socket closed.
  int? get closeCode;
}

typedef RealtimeSocketFactory = RealtimeSocket Function(Uri uri);

/// [RealtimeSocket] over `web_socket_channel` (`dart:io` on Android and iOS,
/// which answers the server's websocket pings by itself).
class WebSocketChannelSocket implements RealtimeSocket {
  WebSocketChannelSocket(Uri uri) : _channel = WebSocketChannel.connect(uri) {
    // A failed connect also ends [messages], which the client handles; left
    // unobserved, `ready` would report the same failure to the zone.
    _channel.ready.ignore();
  }

  final WebSocketChannel _channel;

  @override
  late final Stream<String> messages = _channel.stream
      .where((frame) => frame is String)
      .cast<String>();

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);

  @override
  int? get closeCode => _channel.closeCode;
}
