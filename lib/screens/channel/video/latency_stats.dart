import 'dart:collection';

import 'package:onset/l10n/l10n.dart';

/// Formats a latency in milliseconds with 0.1 s precision (e.g. `2.3s`).
///
/// Uses integer tenths so the output never depends on floating point
/// rounding quirks. Negative values are clamped to zero.
String formatLatency(int ms) {
  final tenths = (ms.clamp(0, 1 << 31) / 100).round();
  return '${tenths ~/ 10}.${tenths % 10}s';
}

/// A latency as the players hold it ("2.3s" from [formatLatency], "2s"
/// from the web player) written in [l]'s language: "2.3s", « 2,3 s ». Any
/// other text (a placeholder, a reconnect count) stays as it is.
String displayLatency(String latency, AppLocalizations l) {
  final match = _seconds.firstMatch(latency);
  if (match == null) return latency;
  return l.latencySeconds(value: localDecimal(match[1]!));
}

final _seconds = RegExp(r'^(\d+(?:\.\d+)?)s$');

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

/// Formats a bitrate in bits per second in [l]'s language ("4.2 Mbps",
/// « 4,2 Mbit/s »), or `—` when unknown.
String formatBitrate(int? bps, AppLocalizations l) {
  if (bps == null || bps <= 0) return '—';
  if (bps >= 1000000) {
    return l.latencyMegabits(
      value: localDecimal((bps / 1000000).toStringAsFixed(1)),
    );
  }
  return l.latencyKilobits(value: (bps / 1000).ceil());
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
