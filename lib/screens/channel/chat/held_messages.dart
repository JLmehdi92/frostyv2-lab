import 'dart:async';

import 'package:onset/l10n/l10n.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';

final _numericId = RegExp(r'^[0-9]{1,20}$');

/// The longest part of a held message quoted in a notice.
const _maxQuote = 100;

/// Tells the viewer what the moderators decided about their messages that
/// AutoMod held (EventSub `channel.chat.user_message_update`, scope
/// `user:read:chat`). IRC only says a message is being checked, never what
/// came of it.
class HeldMessageWatcher {
  HeldMessageWatcher({
    required EventSubHandle Function(EventSubTopic topic) listen,
    required String broadcasterId,
    required String userId,
    required void Function(String notice) onNotice,
  }) : _userId = userId,
       _onNotice = onNotice {
    for (final id in [broadcasterId, userId]) {
      if (!_numericId.hasMatch(id)) throw ArgumentError.value(id);
    }
    _handle = listen(
      EventSubTopic('channel.chat.user_message_update', '1', {
        'broadcaster_user_id': broadcasterId,
        'user_id': userId,
      }),
    );
    _events = _handle.events.listen((event) {
      if (event case EventSubData(:final event)) _onUpdate(event);
    });
  }

  final String _userId;
  final void Function(String notice) _onNotice;
  late final EventSubHandle _handle;
  late final StreamSubscription<EventSubTopicEvent> _events;

  void _onUpdate(Map<String, Object?> event) {
    if (event['user_id'] != _userId) return;
    final status = switch (event['status']) {
      final String status
          when const {'approved', 'denied', 'invalid'}.contains(status) =>
        status,
      _ => null,
    };
    if (status == null) return;
    // A line put in the chat: worded in the language on screen now.
    final l = L10n.current;
    final decision = l.chatHeldDecision(decision: status);
    final quote = switch (event['message']) {
      {'text': final String text} => whisperPreview(text),
      _ => '',
    };
    if (quote.isEmpty) {
      _onNotice('$decision.');
    } else if (quote.runes.length > _maxQuote) {
      // By code point, so an emoji is not cut in half.
      final cut = String.fromCharCodes(quote.runes.take(_maxQuote));
      _onNotice(l.chatHeldQuoted(decision: decision, quote: '$cut…'));
    } else {
      _onNotice(l.chatHeldQuoted(decision: decision, quote: quote));
    }
  }

  void dispose() {
    _handle.cancel();
    unawaited(_events.cancel());
  }
}
