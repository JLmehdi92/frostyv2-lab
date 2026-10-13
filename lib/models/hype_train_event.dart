import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frosty/models/hype_train.dart';

/// A realtime message of the `hype-train-events-v2.<channelId>` topic.
@immutable
sealed class HypeTrainEvent {
  const HypeTrainEvent();

  /// Parses the topic's JSON message. Never throws: anything unusable is an
  /// [HtUnknownEvent].
  static HypeTrainEvent parse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const HtUnknownEvent('');
      final type = decoded['type'];
      if (type is! String) return const HtUnknownEvent('');
      final data = decoded['data'];
      return _parse(type, data is Map ? data : const {}) ??
          HtUnknownEvent(type);
    } catch (_) {
      return const HtUnknownEvent('');
    }
  }

  static HypeTrainEvent? _parse(String type, Map data) {
    switch (type) {
      case 'hype-train-approaching':
        final approaching = HypeTrainApproaching.parse(data);
        return approaching == null ? null : HtApproachingEvent(approaching);
      case 'hype-train-start' || 'hype-train-shared-conversion':
        final train = HypeTrainExecution.parse(
          htMap(data, ['hypeTrain', 'hype_train']) ?? data,
        );
        return train == null ? null : HtStartEvent(train);
      case 'hype-train-progression':
        final progress = HtProgress.parse(htMap(data, ['progress']));
        if (progress == null) return null;
        final details =
            htMap(data, ['treasureTrainDetails']) ??
            htMap(data, ['variantTrainDetails']);
        return HtProgressionEvent(
          trainId: htString(data, ['id']),
          sequenceId: htInt(data, ['sequence_id']) ?? progress.total,
          userId: htString(data, ['user_id']),
          login: htString(data, ['user_login']),
          displayName: htString(data, ['user_display_name']),
          profileImageUrl: htCdnUrl(
            htString(data, ['user_profile_image_url']),
          )?.toString(),
          action: HtAction(htString(data, ['action']) ?? 'UNKNOWN'),
          source: htSource(htString(data, ['source'])),
          quantity: htInt(data, ['quantity']) ?? 0,
          isLarge: htBool(data, ['is_large_event']),
          progress: progress,
          expiresAt: htDate(data, ['expires_at']),
          sharedProgress: _sharedProgress(htList(data, ['sharedProgress'])),
          treasure: HtTreasure.parse(details),
        );
      case 'hype-train-level-up':
        final progress = HtProgress.parse(htMap(data, ['progress']));
        final timeToExpire = htDate(data, ['time_to_expire']);
        if (progress == null || timeToExpire == null) return null;
        return HtLevelUpEvent(
          timeToExpire: timeToExpire,
          progress: progress,
          train: HypeTrainExecution.parse(htMap(data, ['hype_train'])),
        );
      case 'hype-train-conductor-update':
        final conductor = HtConductor.parse(data);
        return conductor == null ? null : HtConductorEvent(conductor);
      case 'hype-train-end':
        return HtEndEvent(
          trainId: htString(data, ['id']),
          endedAt: htDate(data, ['ended_at']),
          reason: htEndReason(htString(data, ['ending_reason'])),
          totals: [
            for (final item in htList(data, ['participation_totals']))
              if (item is Map && htInt(item, ['quantity']) != null)
                HtTotal(
                  source: htSource(htString(item, ['source'])),
                  action: HtAction(htString(item, ['action']) ?? 'UNKNOWN'),
                  quantity: htInt(item, ['quantity'])!,
                ),
          ],
          rewards: htRewards(htList(data, ['rewards'])),
        );
      case 'hype-train-shared-merge-trains':
        final train = HypeTrainExecution.parse(htMap(data, ['hypeTrain']));
        if (train == null) return null;
        return HtMergeEvent(
          train: train,
          previousProgress: HtProgress.parse(htMap(data, ['prevProgress'])),
          previousChannels: _users(htList(data, ['prevUsers'])),
          joiningChannels: _users(htList(data, ['joiningUsers'])),
        );
      case 'hype-train-shared-channel-left':
        return HtChannelLeftEvent(
          trainId: htString(data, ['id']),
          continuesIn: HtUser.parse(htMap(data, ['user'])),
          shouldEnd: htBool(data, ['shouldTrainEnd']),
        );
      case 'hype-train-cooldown-expiration' ||
          'hype-train-reward-eligibility' ||
          'hype-train-rewards':
        return HtIgnoredEvent(type);
    }
    return null;
  }

  static List<HtUser> _users(List raw) => [
    for (final u in raw) ?HtUser.parse(u),
  ];

  static Map<String, HtProgress>? _sharedProgress(List raw) {
    final result = <String, HtProgress>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final user = HtUser.parse(htMap(item, ['user']));
      final progress = HtProgress.parse(htMap(item, ['channelProgress']));
      if (user != null && progress != null) result[user.id] = progress;
    }
    return result.isEmpty ? null : result;
  }
}

final class HtApproachingEvent extends HypeTrainEvent {
  const HtApproachingEvent(this.approaching);

  final HypeTrainApproaching approaching;
}

/// A train started (or a shared conversion turned this one into one).
final class HtStartEvent extends HypeTrainEvent {
  const HtStartEvent(this.train);

  final HypeTrainExecution train;
}

final class HtProgressionEvent extends HypeTrainEvent {
  const HtProgressionEvent({
    required this.sequenceId,
    required this.action,
    required this.source,
    required this.quantity,
    required this.isLarge,
    required this.progress,
    this.trainId,
    this.userId,
    this.login,
    this.displayName,
    this.profileImageUrl,
    this.expiresAt,
    this.sharedProgress,
    this.treasure,
  });

  /// The train's id (`data.id` is the train, not the event: verified).
  final String? trainId;

  /// Equals the train total: orders contributions.
  final int sequenceId;
  final String? userId;
  final String? login;
  final String? displayName;
  final String? profileImageUrl;
  final HtAction action;
  final HtSource source;
  final int quantity;
  final bool isLarge;
  final HtProgress progress;
  final DateTime? expiresAt;

  /// Per channel of a shared train.
  final Map<String, HtProgress>? sharedProgress;
  final HtTreasure? treasure;
}

final class HtLevelUpEvent extends HypeTrainEvent {
  const HtLevelUpEvent({
    required this.timeToExpire,
    required this.progress,
    this.train,
  });

  /// When the new level runs out (sent as epoch milliseconds).
  final DateTime timeToExpire;
  final HtProgress progress;
  final HypeTrainExecution? train;
}

final class HtConductorEvent extends HypeTrainEvent {
  const HtConductorEvent(this.conductor);

  final HtConductor conductor;
}

@immutable
class HtTotal {
  const HtTotal({
    required this.source,
    required this.action,
    required this.quantity,
  });

  final HtSource source;
  final HtAction action;
  final int quantity;
}

final class HtEndEvent extends HypeTrainEvent {
  const HtEndEvent({
    required this.reason,
    this.trainId,
    this.endedAt,
    this.totals = const [],
    this.rewards = const [],
  });

  final HtEndReason reason;
  final String? trainId;
  final DateTime? endedAt;
  final List<HtTotal> totals;

  /// Every emote earned by the train.
  final List<HtReward> rewards;
}

final class HtMergeEvent extends HypeTrainEvent {
  const HtMergeEvent({
    required this.train,
    this.previousProgress,
    this.previousChannels = const [],
    this.joiningChannels = const [],
  });

  final HypeTrainExecution train;
  final HtProgress? previousProgress;
  final List<HtUser> previousChannels;
  final List<HtUser> joiningChannels;
}

final class HtChannelLeftEvent extends HypeTrainEvent {
  const HtChannelLeftEvent({
    required this.shouldEnd,
    this.trainId,
    this.continuesIn,
  });

  final String? trainId;

  /// The channel the shared train continues in.
  final HtUser? continuesIn;
  final bool shouldEnd;
}

/// Known messages the viewer side does not act on.
final class HtIgnoredEvent extends HypeTrainEvent {
  const HtIgnoredEvent(this.type);

  final String type;
}

final class HtUnknownEvent extends HypeTrainEvent {
  const HtUnknownEvent(this.type);

  final String type;
}
