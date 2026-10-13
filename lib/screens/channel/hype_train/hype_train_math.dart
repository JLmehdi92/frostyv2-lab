import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';

/// Where a level-gated reward (treasure discount, community emotes) stands.
enum HtUnlockState { locked, oneLevelAway, unlockNow, unlocked }

/// Progress through the current level, 0–100 (in-level values, verified).
int percent(HtProgress progress) {
  if (progress.goal <= 0) return 0;
  return (progress.value / progress.goal * 100).round().clamp(0, 100);
}

bool isFinalLevel(HypeTrainExecution train) {
  final maxLevel = train.config.maxLevel;
  return maxLevel != null && train.level >= maxLevel;
}

/// Tier 1 subs or Bits that complete the current level: the whole in-level
/// goal, like Twitch's "about 10 subs completes this level" (D6).
({int subs, int bits}) levelTarget(HypeTrainExecution train) {
  final goal = train.progress.goal;
  if (goal <= 0) return (subs: 0, bits: 0);
  final perSub = train.config.conversionRates['TIER_1_SUB'] ?? 500;
  final perBit = train.config.conversionRates['CHEER'] ?? 1;
  return (subs: (goal / perSub).ceil(), bits: (goal / perBit).ceil());
}

/// The [n] channels of a shared train that contributed most, with their
/// share of the combined total in percent.
List<(HtSharedChannel, int)> topShares(HtShared shared, {int n = 3}) {
  final channels = [
    for (final channel in shared.channels)
      if ((channel.progress?.total ?? 0) > 0) channel,
  ];
  final sum = channels.fold(0, (a, c) => a + c.progress!.total);
  if (sum <= 0) return const [];
  channels.sort((a, b) => b.progress!.total.compareTo(a.progress!.total));
  return [
    for (final channel in channels.take(n))
      (channel, (channel.progress!.total / sum * 100).round()),
  ];
}

/// How close [total] is to the channel's record train, 0–100.
int athPercent(int total, HtAth ath) {
  if (ath.total <= 0) return 0;
  return (total / ath.total * 100).round().clamp(0, 100);
}

/// Bits cheered and subscriptions given over the whole train.
({int bits, int subs}) endTotals(List<HtTotal> totals) {
  var bits = 0;
  var subs = 0;
  for (final total in totals) {
    switch (total.source) {
      case HtSource.bits:
        bits += total.quantity;
      case HtSource.subs:
        subs += total.quantity;
      case _:
        break;
    }
  }
  return (bits: bits, subs: subs);
}

HtUnlockState _unlockState(int level, int threshold) {
  if (level == threshold) return HtUnlockState.unlockNow;
  if (level > threshold) return HtUnlockState.unlocked;
  if (level + 1 == threshold) return HtUnlockState.oneLevelAway;
  return HtUnlockState.locked;
}

/// The treasure discount, or null for a train without one.
HtUnlockState? treasureState(HypeTrainExecution train) {
  final treasure = train.treasure;
  if (treasure == null) return null;
  return _unlockState(train.level, treasure.threshold);
}

/// The community emotes, or null for a train without them.
HtUnlockState? communityState(HypeTrainExecution train) {
  final community = train.community;
  if (community == null) return null;
  return _unlockState(train.level, community.threshold);
}
