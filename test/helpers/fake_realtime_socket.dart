import 'dart:async';

import 'package:frosty/services/realtime/realtime_socket.dart';

/// A scripted [RealtimeSocket]: tests push server frames and closes.
class FakeRealtimeSocket implements RealtimeSocket {
  FakeRealtimeSocket(this.uri);

  final Uri uri;
  final sent = <String>[];
  final _controller = StreamController<String>();
  var closedByClient = false;
  int? clientCloseCode;

  @override
  int? closeCode;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String text) {
    if (_controller.isClosed) return;
    sent.add(text);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closedByClient = true;
    clientCloseCode = code;
    closeCode ??= code;
    if (!_controller.isClosed) await _controller.close();
  }

  /// Ignored once closed (a closed socket receives nothing).
  void serverSend(String text) {
    if (!_controller.isClosed) _controller.add(text);
  }

  void serverClose(int? code) {
    closeCode = code;
    unawaited(_controller.close());
  }

  bool get isClosed => _controller.isClosed;
}

/// Hands out a new [FakeRealtimeSocket] per connect and remembers them.
class FakeRealtimeSocketFactory {
  final sockets = <FakeRealtimeSocket>[];

  FakeRealtimeSocket get first => sockets.first;
  FakeRealtimeSocket get last => sockets.last;

  RealtimeSocket call(Uri uri) {
    final socket = FakeRealtimeSocket(uri);
    sockets.add(socket);
    return socket;
  }
}
