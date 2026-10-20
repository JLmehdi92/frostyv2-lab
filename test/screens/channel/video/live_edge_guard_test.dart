import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/live_edge_guard.dart';

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

  test('waits for the cooldown and bounds the jumps per window', () {
    guard.onLoad();
    final jumps = <int>[];
    var second = 0;
    void run(List<int> samples, {bool reload = false}) {
      for (final ms in samples) {
        second++;
        now = now.add(const Duration(seconds: 1));
        if (guard.onSample(ms, playing: true)) {
          jumps.add(second);
          if (reload) guard.onLoad();
        }
      }
    }

    run(repeat(2300, 20));
    // Every jump lands behind again at once (the network cannot hold it):
    // the floor stays low because the first seconds after each load reach
    // 2.3 s before drifting.
    for (var i = 0; i < 8; i++) {
      run([...repeat(2300, 16), ...repeat(7000, 60)], reload: true);
    }

    expect(jumps.length, LiveEdgeGuard.maxJumpsPerWindow);
    for (var i = 1; i < jumps.length; i++) {
      expect(
        jumps[i] - jumps[i - 1],
        greaterThanOrEqualTo(LiveEdgeGuard.cooldown.inSeconds),
      );
    }
  });

  test('the jump budget comes back after the window', () {
    guard.onLoad();
    feed(repeat(2300, 20));
    var count = 0;
    for (var i = 0; i < 3; i++) {
      count += feed([...repeat(7000, 11), ...repeat(2300, 60)]).length;
    }
    expect(count, 3);
    expect(feed(repeat(7000, 11)), isEmpty, reason: 'budget used');

    now = now.add(LiveEdgeGuard.budgetWindow);
    expect(feed(repeat(7000, 11)), [11]);
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
