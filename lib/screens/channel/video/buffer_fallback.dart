import 'package:clock/clock.dart';

/// The safety net of Ultra buffering, with auto latency on: when a stream
/// on Ultra rebuffers [stalls] times within [window], the streams opened in
/// the next [holdFor] use Standard buffering.
///
/// It never touches the stream that stalled: the buffer profile is fixed
/// when the player is created, and changing it would mean reloading the
/// picture. The saved setting is not changed either: once the hold ends,
/// Ultra comes back by itself. Kept in memory only, so a restart of the app
/// also tries Ultra again.
class BufferFallback {
  BufferFallback({DateTime Function()? now}) : _now = now ?? clock.now;

  /// The one the app's live players share.
  static final shared = BufferFallback();

  /// Rebuffers that trip it...
  static const stalls = 2;

  /// ...within this long.
  static const window = Duration(seconds: 60);

  /// How long the next streams use Standard: long enough for a bad network
  /// spell, short enough that a good one gets Ultra back the same evening.
  static const holdFor = Duration(minutes: 30);

  final DateTime Function() _now;
  final _recent = <DateTime>[];
  DateTime? _until;

  /// Until when new streams use Standard, or null when they use Ultra.
  DateTime? get until {
    final until = _until;
    if (until == null || !_now().isBefore(until)) return null;
    return until;
  }

  bool get active => until != null;

  /// A stream playing on Ultra rebuffered; true when this one tripped it.
  bool onUltraRebuffer() {
    final now = _now();
    _recent
      ..removeWhere((at) => now.difference(at) > window)
      ..add(now);
    if (_recent.length < stalls) return false;
    _recent.clear();
    _until = now.add(holdFor);
    return true;
  }
}
