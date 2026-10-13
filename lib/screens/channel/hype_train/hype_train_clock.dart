import 'package:clock/clock.dart';

/// Twitch's time, estimated from realtime notification timestamps, so the
/// countdown matches the server even when the phone clock is off.
class ServerClock {
  /// Offsets beyond this are not a skew but a broken timestamp.
  static const _maxOffset = Duration(minutes: 10);
  static const _samples = 5;

  final _offsets = <Duration>[];
  var _offset = Duration.zero;

  Duration get offset => _offset;

  void observe(DateTime serverTime) {
    final offset = serverTime.difference(clock.now());
    if (offset.abs() > _maxOffset) return;
    _offsets.add(offset);
    if (_offsets.length > _samples) _offsets.removeAt(0);
    final sorted = [..._offsets]..sort();
    _offset = sorted[sorted.length ~/ 2];
  }

  DateTime now() => clock.now().add(_offset);
}
