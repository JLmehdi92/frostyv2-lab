import 'dart:collection';

import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';

/// Realtime events waiting for the presenter, which shows them one at a
/// time. Bursts are coalesced so the banner never falls far behind.
class HtEventQueue {
  /// Beyond this, the oldest event is dropped.
  static const maxLength = 100;

  /// From this length on, small progressions coalesce.
  static const _burst = 5;

  final _events = ListQueue<HypeTrainEvent>();
  int? _mergeLevel;

  int get length => _events.length;

  void enqueue(HypeTrainEvent event) {
    switch (event) {
      case HtProgressionEvent(isLarge: false)
          when _events.length >= _burst &&
              _events.last is HtProgressionEvent &&
              !(_events.last as HtProgressionEvent).isLarge:
        // Progress is cumulative: the newest replaces the queued one.
        _events
          ..removeLast()
          ..addLast(event);
        return;
      case HtConductorEvent(:final conductor):
        final events = _events.toList();
        final index = events.indexWhere(
          (e) =>
              e is HtConductorEvent && e.conductor.source == conductor.source,
        );
        if (index != -1) {
          events[index] = event;
          _events
            ..clear()
            ..addAll(events);
          return;
        }
      case HtMergeEvent(:final train):
        _mergeLevel = train.level;
      case HtLevelUpEvent(:final progress, :final timeToExpire)
          when progress.level.value == _mergeLevel:
        // The merge already announced this level.
        _add(
          HtProgressionEvent(
            sequenceId: progress.total,
            action: const HtAction('UNKNOWN'),
            source: HtSource.unknown,
            quantity: 0,
            isLarge: false,
            progress: progress,
            expiresAt: timeToExpire,
          ),
        );
        return;
      case _:
        break;
    }
    _add(event);
  }

  void _add(HypeTrainEvent event) {
    _events.addLast(event);
    while (_events.length > maxLength) {
      _events.removeFirst();
    }
  }

  HypeTrainEvent? pop() => _events.isEmpty ? null : _events.removeFirst();

  /// Everything still queued, oldest first; the queue is empty afterwards.
  List<HypeTrainEvent> drainForEnd() {
    final events = _events.toList();
    clear();
    return events;
  }

  void clear() {
    _events.clear();
    _mergeLevel = null;
  }
}
