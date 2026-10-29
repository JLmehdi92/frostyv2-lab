import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/live_edge_guard.dart';

void main() {
  late DateTime now;
  late LiveEdgeGuard guard;

  setUp(() {
    now = DateTime(2026, 10, 20, 12);
    guard = LiveEdgeGuard(now: () => now);
  });

  /// Feeds one sample per second (like the native ticker) and returns the
  /// seconds (1-based) at which the guard asked for a jump.
  List<int> feed(List<int> latenciesMs, {bool playing = true}) {
    final jumps = <int>[];
    for (var i = 0; i < latenciesMs.length; i++) {
      now = now.add(const Duration(seconds: 1));
      if (guard.onSample(latenciesMs[i], playing: playing)) jumps.add(i + 1);
    }
    return jumps;
  }

  List<int> repeat(int ms, int seconds) => List.filled(seconds, ms);

  test('never jumps while the player holds the low-latency target', () {
    guard.onLoad();
    expect(feed([...repeat(2400, 60), ...repeat(3200, 60)]), isEmpty);
  });

  test('jumps once drift stays past the threshold long enough', () {
    guard.onLoad();
    // Settles at 2.3 s, then rebuffers left it 6 s behind.
    final jumps = feed([...repeat(2300, 20), ...repeat(6000, 15)]);

    expect(guard.floorMs, 2300);
    expect(guard.thresholdMs, LiveEdgeGuard.minThresholdMs);
    // Ten seconds of sustained drift after the first late sample.
    expect(jumps, [20 + 1 + 10]);
  });

  test('a short spike (the speed-up catching up) is left alone', () {
    guard.onLoad();
    expect(
      feed([
        ...repeat(2300, 20),
        ...repeat(6000, 8),
        ...repeat(3000, 5),
        ...repeat(6000, 8),
      ]),
      isEmpty,
    );
  });

  test('does nothing while settling after a load', () {
    guard.onLoad();
    // A slow start well behind live: the speed-up is still catching up.
    expect(feed(repeat(9000, 14)), isEmpty);
  });

  test('a stream that cannot go lower raises its own threshold', () {
    guard.onLoad();
    // Normal-latency stream (or a slow network): the floor is 6 s.
    final jumps = feed([...repeat(6000, 40), ...repeat(8000, 30)]);
    expect(guard.thresholdMs, 6000 + LiveEdgeGuard.marginMs);
    expect(jumps, isEmpty);

    expect(feed(repeat(9000, 12)), [11]);
  });

  test('ignores samples taken while paused or buffering', () {
    guard.onLoad();
    feed(repeat(2300, 20));
    expect(feed(repeat(20000, 30), playing: false), isEmpty);
    // Playing again: drift has to last on its own before a jump.
    expect(feed(repeat(7000, 5)), isEmpty);
  });

  /// Drives the guard like the store does: a jump reloads the stream
  /// (onLoad), which holds [liveMs] for [holdSeconds] after the load and
  /// then drifts to [driftMs]. Returns the seconds at which it jumped.
  List<int> simulate({
    required int minutes,
    int liveMs = 2300,
    int driftMs = 7000,
    required int holdSeconds,
  }) {
    guard.onLoad();
    final jumps = <int>[];
    var sinceLoad = 0;
    for (var second = 1; second <= minutes * 60; second++) {
      now = now.add(const Duration(seconds: 1));
      sinceLoad++;
      final ms = sinceLoad <= holdSeconds ? liveMs : driftMs;
      if (guard.onSample(ms, playing: true)) {
        jumps.add(second);
        guard.onLoad();
        sinceLoad = 0;
      }
    }
    return jumps;
  }

  test('a network that cannot hold low latency is not reloaded forever', () {
    // Every jump reaches the live edge and drifts back right after the
    // settle time: 40 minutes must not mean a reload a minute.
    final jumps = simulate(minutes: 40, holdSeconds: 16);

    expect(jumps.length, LiveEdgeGuard.maxRelapses);
    expect(guard.stopped, isTrue);
  });

  test('a relapse doubles the wait before the next jump', () {
    final jumps = simulate(minutes: 10, holdSeconds: 16);

    expect(jumps, hasLength(2));
    expect(
      jumps[1] - jumps[0],
      greaterThanOrEqualTo(LiveEdgeGuard.cooldown.inSeconds * 2),
    );
  });

  test('jumps that hold keep working for the whole session', () {
    // A stall now and then (every 10 minutes): each jump fixes it.
    final jumps = simulate(minutes: 45, holdSeconds: 600);

    expect(jumps, hasLength(4));
    expect(guard.stopped, isFalse);
  });

  test('a manual refresh lets a stopped guard try again', () {
    simulate(minutes: 20, holdSeconds: 16);
    expect(guard.stopped, isTrue);

    guard.reset();
    guard.onLoad();
    expect(guard.stopped, isFalse);
    expect(feed([...repeat(2300, 20), ...repeat(7000, 11)]), [31]);
  });

  test('after the app comes back a late sample jumps at once', () {
    guard.onLoad();
    feed(repeat(2300, 20));

    guard.expedite();
    expect(feed([12000]), [1]);
  });

  test('expedite waits for a sample it can act on', () {
    guard.onLoad();
    feed(repeat(2300, 20));

    // Back in the app while the player is still buffering.
    guard.expedite();
    expect(feed([12000], playing: false), isEmpty);
    expect(feed([12000]), [1]);
  });

  test('expedite has no effect on a stream at the live edge', () {
    guard.onLoad();
    feed(repeat(2300, 20));

    guard.expedite();
    expect(feed([2500]), isEmpty);
    // Only the next sample was expedited.
    expect(feed(repeat(7000, 5)), isEmpty);
  });

  test('without a measured floor nothing happens', () {
    guard.onLoad();
    now = now.add(const Duration(seconds: 30));
    guard.expedite();
    expect(guard.onSample(9000, playing: false), isFalse);
    expect(guard.floorMs, isNull);
  });

  test('a new load measures a new floor', () {
    guard.onLoad();
    feed(repeat(2300, 20));
    expect(guard.floorMs, 2300);

    guard.onLoad();
    expect(guard.floorMs, isNull);
    feed(repeat(4000, 20));
    expect(guard.floorMs, 4000);
  });
}
