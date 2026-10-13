import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/realtime/realtime_socket.dart';

void main() {
  test('a failed connect ends the stream and leaks no zone error', () async {
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      final socket = WebSocketChannelSocket(Uri.parse('ws://127.0.0.1:1/'));
      final done = Completer<void>();
      socket.messages.listen(
        null,
        onError: (Object _) {},
        onDone: done.complete,
      );
      await done.future.timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, (error, _) => uncaught.add(error));

    expect(uncaught, isEmpty);
  });
}
