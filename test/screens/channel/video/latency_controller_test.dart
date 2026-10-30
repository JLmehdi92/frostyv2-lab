import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  late DateTime now;
  late LatencyController controller;

  LatencyController ultra({bool enabled = true}) =>
      LatencyController.forProfile(
        BufferProfile.ultra,
        enabled: enabled,
        now: () => now,
      );

  setUp(() {
    now = DateTime(2026, 10, 30, 20);
    controller = ultra()..onLoad();
  });

  /// One native tick per second, like `IvsPlayerCore`; returns the rate the
  /// controller asked for after each tick.
  List<double> feed(
    int latencyMs,
    int seconds, {
    int? bufferMs = 1800,
    String? hold,
    bool? lowLatency,
    double? nativeRate,
  }) {
    final rates = <double>[];
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      rates.add(
        controller.onSample(
          latencyMs: latencyMs,
          bufferMs: bufferMs,
          lowLatency: lowLatency,
          nativeRate: nativeRate,
          hold: hold,
        ),
      );
    }
    return rates;
  }

  group('calm connection', () {
    test('catches up once the start has been calm for a few seconds', () {
      // Joined 2.2 s behind with a full buffer: the start settle first.
      final settling = feed(2200, 5);
      expect(settling, everyElement(1.0));
      expect(controller.status.phase, AutoLatencyPhase.settling);

      final rates = feed(2200, 2);
      expect(rates.last, LatencyController.catchUpRate);
      expect(controller.status.phase, AutoLatencyPhase.catchingUp);
      expect(controller.status.rate, LatencyController.catchUpRate);
      expect(controller.status.targetMs, 1300);
    });

    test('stays at 1.0x while the latency holds its target', () {
      expect(feed(1200, 120), everyElement(1.0));
      expect(controller.status.phase, AutoLatencyPhase.steady);
    });

    test('a small drift inside the band is left alone', () {
      // Target 1.3 s: up to 1.7 s is not worth speeding up for.
      expect(feed(1650, 120), everyElement(1.0));
    });

    test('catches up from 3-4 s down near the target then stops', () {
      final rates = <double>[
        ...feed(3600, 10),
        // The catch-up brings the latency down second after second.
        for (var ms = 3500; ms > 1300; ms -= 50) ...feed(ms, 1),
        ...feed(1300, 5),
      ];

      expect(rates.where((r) => r > 1), isNotEmpty);
      expect(rates.last, 1.0, reason: 'back to 1.0x near the target');
      expect(controller.status.phase, AutoLatencyPhase.steady);
    });
  });

  group('hysteresis', () {
    test('stops 0.1 s above target and needs 0.4 s to start again', () {
      feed(2000, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      // The latency falls: the median of the last samples has to come down
      // to target + 0.1 s.
      feed(1500, 2);
      expect(controller.rate, LatencyController.catchUpRate);
      feed(1400, 5);
      expect(controller.rate, 1.0);

      // Wandering between the two thresholds never restarts it.
      final rates = <double>[
        for (var i = 0; i < 30; i++) ...feed(i.isEven ? 1450 : 1650, 1),
      ];
      expect(rates, everyElement(1.0));

      // A real drift does, after the rest cooldown.
      expect(feed(1800, 10).last, LatencyController.catchUpRate);
    });

    test('one noisy sample neither starts nor stops it', () {
      feed(1300, 10);
      feed(3000, 1);
      expect(controller.rate, 1.0, reason: 'one spike is not a drift');

      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);
      feed(1300, 1);
      expect(
        controller.rate,
        LatencyController.catchUpRate,
        reason: 'one low sample is not the target reached',
      );
    });

    test('never flaps: at most one change every five seconds', () {
      feed(2000, 8);
      final rates = <double>[
        for (var i = 0; i < 60; i++) ...feed(i % 6 < 3 ? 1300 : 2400, 1),
      ];
      var changes = 0;
      for (var i = 1; i < rates.length; i++) {
        if (rates[i] != rates[i - 1]) changes++;
      }
      expect(changes, lessThanOrEqualTo(60 ~/ 5));
    });
  });

  group('never above the maximum rate', () {
    test('whatever the latency', () {
      final rates = [...feed(60000, 30), ...feed(9000, 30, bufferMs: 60000)];
      expect(
        rates.every((r) => r >= 1.0 && r <= LatencyController.maxLiveRate),
        isTrue,
      );
      expect(LatencyController.catchUpRate, lessThanOrEqualTo(1.05));
      expect(LatencyController.maxLiveRate, 1.1);
    });
  });

  group('unstable connection', () {
    test('a stall stops the catch-up at once', () {
      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      controller.onStall();

      expect(controller.rate, 1.0);
      expect(controller.status.phase, AutoLatencyPhase.settling);
    });

    test('waits a longer calm after a stall', () {
      feed(1300, 10);
      controller.onStall();

      final rates = feed(2200, LatencyController.calmAfterStall.inSeconds);
      expect(rates, everyElement(1.0));
      expect(feed(2200, 2).last, LatencyController.catchUpRate);
    });

    test('stops when the buffer reaches its floor', () {
      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      // The latency is still high but the buffer is gone: the rest of the
      // delay is the network's, playing faster would only stall.
      feed(2200, 5, bufferMs: 600);

      expect(controller.rate, 1.0);
    });

    test('never starts without buffer to spare', () {
      expect(feed(2500, 60, bufferMs: 800), everyElement(1.0));
    });

    test('never starts without a buffer reading', () {
      expect(feed(2500, 60, bufferMs: null), everyElement(1.0));
      expect(controller.status.phase, AutoLatencyPhase.held);
    });

    test('a ticker gap means the calm has to be seen again', () {
      feed(2200, 4);
      now = now.add(const Duration(seconds: 10));
      expect(feed(2200, 5), everyElement(1.0));
      expect(feed(2200, 2).last, LatencyController.catchUpRate);
    });

    test('backs off after stalls that follow a catch-up, then stops', () {
      for (var strike = 1; strike <= LatencyController.maxStrikes; strike++) {
        // Calm long enough, drifts, catches up, stalls.
        feed(3000, 30);
        expect(
          controller.rate,
          LatencyController.catchUpRate,
          reason: 'strike $strike',
        );
        controller.onStall();
        if (strike < LatencyController.maxStrikes) {
          expect(
            controller.status.targetMs,
            1300 + strike * LatencyController.strikeBackoffMs,
          );
        }
      }

      expect(controller.status.phase, AutoLatencyPhase.stopped);
      expect(feed(3000, 60), everyElement(1.0));
    });

    test('a stall long after a catch-up is not its fault', () {
      feed(2200, 8);
      feed(1300, 10);
      expect(controller.rate, 1.0);

      now = now.add(LatencyController.strikeWindow);
      controller.onStall();

      expect(controller.status.targetMs, 1300);
    });

    test('a quality change during a catch-up stops it', () {
      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      controller.onQualityChanged();

      expect(controller.rate, 1.0);
      expect(
        controller.status.targetMs,
        1300 + LatencyController.strikeBackoffMs,
      );
    });

    test('a quality change while steady changes nothing', () {
      feed(1300, 30);
      controller.onQualityChanged();

      expect(controller.status.phase, AutoLatencyPhase.steady);
      expect(controller.status.targetMs, 1300);
    });
  });

  group('holds', () {
    for (final reason in ['paused', 'picture-in-picture', 'mini player']) {
      test('never corrects while $reason', () {
        expect(feed(3000, 60, hold: reason), everyElement(1.0));
        expect(controller.status.phase, AutoLatencyPhase.held);
        expect(controller.status.reason, reason);
      });
    }

    test('a hold during a catch-up drops back to 1.0x at once', () {
      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      expect(feed(2200, 1, hold: 'paused'), [1.0]);
    });

    test('hold() drops back to 1.0x without a sample', () {
      feed(2200, 8);
      controller.hold('picture-in-picture');
      expect(controller.rate, 1.0);
    });

    test('after a hold the calm starts over', () {
      feed(2200, 8, hold: 'paused');
      expect(feed(2200, 5), everyElement(1.0));
      expect(feed(2200, 2).last, LatencyController.catchUpRate);
    });

    test('never corrects during an ad', () {
      feed(1300, 10);
      controller.onAd(const Duration(seconds: 30));

      final during = feed(3000, LatencyController.minAdHold.inSeconds - 1);
      expect(during, everyElement(1.0));
      expect(controller.status.reason, 'ad');
    });

    test('a stream without low latency is left alone', () {
      expect(feed(5000, 60, lowLatency: false), everyElement(1.0));
      expect(controller.status.phase, AutoLatencyPhase.held);
    });
  });

  group('disabled', () {
    test('does nothing when the setting is off', () {
      controller = ultra(enabled: false)..onLoad();

      expect(feed(4000, 120), everyElement(1.0));
      expect(controller.status.phase, AutoLatencyPhase.off);
      controller.onStall();
      controller.onQualityChanged();
      expect(controller.rate, 1.0);
    });

    test('stops for good when the player refuses the rate', () {
      feed(2200, 8);
      controller.onRateRejected();

      expect(controller.rate, 1.0);
      expect(controller.status.phase, AutoLatencyPhase.stopped);
      expect(feed(4000, 60), everyElement(1.0));
    });

    test('stops when the player does not keep the rate', () {
      feed(2200, 8);
      expect(controller.rate, LatencyController.catchUpRate);

      // Something (the SDK's own catch-up) puts the rate back at 1.0x.
      feed(2200, LatencyController.rateNotHeldTicks, nativeRate: 1.0);

      expect(controller.status.phase, AutoLatencyPhase.stopped);
      expect(controller.rate, 1.0);
    });

    test('a manual refresh tries again', () {
      feed(2200, 8);
      controller
        ..onRateRejected()
        ..reset()
        ..onLoad();

      expect(feed(2200, 8).last, LatencyController.catchUpRate);
    });

    test('a new load keeps the back-off but restarts the settle', () {
      feed(3000, 30);
      controller.onStall();
      controller.onLoad();

      expect(controller.rate, 1.0);
      expect(controller.status.phase, AutoLatencyPhase.settling);
      expect(
        controller.status.targetMs,
        1300 + LatencyController.strikeBackoffMs,
      );
    });
  });

  group('profiles', () {
    test('standard aims where a refresh lands', () {
      final standard = LatencyController.forProfile(
        BufferProfile.standard,
        enabled: true,
      );
      expect(standard.targetMs, 2000);
      expect(standard.bufferFloorMs, 1000);
    });

    test('ultra aims just above its measured steady latency', () {
      expect(controller.targetMs, 1300);
      expect(controller.bufferFloorMs, 700);
    });
  });

  test('status values compare by value', () {
    const a = AutoLatencyStatus(
      phase: AutoLatencyPhase.steady,
      rate: 1.0,
      targetMs: 1300,
    );
    const b = AutoLatencyStatus(
      phase: AutoLatencyPhase.steady,
      rate: 1.0,
      targetMs: 1300,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  group('describeAutoLatency', () {
    test('off', () {
      expect(describeAutoLatency(null), 'off');
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(phase: AutoLatencyPhase.off, rate: 1.0),
        ),
        'off',
      );
    });

    test('catching up shows the rate and the target', () {
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.catchingUp,
            rate: 1.05,
            targetMs: 1300,
          ),
        ),
        'catching up 1.05x · target 1.3s',
      );
    });

    test('steady, settling, held and stopped', () {
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.steady,
            rate: 1.0,
            targetMs: 1300,
          ),
        ),
        'at target · target 1.3s',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.settling,
            rate: 1.0,
            targetMs: 1800,
            calmLeftSeconds: 12,
          ),
        ),
        'waiting for calm 12s · target 1.8s',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.held,
            rate: 1.0,
            targetMs: 1300,
            reason: 'paused',
          ),
        ),
        'held: paused · target 1.3s',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.stopped,
            rate: 1.0,
            targetMs: 2800,
            reason: 'stalls after catching up',
          ),
        ),
        'stopped: stalls after catching up',
      );
    });
  });

  test('describeBufferFallback says until when', () {
    expect(describeBufferFallback(null), isNull);
    expect(
      describeBufferFallback(DateTime(2026, 10, 30, 9, 5)),
      'Standard until 09:05 (Ultra stalled)',
    );
  });
}
