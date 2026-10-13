import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/latency_stats.dart';

void main() {
  group('formatLatency', () {
    test('formats milliseconds with 0.1 s precision', () {
      expect(formatLatency(0), '0.0s');
      expect(formatLatency(2349), '2.3s');
      expect(formatLatency(2350), '2.4s');
      expect(formatLatency(999), '1.0s');
      expect(formatLatency(61234), '61.2s');
    });

    test('clamps negative values to zero', () {
      expect(formatLatency(-500), '0.0s');
    });
  });

  group('chatDelaySecondsFromLatency', () {
    test('rounds to whole seconds like the previous implementation', () {
      expect(chatDelaySecondsFromLatency(0), 0);
      expect(chatDelaySecondsFromLatency(2400), 2);
      expect(chatDelaySecondsFromLatency(2500), 3);
    });

    test('clamps to 60 seconds', () {
      expect(chatDelaySecondsFromLatency(61000), 60);
      expect(chatDelaySecondsFromLatency(-100), 0);
    });
  });

  group('formatBitrate', () {
    test('formats megabits and kilobits', () {
      expect(formatBitrate(6200000), '6.2 Mbps');
      expect(formatBitrate(850000), '850 kbps');
      expect(formatBitrate(999), '1 kbps');
    });

    test('returns a dash for unknown values', () {
      expect(formatBitrate(null), '—');
      expect(formatBitrate(0), '—');
      expect(formatBitrate(-1), '—');
    });
  });

  group('LatencySampler', () {
    test('returns null statistics when empty', () {
      final sampler = LatencySampler();

      expect(sampler.count, 0);
      expect(sampler.median, isNull);
      expect(sampler.p90, isNull);
      expect(sampler.min, isNull);
      expect(sampler.max, isNull);
    });

    test('computes median, p90, min and max', () {
      final sampler = LatencySampler();
      for (final ms in [5000, 1000, 3000, 2000, 4000]) {
        sampler.add(ms);
      }

      expect(sampler.count, 5);
      expect(sampler.median, 3000);
      expect(sampler.min, 1000);
      expect(sampler.max, 5000);
      expect(sampler.p90, 5000);
    });

    test('uses the upper middle value for an even count median', () {
      final sampler = LatencySampler()
        ..add(1000)
        ..add(2000)
        ..add(3000)
        ..add(4000);

      expect(sampler.median, 3000);
    });

    test('p90 uses the nearest-rank method', () {
      final sampler = LatencySampler();
      for (var i = 1; i <= 10; i++) {
        sampler.add(i * 100);
      }

      expect(sampler.p90, 900);
    });

    test('evicts the oldest samples beyond capacity', () {
      final sampler = LatencySampler(capacity: 3)
        ..add(10000)
        ..add(1000)
        ..add(2000)
        ..add(3000);

      expect(sampler.count, 3);
      expect(sampler.max, 3000);
      expect(sampler.min, 1000);
    });

    test('defaults to five minutes of 1 Hz samples', () {
      final sampler = LatencySampler();
      for (var i = 0; i < 301; i++) {
        sampler.add(i);
      }

      expect(sampler.count, 300);
      expect(sampler.min, 1);
    });

    test('reset clears all samples', () {
      final sampler = LatencySampler()
        ..add(1000)
        ..reset();

      expect(sampler.count, 0);
      expect(sampler.median, isNull);
    });
  });
}
