import 'dart:async';

import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/models/raid_arrival.dart';

/// Leaving a channel with its raid: one departure at a time, the switch
/// after a delay (the card's hit and the "Heading to" overlay), and the
/// checks run again at the switch.
class RaidDeparture {
  RaidDeparture({
    required this.canLeave,
    required this.onSwitch,
    required this.onChanged,
  });

  /// Whether the screen may leave now (on screen, on top, not in PiP).
  final bool Function() canLeave;

  /// Replaces the channel with [raid]'s target.
  final void Function(OutgoingRaid raid, RaidArrival arrival) onSwitch;

  /// [current] changed (started, or called off at the switch).
  final void Function() onChanged;

  Timer? _timer;
  RaidArrival? _current;
  var _disposed = false;

  /// The raid being followed, while the departure plays.
  RaidArrival? get current => _current;

  /// Starts leaving with [raid] for the switch in [delay]; false while one
  /// is already under way (the raid leaving after "Go now", a second tap).
  bool start(
    OutgoingRaid raid, {
    required String fromName,
    String? fromLogin,
    required Duration delay,
    required DateTime now,
  }) {
    if (_disposed || _current != null) return false;
    final arrival = RaidArrival.leaving(
      raid,
      fromName: fromName,
      fromLogin: fromLogin,
      at: now,
    );
    _current = arrival;
    onChanged();
    _timer = Timer(delay, () {
      _timer = null;
      if (_disposed) return;
      if (!canLeave()) {
        _current = null;
        onChanged();
        return;
      }
      onSwitch(raid, arrival);
    });
    return true;
  }

  /// Stops the departure under way (the raid was called off): no switch,
  /// and [current] clears at once.
  void callOff() {
    if (_current == null) return;
    _timer?.cancel();
    _timer = null;
    _current = null;
    onChanged();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
