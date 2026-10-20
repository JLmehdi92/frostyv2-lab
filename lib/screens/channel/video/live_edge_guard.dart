import 'package:clock/clock.dart';

/// Decides when the native live player has drifted so far behind the live
/// edge that it should jump back to it (by reloading the stream, which
/// starts at the edge).
///
/// The IVS player keeps itself close to live with its speed-up catch-up,
/// like the official app. What that does not undo is a larger buffer
/// target: the SDK's low-latency buffer control has a 1 s
/// `rebufferPenaltySeconds` and a 6 s `minBufferCeilingSeconds` (defaults
/// read from the IVS config schema in the decompiled Twitch app), i.e. the
/// target can grow after stalls, and a network drop the player resumes
/// from leaves it behind by as long as it lasted. Chat (sent by viewers
/// ~2 s behind live) then runs ahead of the picture.
///
/// The guard is a safety net on top of the catch-up, not a replacement:
/// it measures the lowest latency this load reached (the floor the stream
/// and the network allow) and only acts when the latency stays well above
/// it, rarely, and never in a loop.
class LiveEdgeGuard {
  LiveEdgeGuard({DateTime Function()? now}) : _now = now ?? clock.now;

  /// Never jump below this: a healthy low-latency stream reads ~2–3.5 s on
  /// the native player (probes: usher's newest full segment is 0.3–2.8 s
  /// old and its prefetch parts complete 0.0–0.9 s after their end, plus
  /// the IVS 1 s low-latency buffer), and the speed-up catch-up handles
  /// small drifts by itself.
  static const minThresholdMs = 5000;

  /// How far above this load's floor the latency may sit before a jump,
  /// e.g. two rebuffer penalties and a half.
  static const marginMs = 2500;

  /// Samples right after a load only measure the floor: the speed-up is
  /// still bringing the start position to the live edge.
  static const settle = Duration(seconds: 15);

  /// The drift has to last this long: a stall the speed-up is about to
  /// absorb must not cost a reload.
  static const sustain = Duration(seconds: 10);

  /// A sample gap longer than this means the ticker stopped (app in the
  /// background, player recreated): the drift has to be seen again.
  static const maxSampleGap = Duration(seconds: 3);

  /// Minimum time between two jumps, and at most [maxJumpsPerWindow] jumps
  /// per [budgetWindow], so a network that cannot hold low latency gets a
  /// few tries and is then left to the speed-up.
  static const cooldown = Duration(seconds: 60);
  static const budgetWindow = Duration(minutes: 10);
  static const maxJumpsPerWindow = 3;

  final DateTime Function() _now;

  DateTime? _loadedAt;
  DateTime? _lastSampleAt;
  DateTime? _overSince;
  int? _floorMs;
  var _expedited = false;
  final _jumps = <DateTime>[];

  /// Lowest latency measured while playing since the last load.
  int? get floorMs => _floorMs;

  /// Latency above which drift starts counting.
  int get thresholdMs {
    final floor = _floorMs;
    if (floor == null) return minThresholdMs;
    final relative = floor + marginMs;
    return relative > minThresholdMs ? relative : minThresholdMs;
  }

  /// A new source was loaded (it starts at the live edge): measure again.
  void onLoad() {
    _loadedAt = _now();
    _floorMs = null;
    _overSince = null;
    _expedited = false;
  }

  /// The app came back to the foreground (or left picture-in-picture): a
  /// drift seen on the next sample taken while playing (after the settle
  /// time) jumps at once instead of waiting for [sustain].
  void expedite() => _expedited = true;

  /// Records one latency sample; true when the player should jump to the
  /// live edge now.
  bool onSample(int latencyMs, {required bool playing}) {
    final now = _now();
    final last = _lastSampleAt;
    _lastSampleAt = now;
    if (last != null && now.difference(last) > maxSampleGap) {
      _overSince = null;
    }

    if (!playing || latencyMs < 0) {
      _overSince = null;
      return false;
    }

    final floor = _floorMs;
    if (floor == null || latencyMs < floor) _floorMs = latencyMs;

    final loadedAt = _loadedAt;
    if (loadedAt != null && now.difference(loadedAt) < settle) return false;

    // The first sample that can be judged answers an [expedite].
    final expedited = _expedited;
    _expedited = false;

    if (latencyMs <= thresholdMs) {
      _overSince = null;
      return false;
    }

    final overSince = _overSince ??= now;
    if (!expedited && now.difference(overSince) < sustain) return false;
    if (!_canJump(now)) return false;

    _jumps.add(now);
    _overSince = null;
    return true;
  }

  bool _canJump(DateTime now) {
    _jumps.removeWhere((at) => now.difference(at) >= budgetWindow);
    if (_jumps.length >= maxJumpsPerWindow) return false;
    return _jumps.isEmpty || now.difference(_jumps.last) >= cooldown;
  }
}
