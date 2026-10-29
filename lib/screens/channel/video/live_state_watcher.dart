import 'dart:async';

import 'package:onset/services/realtime/twitch_eventsub_client.dart';

/// What a channel's live state did, as EventSub tells it.
enum LiveChange {
  online,

  /// Listening again after a gap: a change may have been missed.
  maybeMissed,
}

final _numericId = RegExp(r'^[0-9]{1,20}$');

/// Pushes a channel going live (EventSub `stream.online`, which needs a
/// logged-in viewer but no scope), so an offline player restarts without
/// waiting for a poll. Going offline is left to the player, which sees it
/// first (and each topic costs from a budget of 10 per connection).
class LiveStateWatcher {
  LiveStateWatcher({
    required EventSubHandle Function(EventSubTopic topic) listen,
    required String broadcasterId,
    required void Function(LiveChange change) onChange,
  }) {
    if (!_numericId.hasMatch(broadcasterId)) {
      throw ArgumentError.value(broadcasterId, 'broadcasterId');
    }
    _handle = listen(
      EventSubTopic('stream.online', '1', {
        'broadcaster_user_id': broadcasterId,
      }),
    );
    _events = _handle.events.listen(
      (event) => switch (event) {
        EventSubData() => onChange(LiveChange.online),
        EventSubListening(afterGap: true) => onChange(LiveChange.maybeMissed),
        _ => null,
      },
    );
  }

  late final EventSubHandle _handle;
  late final StreamSubscription<EventSubTopicEvent> _events;

  void dispose() {
    _handle.cancel();
    unawaited(_events.cancel());
  }
}
