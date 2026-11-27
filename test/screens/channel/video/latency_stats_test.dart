import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';

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

  group('chatDelayFromLatency', () {
    test('rounds to tenths of a second', () {
      expect(chatDelayFromLatency(0), 0.0);
      expect(chatDelayFromLatency(300), 0.3);
      expect(chatDelayFromLatency(2349), 2.3);
      expect(chatDelayFromLatency(2350), 2.4);
    });

    test('clamps to 60 seconds', () {
      expect(chatDelayFromLatency(61000), 60.0);
      expect(chatDelayFromLatency(-100), 0.0);
    });
  });

  group('chatDelayWithHysteresis', () {
    test('rounds when there is no delay yet', () {
      expect(chatDelayWithHysteresis(300, null), 0.3);
      expect(chatDelayWithHysteresis(1640, null), 1.6);
    });

    test('keeps the delay within 0.25 s of it', () {
      expect(chatDelayWithHysteresis(1700, 1.5), 1.5);
      expect(chatDelayWithHysteresis(1749, 1.5), 1.5);
      expect(chatDelayWithHysteresis(1260, 1.5), 1.5);
    });

    test('stays put while the latency wanders around it', () {
      double? delay;
      for (final ms in [1500, 1600, 1400, 1700, 1300, 1550, 1450]) {
        delay = chatDelayWithHysteresis(ms, delay);
      }
      expect(delay, 1.5);
    });

    test('moves once the latency is clearly away from it', () {
      expect(chatDelayWithHysteresis(1750, 1.5), 1.8);
      expect(chatDelayWithHysteresis(1250, 1.5), 1.3);
      expect(chatDelayWithHysteresis(4200, 1.0), 4.2);
      expect(chatDelayWithHysteresis(70000, 4.0), 60.0);
    });
  });

  group('formatBitrate', () {
    test('formats megabits and kilobits', () {
      expect(formatBitrate(6200000, L10n.english), '6.2 Mbps');
      expect(formatBitrate(850000, L10n.english), '850 kbps');
      expect(formatBitrate(999, L10n.english), '1 kbps');
    });

    test('returns a dash for unknown values', () {
      expect(formatBitrate(null, L10n.english), '—');
      expect(formatBitrate(0, L10n.english), '—');
      expect(formatBitrate(-1, L10n.english), '—');
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
