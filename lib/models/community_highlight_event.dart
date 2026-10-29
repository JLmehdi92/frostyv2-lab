import 'dart:convert';

import 'package:onset/models/community_highlights.dart';

/// The Hermes topics carrying community highlights, per channel.
enum HighlightTopic {
  polls('polls'),
  predictions('predictions-channel-v1'),
  pinned('pinned-chat-updates-v1'),
  raid('raid');

  const HighlightTopic(this.prefix);

  final String prefix;

  /// The topic for [channelId] (`polls.123`).
  String topicFor(String channelId) => '$prefix.$channelId';
}

/// A realtime community highlight event. [ChEvent.parse] never throws.
sealed class ChEvent {
  const ChEvent();

  /// Parses the `pubsub` string of a [topic] notification.
  static ChEvent parse(HighlightTopic topic, String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const ChUnknown();
    }
    final map = chMap(decoded);
    final type = map?['type'];
    if (map == null || type is! String) return const ChUnknown();
    try {
      return switch (topic) {
        HighlightTopic.polls => _poll(type, chMap(map['data'])),
        HighlightTopic.predictions => _prediction(chMap(map['data'])),
        HighlightTopic.pinned => _pinned(type, chMap(map['data'])),
        HighlightTopic.raid => _raid(type, map['raid']),
      };
    } catch (_) {
      // Shapes are checked field by field; this is a last resort.
      return const ChUnknown();
    }
  }

  static ChEvent _poll(String type, Map<dynamic, dynamic>? data) {
    final poll = Poll.fromPubsub(data?['poll']);
    if (poll == null) return const ChUnknown();
    final kind = switch (type) {
      'POLL_CREATE' => PollEventKind.create,
      'POLL_UPDATE' => PollEventKind.update,
      'POLL_COMPLETE' => PollEventKind.complete,
      'POLL_TERMINATE' => PollEventKind.terminate,
      'POLL_ARCHIVE' => PollEventKind.archive,
      _ => null,
    };
    return kind == null ? const ChUnknown() : PollEvent(kind, poll);
  }

  static ChEvent _prediction(Map<dynamic, dynamic>? data) {
    final prediction = Prediction.fromPubsub(data?['event']);
    if (prediction == null) return const ChUnknown();
    return PredictionEvent(prediction, timestamp: chDate(data?['timestamp']));
  }

  static ChEvent _pinned(String type, Map<dynamic, dynamic>? data) {
    switch (type) {
      case 'pin-message':
        final message = PinnedChatMessage.fromPubsub(data);
        return message == null ? const ChUnknown() : PinEvent(message);
      case 'update-message':
        final id = chString(data?['id'], max: 64);
        return id == null ? const ChUnknown() : PinUpdateEvent(id);
      case 'unpin-message':
        final id = chString(data?['id'], max: 64);
        return id == null ? const ChUnknown() : UnpinEvent(id);
    }
    return const ChUnknown();
  }

  static ChEvent _raid(String type, Object? node) {
    final raid = OutgoingRaid.fromPubsub(node);
    if (raid == null) return const ChUnknown();
    final kind = switch (type) {
      'raid_update_v2' || 'raid_update' => RaidEventKind.update,
      'raid_go_v2' || 'raid_go' => RaidEventKind.go,
      'raid_cancel_v2' || 'raid_cancel' => RaidEventKind.cancel,
      _ => null,
    };
    return kind == null ? const ChUnknown() : RaidEvent(kind, raid);
  }
}

enum PollEventKind { create, update, complete, terminate, archive }

final class PollEvent extends ChEvent {
  const PollEvent(this.kind, this.poll);

  final PollEventKind kind;
  final Poll poll;
}

final class PredictionEvent extends ChEvent {
  const PredictionEvent(this.prediction, {this.timestamp});

  final Prediction prediction;

  /// When Twitch emitted it (orders updates that arrive out of order).
  final DateTime? timestamp;
}

final class PinEvent extends ChEvent {
  const PinEvent(this.message);

  final PinnedChatMessage message;
}

/// The pin changed (its end, usually); the event carries no details.
final class PinUpdateEvent extends ChEvent {
  const PinUpdateEvent(this.id);

  final String id;
}

final class UnpinEvent extends ChEvent {
  const UnpinEvent(this.id);

  final String id;
}

enum RaidEventKind { update, go, cancel }

final class RaidEvent extends ChEvent {
  const RaidEvent(this.kind, this.raid);

  final RaidEventKind kind;
  final OutgoingRaid raid;
}

/// Anything unreadable or not shown.
final class ChUnknown extends ChEvent {
  const ChUnknown();
}
