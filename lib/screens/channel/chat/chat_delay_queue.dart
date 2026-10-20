/// Chat payloads held back so chat matches a video that is behind live.
///
/// Each payload is released once its delay has passed, and never before a
/// payload that arrived earlier: when the delay shrinks (the video caught up
/// with the live edge), a later message waits for the earlier ones instead
/// of overtaking them. Order matters beyond looks: a deletion or a timeout
/// must never reach the chat before the message it acts on.
class ChatDelayQueue {
  final _pending = <_Delayed>[];

  bool get isEmpty => _pending.isEmpty;

  /// Holds [callback] for [delay] from [now] (a negative delay is none).
  void add(
    void Function() callback, {
    required DateTime now,
    required Duration delay,
  }) {
    var releaseAt = delay.isNegative ? now : now.add(delay);
    if (_pending.isNotEmpty && releaseAt.isBefore(_pending.last.releaseAt)) {
      releaseAt = _pending.last.releaseAt;
    }
    _pending.add(_Delayed(releaseAt, callback));
  }

  /// Releases, in arrival order, every payload due at [now].
  void flushDue(DateTime now) {
    var due = 0;
    while (due < _pending.length && !_pending[due].releaseAt.isAfter(now)) {
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
  const _Delayed(this.releaseAt, this.callback);

  final DateTime releaseAt;
  final void Function() callback;
}
