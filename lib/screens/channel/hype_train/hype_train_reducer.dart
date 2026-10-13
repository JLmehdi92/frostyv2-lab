import 'package:flutter/foundation.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';

/// A change of the channel's record (all-time high) state worth showing.
enum HtAthTransition { none, approaching, reached }

/// What [applyEvent] did, with what the presenter needs to animate it.
@immutable
class HtApplyResult {
  const HtApplyResult(
    this.train, {
    this.applied = true,
    this.ignoredReason,
    this.levelChangedFrom,
    this.athTransition = HtAthTransition.none,
    this.treasureUnlockedNow = false,
    this.communityUnlockedNow = false,
    this.deferredNextLevel = false,
    this.endTotals = const [],
    this.endRewards = const [],
    this.mergedFrom,
    this.previousChannels = const [],
    this.joiningChannels = const [],
    this.continuesIn,
  });

  const HtApplyResult.ignored(this.train, String this.ignoredReason)
    : applied = false,
      levelChangedFrom = null,
      athTransition = HtAthTransition.none,
      treasureUnlockedNow = false,
      communityUnlockedNow = false,
      deferredNextLevel = false,
      endTotals = const [],
      endRewards = const [],
      mergedFrom = null,
      previousChannels = const [],
      joiningChannels = const [],
      continuesIn = null;

  /// The train after the event ([identical] to the input when ignored).
  final HypeTrainExecution train;
  final bool applied;
  final String? ignoredReason;

  /// The level before the event, when the event changed it.
  final int? levelChangedFrom;
  final HtAthTransition athTransition;
  final bool treasureUnlockedNow;
  final bool communityUnlockedNow;

  /// A progression of the next level arrived before its level-up (verified
  /// ordering): wait for the level-up, then apply it with `force`.
  final bool deferredNextLevel;

  final List<HtTotal> endTotals;
  final List<HtReward> endRewards;

  /// The progress before a merge (where the level pill counts from).
  final HtProgress? mergedFrom;
  final List<HtUser> previousChannels;
  final List<HtUser> joiningChannels;

  /// Where a shared train goes on after this channel left it.
  final HtUser? continuesIn;
}

/// Applies one realtime [event] to the running [train].
///
/// Pure except for [seenIds], which collects the `trainId:sequenceId` keys
/// of applied progressions so a redelivery is not counted twice. [channelId] picks this channel's
/// entry of a shared train. [force] applies a deferred next-level
/// progression as a level change.
HtApplyResult applyEvent(
  HypeTrainExecution train,
  HypeTrainEvent event, {
  required Set<String> seenIds,
  String? channelId,
  bool force = false,
}) {
  switch (event) {
    case HtProgressionEvent():
      return _progression(train, event, seenIds, channelId, force);
    case HtLevelUpEvent():
      return _levelUp(train, event, channelId);
    case HtConductorEvent(:final conductor):
      final conductors = [...train.conductors];
      final index = conductors.indexWhere((c) => c.source == conductor.source);
      if (index == -1) {
        conductors.insert(0, conductor);
      } else {
        conductors[index] = conductor;
      }
      return HtApplyResult(train.copyWith(conductors: conductors));
    case HtEndEvent():
      return HtApplyResult(
        train.copyWith(endReason: event.reason, endedAt: event.endedAt),
        endTotals: event.totals,
        endRewards: event.rewards,
      );
    case HtStartEvent(train: final next):
      // A late or repeated start must not reset the running train.
      if (next.id == train.id) {
        return HtApplyResult.ignored(train, 'duplicate start');
      }
      return HtApplyResult(next);
    case HtMergeEvent():
      return HtApplyResult(
        event.train,
        levelChangedFrom: event.train.level != train.level ? train.level : null,
        mergedFrom: event.previousProgress ?? train.progress,
        previousChannels: event.previousChannels,
        joiningChannels: event.joiningChannels,
      );
    case HtChannelLeftEvent(:final shouldEnd, :final continuesIn):
      if (shouldEnd) {
        return HtApplyResult(train.copyWith(endReason: HtEndReason.completed));
      }
      return HtApplyResult(train, continuesIn: continuesIn);
    case HtApproachingEvent():
      return HtApplyResult.ignored(train, 'approaching');
    case HtIgnoredEvent() || HtUnknownEvent():
      return HtApplyResult.ignored(train, 'not applicable');
  }
}

HtApplyResult _progression(
  HypeTrainExecution train,
  HtProgressionEvent event,
  Set<String> seenIds,
  String? channelId,
  bool force,
) {
  final key = '${event.trainId ?? train.id}:${event.sequenceId}';
  if (seenIds.contains(key)) {
    return HtApplyResult.ignored(train, 'duplicate');
  }
  // Equal is not stale: the level-up may have come first with the same
  // total, and the progression still names the contributor (verified).
  if (event.sequenceId < train.progress.total) {
    return HtApplyResult.ignored(train, 'stale');
  }
  final level = event.progress.level.value;
  final nextLevel = level == train.level + 1;
  if (nextLevel && !force) {
    return HtApplyResult(train, applied: false, deferredNextLevel: true);
  }
  if (level != train.level && !nextLevel) {
    return HtApplyResult.ignored(train, 'level mismatch');
  }
  seenIds.add(key);

  final shared = _withSharedProgress(train.shared, event.sharedProgress);
  final own = channelId == null ? null : event.sharedProgress?[channelId];
  final progress = own == null
      ? event.progress
      : event.progress.copyWith(athState: own.athState);
  final after = train.copyWith(
    progress: progress,
    expiresAt: event.expiresAt,
    treasure: event.treasure,
    shared: shared,
  );
  return _withTransitions(
    train,
    after,
    levelChangedFrom: nextLevel ? train.level : null,
  );
}

HtApplyResult _levelUp(
  HypeTrainExecution train,
  HtLevelUpEvent event,
  String? channelId,
) {
  final level = event.progress.level.value;
  if (level < train.level || event.progress.total < train.progress.total) {
    return HtApplyResult.ignored(train, 'stale');
  }

  // The level-up carries the whole train in GQL shape: it refreshes the
  // variant details, the shared channels and the config.
  final fresh = event.train;
  var progress = event.progress;
  if (fresh != null && channelId != null) {
    for (final channel in fresh.shared?.channels ?? const <HtSharedChannel>[]) {
      if (channel.user.id == channelId && channel.progress != null) {
        progress = progress.copyWith(athState: channel.progress!.athState);
      }
    }
  }
  final after = train.copyWith(
    progress: progress,
    expiresAt: event.timeToExpire,
    config: fresh?.config,
    ath: fresh?.ath,
    variant: fresh?.variant,
    treasure: fresh?.treasure,
    community: fresh?.community,
    mythic: fresh?.mythic,
    shared: fresh?.shared,
    conductors: fresh != null && fresh.conductors.isNotEmpty
        ? fresh.conductors
        : null,
  );
  return _withTransitions(
    train,
    after,
    levelChangedFrom: level != train.level ? train.level : null,
  );
}

HtApplyResult _withTransitions(
  HypeTrainExecution before,
  HypeTrainExecution after, {
  int? levelChangedFrom,
}) {
  final levelChanged = levelChangedFrom != null;
  final treasure = after.treasure;
  final community = after.community;
  return HtApplyResult(
    after,
    levelChangedFrom: levelChangedFrom,
    athTransition: _athTransition(
      before.progress.athState,
      after.progress.athState,
    ),
    treasureUnlockedNow:
        levelChanged && treasure != null && after.level == treasure.threshold,
    communityUnlockedNow:
        levelChanged && community != null && after.level == community.threshold,
  );
}

HtAthTransition _athTransition(HtAthState before, HtAthState after) {
  bool reached(HtAthState s) =>
      s == HtAthState.reached || s == HtAthState.justReached;
  if (reached(after) && !reached(before)) return HtAthTransition.reached;
  if (after == HtAthState.approaching && before == HtAthState.none) {
    return HtAthTransition.approaching;
  }
  return HtAthTransition.none;
}

/// The shared channels with their progress from a progression event.
HtShared? _withSharedProgress(
  HtShared? shared,
  Map<String, HtProgress>? progress,
) {
  if (shared == null || progress == null) return null;
  return HtShared(
    id: shared.id,
    channels: [
      for (final channel in shared.channels)
        HtSharedChannel(
          user: channel.user,
          progress: progress[channel.user.id] ?? channel.progress,
          ath: channel.ath,
          conductors: channel.conductors,
        ),
    ],
  );
}
