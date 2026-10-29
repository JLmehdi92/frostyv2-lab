import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/hype_train/hype_train_clock.dart';

void main() {
  final base = DateTime.utc(2026, 10, 13, 16);

  test('without samples it is the local clock', () {
    withClock(Clock.fixed(base), () {
      expect(ServerClock().now(), base);
    });
  });

  test('follows the median of the last five offsets', () {
    withClock(Clock.fixed(base), () {
      final server = ServerClock();
      for (final seconds in [3, 3, 50, 3, -40]) {
        server.observe(base.add(Duration(seconds: seconds)));
      }

      expect(server.offset, const Duration(seconds: 3));
      expect(server.now(), base.add(const Duration(seconds: 3)));

      for (var i = 0; i < 5; i++) {
        server.observe(base.add(const Duration(seconds: 1)));
      }
      expect(server.offset, const Duration(seconds: 1), reason: 'last 5');
    });
  });

  test('ignores offsets over 10 minutes', () {
    withClock(Clock.fixed(base), () {
      final server = ServerClock()
        ..observe(base.add(const Duration(minutes: 11)))
        ..observe(base.subtract(const Duration(hours: 3)));

      expect(server.offset, Duration.zero);
    });
  });
}
