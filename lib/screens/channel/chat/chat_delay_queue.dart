/// Chat payloads held back so chat matches a video that is behind live.
///
/// Payloads leave in arrival order, each once the current delay has passed
/// since it arrived. The delay is read when flushing, not when a payload
/// arrives: it follows the measured video latency, and when it shrinks (the
/// video caught up with the live edge) whatever is now due leaves at once,
/// oldest first, instead of a later message overtaking an earlier one or
/// the chat staying frozen for the old delay. Order matters beyond looks: a
/// deletion or a timeout must never reach the chat before the message it
/// acts on.
class ChatDelayQueue {
  final _pending = <_Delayed>[];

  bool get isEmpty => _pending.isEmpty;

  /// Holds [callback], which arrived at [now].
  void add(void Function() callback, {required DateTime now}) =>
      _pending.add(_Delayed(now, callback));

  /// Releases, in arrival order, every payload that arrived at least
  /// [delay] before [now].
  void flushDue(DateTime now, Duration delay) {
    final cutoff = now.subtract(delay);
    var due = 0;
    while (due < _pending.length && !_pending[due].arrivedAt.isAfter(cutoff)) {
      due++;
    }
    if (due == 0) return;
    // Taken out before running: a callback may enqueue more.
    final ready = _pending.sublist(0, due);
    _pending.removeRange(0, due);
    for (final delayed in ready) {
      delayed.callback();
    }
  }

  /// Releases everything at once, in arrival order (the delay was turned
  /// off, or the video hidden).
  void flushAll() {
    if (_pending.isEmpty) return;
    final ready = List.of(_pending);
    _pending.clear();
    for (final delayed in ready) {
      delayed.callback();
    }
  }

  /// Drops everything (the connection that sent it is gone).
  void clear() => _pending.clear();
}

class _Delayed {
  const _Delayed(this.arrivedAt, this.callback);

  final DateTime arrivedAt;
  final void Function() callback;
}
