import 'dart:collection';

class SlowFrames {
  SlowFrames({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const window = Duration(seconds: 10);
  static const budget = Duration(milliseconds: 16);

  final DateTime Function() _now;
  final _slow = Queue<DateTime>();

  void add(Iterable<Duration> frames) {
    final now = _now();
    for (final frame in frames) {
      if (frame > budget) _slow.add(now);
    }
  }

  int get count {
    final since = _now().subtract(window);
    while (_slow.isNotEmpty && !_slow.first.isAfter(since)) {
      _slow.removeFirst();
    }
    return _slow.length;
  }
}
