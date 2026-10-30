import 'dart:collection';

/// Formats a latency in milliseconds with 0.1 s precision (e.g. `2.3s`).
///
/// Uses integer tenths so the output never depends on floating point
/// rounding quirks. Negative values are clamped to zero.
String formatLatency(int ms) {
  final tenths = (ms.clamp(0, 1 << 31) / 100).round();
  return '${tenths ~/ 10}.${tenths % 10}s';
}

/// Whole-second chat delay derived from the measured stream latency.
///
/// The chat delay sync only ever moves in whole seconds so the delayed chat
/// queue is not rebuilt on every latency tick.
int chatDelaySecondsFromLatency(int ms) => (ms / 1000).clamp(0, 60).round();

/// [chatDelaySecondsFromLatency] that keeps [current] until the latency is
/// clearly nearer another whole second ([marginMs] past the half second).
///
/// Auto latency holds a stream around its target, which can sit near a half
/// second (Ultra aims at 1.3 s and lets it wander to 1.7 s): plain rounding
/// would then move the chat delay between two seconds on every swing.
int chatDelaySecondsWithHysteresis(int ms, int? current, {int marginMs = 150}) {
  final rounded = chatDelaySecondsFromLatency(ms);
  if (current == null || rounded == current) return rounded;
  return (ms - current * 1000).abs() >= 500 + marginMs ? rounded : current;
}

/// Formats a bitrate in bits per second, or `—` when unknown.
String formatBitrate(int? bps) {
  if (bps == null || bps <= 0) return '—';
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  return '${(bps / 1000).ceil()} kbps';
}

/// Rolling window of latency samples (one per second from the native player)
/// used to report median / p90 / min / max over the last few minutes.
class LatencySampler {
  LatencySampler({this.capacity = 300});

  /// Maximum number of samples kept; the default is five minutes at 1 Hz.
  final int capacity;

  final _samples = Queue<int>();

  int get count => _samples.length;

  void add(int ms) {
    _samples.addLast(ms);
    while (_samples.length > capacity) {
      _samples.removeFirst();
    }
  }

  void reset() => _samples.clear();

  int? get min => _sorted()?.first;

  int? get max => _sorted()?.last;

  /// Upper median (the higher of the two middle values for even counts).
  int? get median {
    final sorted = _sorted();
    if (sorted == null) return null;
    return sorted[sorted.length ~/ 2];
  }

  /// 90th percentile using the nearest-rank method.
  int? get p90 {
    final sorted = _sorted();
    if (sorted == null) return null;
    final rank = (0.9 * sorted.length).ceil();
    return sorted[rank - 1];
  }

  List<int>? _sorted() {
    if (_samples.isEmpty) return null;
    return _samples.toList()..sort();
  }
}
