import 'dart:async';

import 'package:frosty/services/realtime/twitch_eventsub_client.dart';

/// What a channel's live state did, as EventSub tells it.
enum LiveChange {
  online,
  offline,

  /// Listening again after a gap: a change may have been missed.
  maybeMissed,
}

final _numericId = RegExp(r'^[0-9]{1,20}$');

/// Pushes a channel going live or offline (EventSub `stream.online` and
/// `stream.offline`, which need a logged-in viewer but no scope), so the
/// player does not wait for a poll.
class LiveStateWatcher {
  LiveStateWatcher({
    required EventSubHandle Function(EventSubTopic topic) listen,
    required String broadcasterId,
    required void Function(LiveChange change) onChange,
  }) {
    if (!_numericId.hasMatch(broadcasterId)) {
      throw ArgumentError.value(broadcasterId, 'broadcasterId');
    }
    for (final (type, change) in [
      ('stream.online', LiveChange.online),
      ('stream.offline', LiveChange.offline),
    ]) {
      final handle = listen(
        EventSubTopic(type, '1', {'broadcaster_user_id': broadcasterId}),
      );
      _handles.add(handle);
      _events.add(
        handle.events.listen(
          (event) => switch (event) {
            EventSubData() => onChange(change),
            // Once per gap is enough: the online topic speaks for both.
            EventSubListening(afterGap: true) when type == 'stream.online' =>
              onChange(LiveChange.maybeMissed),
            _ => null,
          },
        ),
      );
    }
  }

  final _handles = <EventSubHandle>[];
  final _events = <StreamSubscription<EventSubTopicEvent>>[];

  void dispose() {
    for (final handle in _handles) {
      handle.cancel();
    }
    for (final events in _events) {
      unawaited(events.cancel());
    }
  }
}
