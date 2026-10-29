import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/models/community_highlights.dart';

int _pollRank(PollStatus status) => switch (status) {
  PollStatus.active => 0,
  PollStatus.completed || PollStatus.terminated => 1,
  PollStatus.archived => 2,
  PollStatus.unknown => -1,
};

/// The poll after [event]. A late event never moves a poll back (an update
/// after its completion), votes never go down within a status, an archive
/// removes it, and a new poll replaces the old one.
Poll? reducePoll(Poll? current, PollEvent event) {
  final next = event.poll;
  if (event.kind == PollEventKind.archive ||
      next.status == PollStatus.archived) {
    return current == null || current.id == next.id ? null : current;
  }
  if (next.status == PollStatus.unknown) return current;
  if (current == null || current.id != next.id) return next;
  final rank = _pollRank(next.status);
  final currentRank = _pollRank(current.status);
  if (rank < currentRank) return current;
  if (rank == currentRank && next.totalVotes < current.totalVotes) {
    return current;
  }
  return next;
}

int _predictionRank(PredictionStatus status) => switch (status) {
  PredictionStatus.active => 0,
  PredictionStatus.locked => 1,
  PredictionStatus.resolvePending || PredictionStatus.cancelPending => 2,
  PredictionStatus.resolved || PredictionStatus.canceled => 3,
  PredictionStatus.unknown => -1,
};

/// The prediction after [event], with the timestamp of the last applied
/// event. Updates older than [lastTimestamp], or moving the status back,
/// are ignored; another prediction id replaces the current one.
({Prediction? prediction, DateTime? timestamp}) reducePrediction(
  Prediction? current,
  PredictionEvent event, {
  DateTime? lastTimestamp,
}) {
  final next = event.prediction;
  final unchanged = (prediction: current, timestamp: lastTimestamp);
  if (next.status == PredictionStatus.unknown) return unchanged;
  if (current == null || current.id != next.id) {
    return (prediction: next, timestamp: event.timestamp);
  }
  final at = event.timestamp;
  if (at != null && lastTimestamp != null && at.isBefore(lastTimestamp)) {
    return unchanged;
  }
  if (_predictionRank(next.status) < _predictionRank(current.status)) {
    return unchanged;
  }
  return (prediction: next, timestamp: at ?? lastTimestamp);
}

/// The pinned message after [event], and whether its details must be
/// fetched again (an update event carries none).
({PinnedChatMessage? pin, bool refetch}) reducePinned(
  PinnedChatMessage? current,
  ChEvent event,
) => switch (event) {
  PinEvent(:final message) => (pin: message, refetch: false),
  UnpinEvent(:final id) => (
    pin: current?.id == id ? null : current,
    refetch: false,
  ),
  PinUpdateEvent(:final id) => (pin: current, refetch: current?.id == id),
  _ => (pin: current, refetch: false),
};

/// Whether [pin] has reached its end at [now] (Twitch sends nothing then).
bool pinExpired(PinnedChatMessage pin, DateTime now) {
  final end = pin.endsAt;
  return end != null && !now.isBefore(end);
}

/// An outgoing raid, and whether it already left or was called off.
class RaidState {
  const RaidState(this.raid, {this.gone = false, this.cancelled = false});

  final OutgoingRaid raid;
  final bool gone;

  /// Called off before it left: it shows so for a moment, then goes away
  /// (see kRaidCancelledLinger), and never takes the viewer along.
  final bool cancelled;
}

/// The raid of [channelId] after [event]: another channel's raid is
/// ignored, a cancel before it left marks it called off (final: later
/// events of that raid change nothing) and one after removes it, and the
/// repeated "go" events change nothing once it left.
RaidState? reduceRaid(
  RaidState? current,
  RaidEvent event, {
  required String channelId,
}) {
  final raid = event.raid;
  if (raid.sourceId != channelId) return current;
  final same = current != null && current.raid.id == raid.id;
  if (same && current.cancelled) return current;
  return switch (event.kind) {
    RaidEventKind.cancel =>
      !same
          ? current
          : current.gone
          ? null
          : RaidState(current.raid, cancelled: true),
    RaidEventKind.go =>
      same && current.gone ? current : RaidState(raid, gone: true),
    RaidEventKind.update => RaidState(raid, gone: same && current.gone),
  };
}
