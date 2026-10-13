import 'dart:math';

import 'package:flutter/foundation.dart';

/// Hype train data from Twitch GQL (camelCase) and realtime events
/// (mostly snake_case, sometimes both). Parsing is tolerant: a missing or
/// wrongly typed field gets a default, never an exception.

// --- Field helpers -------------------------------------------------------------

/// The first of [keys] present in [map] (camel and snake spellings).
Object? htField(Map? map, List<String> keys) {
  if (map == null) return null;
  for (final key in keys) {
    final value = map[key];
    if (value != null) return value;
  }
  return null;
}

String? htString(Map? map, List<String> keys) {
  final value = htField(map, keys);
  return value is String ? value : null;
}

/// Larger magnitudes are garbage (and could overflow sums).
const _maxInt = 1 << 40;

int? htInt(Map? map, List<String> keys) => _int(htField(map, keys));

int? _int(Object? value) {
  if (value is! num || !value.isFinite || value.abs() > _maxInt) return null;
  return value.toInt();
}

bool htBool(Map? map, List<String> keys) => htField(map, keys) == true;

Map? htMap(Map? map, List<String> keys) {
  final value = htField(map, keys);
  return value is Map ? value : null;
}

/// No Twitch list we read is anywhere near this long.
const _maxListLength = 200;

List htList(Map? map, List<String> keys) {
  final value = htField(map, keys);
  if (value is! List) return const [];
  return value.length > _maxListLength
      ? value.sublist(0, _maxListLength)
      : value;
}

final _minDate = DateTime.utc(2000);
final _maxDate = DateTime.utc(2100);

/// An ISO-8601 string or epoch milliseconds; null outside 2000–2100 (Go's
/// zero time `0001-01-01` means "unset").
DateTime? htDate(Map? map, List<String> keys) {
  final value = htField(map, keys);
  DateTime? date;
  if (value is String) {
    date = DateTime.tryParse(value)?.toUtc();
  } else if (value is num &&
      value.isFinite &&
      value >= _minDate.millisecondsSinceEpoch &&
      value <= _maxDate.millisecondsSinceEpoch) {
    date = DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (date == null || date.isBefore(_minDate) || date.isAfter(_maxDate)) {
    return null;
  }
  return date;
}

// --- Enums ---------------------------------------------------------------------

/// How a train looks and what it unlocks. Pinata trains render as regular.
enum HtVariant { regular, goldenKappa, treasure, community, mythic }

enum HtAthState { none, approaching, reached, justReached }

HtAthState htAthState(String? raw) => switch (raw) {
  'APPROACHING' => HtAthState.approaching,
  'REACHED' => HtAthState.reached,
  'JUST_REACHED' => HtAthState.justReached,
  _ => HtAthState.none,
};

enum HtSource { bits, subs, explicitPurchase, admin, raid, unknown }

HtSource htSource(String? raw) => switch (raw) {
  'BITS' => HtSource.bits,
  'SUBS' => HtSource.subs,
  'EXPLICIT_PURCHASE' => HtSource.explicitPurchase,
  'ADMIN' => HtSource.admin,
  'RAID' => HtSource.raid,
  _ => HtSource.unknown,
};

/// What a viewer did. Unknown actions keep their [raw] name.
@immutable
class HtAction {
  const HtAction(this.raw);

  final String raw;

  bool get isCheer => const {
    'CHEER',
    'POWER_CHEER',
    'BITS_ON_EXTENSION',
    'BITS_EXTENSION',
    'POLLS',
    'POLL',
  }.contains(raw);

  /// 1, 2 or 3 for subscriptions (own or gifted), else null.
  int? get subTier => switch (raw) {
    'TIER_1_SUB' || 'TIER_1_GIFTED_SUB' => 1,
    'TIER_2_SUB' || 'TIER_2_GIFTED_SUB' => 2,
    'TIER_3_SUB' || 'TIER_3_GIFTED_SUB' => 3,
    _ => null,
  };

  bool get isGift => raw.endsWith('_GIFTED_SUB');

  bool get isKnown =>
      isCheer ||
      subTier != null ||
      const {'PAID_PINNED_CHAT', 'ADMIN', 'RAID'}.contains(raw);

  @override
  bool operator ==(Object other) => other is HtAction && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => 'HtAction($raw)';
}

enum HtEndReason { completed, expired, inProgress, unknown }

HtEndReason htEndReason(String? raw) => switch (raw) {
  'COMPLETED' => HtEndReason.completed,
  'EXPIRED' => HtEndReason.expired,
  'IN_PROGRESS' => HtEndReason.inProgress,
  _ => HtEndReason.unknown,
};

/// Treasure discount / community emotes: locked, one level away, unlocked.
enum HtUnlockStatus { none, approaching, reached }

HtUnlockStatus htUnlockStatus(String? raw) => switch (raw) {
  'APPROACHING' => HtUnlockStatus.approaching,
  'REACHED' => HtUnlockStatus.reached,
  _ => HtUnlockStatus.none,
};

// --- Values --------------------------------------------------------------------

final _emoteId = RegExp(r'^[A-Za-z0-9_]{1,80}$');
const _emoteBase = 'https://static-cdn.jtvnw.net/emoticons/v2';

enum HtRewardType { emote, badge, unknown }

/// An emote or badge earned on a level.
@immutable
class HtReward {
  const HtReward({
    required this.type,
    required this.id,
    this.token,
    this.imageUrl,
    this.setId,
  });

  /// Accepts the realtime flat form `{type, id, token}` and the GQL form
  /// `{id, type, emote{id token}}` / `{badge{id setID imageURL}}`.
  static HtReward? parse(Object? raw) {
    if (raw is! Map) return null;
    final emote = htMap(raw, ['emote']);
    final badge = htMap(raw, ['badge']);
    final typeName = htString(raw, ['type']) ?? htString(raw, ['__typename']);
    final type = switch (typeName) {
      'EMOTE' || 'HypeTrainEmoteReward' => HtRewardType.emote,
      'BADGE' || 'HypeTrainBadgeReward' => HtRewardType.badge,
      _ =>
        emote != null
            ? HtRewardType.emote
            : badge != null
            ? HtRewardType.badge
            : HtRewardType.unknown,
    };
    final id =
        htString(emote, ['id']) ??
        htString(badge, ['id']) ??
        htString(raw, ['id', 'badge_id']);
    if (id == null || id.isEmpty) return null;
    return HtReward(
      type: type,
      id: id,
      token: htString(emote, ['token']) ?? htString(raw, ['token']),
      imageUrl:
          htString(badge, ['imageURL']) ??
          htString(raw, ['image_url', 'imageURL']),
      setId: htString(badge, ['setID']) ?? htString(raw, ['set_id', 'setID']),
    );
  }

  final HtRewardType type;
  final String id;
  final String? token;
  final String? imageUrl;
  final String? setId;

  /// The emote image, only for a well-formed emote id.
  Uri? get emoteUrl => type == HtRewardType.emote && _emoteId.hasMatch(id)
      ? Uri.parse('$_emoteBase/$id/default/dark/3.0')
      : null;

  /// The badge image, only from Twitch's CDN over https.
  Uri? get badgeUrl => htCdnUrl(imageUrl);
}

/// [raw] when it is an https URL on Twitch's image CDN, else null.
Uri? htCdnUrl(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  return uri.host == 'static-cdn.jtvnw.net' ? uri : null;
}

List<HtReward> htRewards(Iterable raw) => [
  for (final item in raw) ?HtReward.parse(item),
];

/// A level: its number, the running total needed to finish it, rewards.
@immutable
class HtLevel {
  const HtLevel({
    required this.value,
    required this.cumulativeGoal,
    this.rewards = const [],
  });

  static HtLevel parse(Map? raw) => HtLevel(
    value: htInt(raw, ['value']) ?? 1,
    cumulativeGoal: htInt(raw, ['goal']) ?? 0,
    rewards: htRewards(htList(raw, ['rewards'])),
  );

  final int value;

  /// Cumulative (the train's total at the end of this level).
  final int cumulativeGoal;
  final List<HtReward> rewards;
}

/// Progress inside the current level. [goal] and [value] are in-level;
/// [total] is the train's running total (verified live).
@immutable
class HtProgress {
  const HtProgress({
    required this.level,
    required this.goal,
    required this.value,
    required this.total,
    this.remainingSeconds,
    this.athState = HtAthState.none,
  });

  /// Null without a total or a level: an empty progress must not reset the
  /// banner to level 1.
  static HtProgress? parse(Object? raw) {
    if (raw is! Map) return null;
    final total = htInt(raw, ['total']);
    final level = htMap(raw, ['level']);
    final levelValue = htInt(level, ['value']);
    if (total == null || levelValue == null || levelValue < 1) return null;
    return HtProgress(
      level: HtLevel.parse(level),
      goal: max(0, htInt(raw, ['goal']) ?? 0),
      value: max(0, htInt(raw, ['progression', 'value']) ?? 0),
      total: max(0, total),
      remainingSeconds: htInt(raw, ['remainingSeconds', 'remaining_seconds']),
      athState: htAthState(
        htString(raw, ['allTimeHighState', 'all_time_high_state']),
      ),
    );
  }

  final HtLevel level;
  final int goal;
  final int value;
  final int total;
  final int? remainingSeconds;
  final HtAthState athState;

  HtProgress copyWith({HtAthState? athState}) => HtProgress(
    level: level,
    goal: goal,
    value: value,
    total: total,
    remainingSeconds: remainingSeconds,
    athState: athState ?? this.athState,
  );
}

/// A viewer shown with an avatar (conductors, shared channels).
@immutable
class HtUser {
  const HtUser({
    required this.id,
    required this.login,
    required this.displayName,
    this.profileImageUrl,
  });

  static HtUser? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = htString(raw, ['id']);
    if (id == null || id.isEmpty) return null;
    final login = htString(raw, ['login']) ?? '';
    return HtUser(
      id: id,
      login: login,
      displayName: htString(raw, ['displayName', 'display_name']) ?? login,
      profileImageUrl: htCdnUrl(
        htString(raw, ['profileImageURL', 'profile_image_url']),
      )?.toString(),
    );
  }

  final String id;
  final String login;
  final String displayName;
  final String? profileImageUrl;
}

/// The top contributor of one source (subs or bits).
@immutable
class HtConductor {
  const HtConductor({
    required this.source,
    required this.user,
    this.participations = const {},
  });

  /// Accepts the GQL `participation[{source action quantity}]` list and the
  /// realtime `participations{"SOURCE.ACTION": quantity}` map.
  static HtConductor? parse(Object? raw) {
    if (raw is! Map) return null;
    final user = HtUser.parse(htMap(raw, ['user']));
    if (user == null) return null;
    final participations = <String, int>{};
    final map = htField(raw, ['participations']);
    if (map is Map) {
      map.forEach((key, value) {
        final quantity = _int(value);
        if (key is String && quantity != null && quantity > 0) {
          final action = key.contains('.') ? key.split('.').last : key;
          participations[action] = (participations[action] ?? 0) + quantity;
        }
      });
    }
    for (final item in htList(raw, ['participation'])) {
      if (item is! Map) continue;
      final action = htString(item, ['action']);
      final quantity = htInt(item, ['quantity']);
      if (action != null && quantity != null && quantity > 0) {
        participations[action] = (participations[action] ?? 0) + quantity;
      }
    }
    return HtConductor(
      source: htSource(htString(raw, ['source'])),
      user: user,
      participations: participations,
    );
  }

  final HtSource source;
  final HtUser user;

  /// Quantity per action name (`TIER_1_GIFTED_SUB`, `CHEER`, …).
  final Map<String, int> participations;

  /// Bits cheered or subscriptions given (own and gifted).
  int get amount => participations.values.fold(0, (a, b) => a + b);
}

/// Per-channel settings of the train.
@immutable
class HtConfig {
  const HtConfig({
    this.difficulty,
    this.maxLevel,
    this.conversionRates = const {},
    this.conductorBadges = const {},
    this.calloutEmote,
    this.creatorColor,
    this.kickoffMinPoints,
  });

  static HtConfig parse(Object? raw) {
    if (raw is! Map) return const HtConfig();
    final difficulty = htString(raw, ['difficulty']);
    int? maxLevel;
    for (final setting in htList(raw, ['difficultySettings'])) {
      if (setting is! Map) continue;
      final level = htInt(setting, ['maxLevel']);
      if (level == null) continue;
      if (difficulty == null ||
          htString(setting, ['difficulty']) == difficulty) {
        maxLevel = level;
        break;
      }
    }
    final rates = <String, int>{};
    for (final rate in htList(raw, ['participationConversionRates'])) {
      if (rate is! Map) continue;
      final action = htString(rate, ['action']);
      final value = htInt(rate, ['value']);
      if (action == null ||
          action == 'UNKNOWN' ||
          value == null ||
          value <= 0) {
        continue;
      }
      rates[action] = value;
    }
    final badges = <HtSource, String>{};
    for (final reward in htList(raw, ['conductorRewards'])) {
      if (reward is! Map || htString(reward, ['type']) != 'CURRENT') continue;
      final source = htSource(htString(reward, ['source']));
      for (final item in htRewards(htList(reward, ['rewards']))) {
        final url = item.badgeUrl;
        if (url != null) badges[source] ??= url.toString();
      }
    }
    final callout = htMap(raw, ['calloutEmote']);
    final calloutId =
        htString(callout, ['id']) ?? htString(raw, ['calloutEmoteId']);
    final calloutToken =
        htString(callout, ['token']) ?? htString(raw, ['calloutEmoteToken']);
    final useColor = htField(raw, ['willUseCreatorColor']) != false;
    return HtConfig(
      difficulty: difficulty,
      maxLevel: maxLevel,
      conversionRates: rates,
      conductorBadges: badges,
      calloutEmote: calloutId == null
          ? null
          : HtReward(
              type: HtRewardType.emote,
              id: calloutId,
              token: calloutToken,
            ),
      creatorColor: useColor
          ? htColor(htString(raw, ['primaryHexColor']))
          : null,
      kickoffMinPoints: htInt(htMap(raw, ['kickoff']), [
        'minPoints',
        'min_points',
      ]),
    );
  }

  final String? difficulty;
  final int? maxLevel;

  /// Points per unit of each action (TIER_1_SUB → 500, CHEER → 1, …).
  final Map<String, int> conversionRates;

  /// Badge shown next to the current conductor of each source.
  final Map<HtSource, String> conductorBadges;
  final HtReward? calloutEmote;

  /// The channel's colour as `0xFFRRGGBB`, when it asked for it.
  final int? creatorColor;
  final int? kickoffMinPoints;
}

/// `BD0078` or `#BD0078` → `0xFFBD0078`; anything else → null.
int? htColor(String? raw) {
  if (raw == null) return null;
  final hex = raw.startsWith('#') ? raw.substring(1) : raw;
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex, radix: 16);
}

@immutable
class HtTreasure {
  const HtTreasure({
    required this.discountPercentage,
    required this.threshold,
    required this.status,
  });

  /// Both key spellings arrive in the same object (verified).
  static HtTreasure? parse(Object? raw) {
    if (raw is! Map) return null;
    final threshold = htInt(raw, [
      'discountLevelThreshold',
      'discount_level_threshold',
    ]);
    if (threshold == null) return null;
    return HtTreasure(
      discountPercentage:
          htInt(raw, ['discountPercentage', 'discount_percentage']) ?? 0,
      threshold: threshold,
      status: htUnlockStatus(
        htString(raw, ['status', 'discount_status', 'discountStatus']),
      ),
    );
  }

  final int discountPercentage;
  final int threshold;
  final HtUnlockStatus status;
}

@immutable
class HtCommunity {
  const HtCommunity({
    required this.current,
    required this.next,
    required this.previous,
    required this.threshold,
    required this.status,
    this.maxRewardLevel,
  });

  static HtCommunity parse(Map raw) => HtCommunity(
    current: htInt(raw, ['currentRewardAmount']) ?? 0,
    next: htInt(raw, ['nextRewardAmount']) ?? 0,
    previous: htInt(raw, ['previousRewardAmount']) ?? 0,
    threshold: htInt(raw, ['rewardLevelThreshold']) ?? 5,
    status: htUnlockStatus(htString(raw, ['status', 'rewardStatus'])),
    maxRewardLevel: htInt(raw, ['maxRewardLevel']),
  );

  /// Viewers that receive an emote at the current level.
  final int current;
  final int next;
  final int previous;
  final int threshold;
  final HtUnlockStatus status;
  final int? maxRewardLevel;
}

@immutable
class HtMythic {
  const HtMythic({this.selectedEmote, this.pool = const []});

  static HtMythic parse(Map raw) {
    HtReward? emote(Object? e) => e is Map && htString(e, ['id']) != null
        ? HtReward(
            type: HtRewardType.emote,
            id: htString(e, ['id'])!,
            token: htString(e, ['token']),
          )
        : null;
    return HtMythic(
      selectedEmote: emote(htMap(raw, ['selectedEmote'])),
      pool: [
        for (final e in htList(raw, ['emotePool'])) ?emote(e),
      ],
    );
  }

  final HtReward? selectedEmote;
  final List<HtReward> pool;
}

/// The channel's record train.
@immutable
class HtAth {
  const HtAth({
    required this.level,
    required this.goal,
    required this.progression,
    required this.total,
  });

  static HtAth? parse(Object? raw) {
    if (raw is! Map) return null;
    final level = htInt(htMap(raw, ['level']), ['value']);
    if (level == null) return null;
    return HtAth(
      level: level,
      goal: htInt(raw, ['goal']) ?? 0,
      progression: htInt(raw, ['progression', 'value']) ?? 0,
      total: htInt(raw, ['total']) ?? 0,
    );
  }

  final int level;
  final int goal;
  final int progression;
  final int total;
}

/// One channel of a shared (collaboration) train.
@immutable
class HtSharedChannel {
  const HtSharedChannel({
    required this.user,
    this.progress,
    this.ath,
    this.conductors = const [],
  });

  final HtUser user;
  final HtProgress? progress;
  final HtAth? ath;
  final List<HtConductor> conductors;
}

@immutable
class HtShared {
  const HtShared({required this.id, required this.channels});

  static HtShared? parse(Object? raw) {
    if (raw is! Map) return null;
    final channels = <String, HtSharedChannel>{};
    HtSharedChannel entry(HtUser user) =>
        channels[user.id] ?? HtSharedChannel(user: user);
    for (final item in htList(raw, ['sharedProgress'])) {
      if (item is! Map) continue;
      final user = HtUser.parse(htMap(item, ['user']));
      if (user == null) continue;
      final current = entry(user);
      channels[user.id] = HtSharedChannel(
        user: user,
        progress: HtProgress.parse(htMap(item, ['channelProgress'])),
        ath: current.ath,
        conductors: current.conductors,
      );
    }
    for (final item in htList(raw, [
      'sharedAllTimeHighRecords',
      'channelAllTimeHighRecords',
    ])) {
      if (item is! Map) continue;
      final user = HtUser.parse(htMap(item, ['user']));
      if (user == null) continue;
      final current = entry(user);
      channels[user.id] = HtSharedChannel(
        user: user,
        progress: current.progress,
        ath: HtAth.parse(htMap(item, ['channelAllTimeHigh'])),
        conductors: current.conductors,
      );
    }
    for (final item in htList(raw, ['sharedConductors'])) {
      if (item is! Map) continue;
      final user = HtUser.parse(htMap(item, ['user']));
      if (user == null) continue;
      final current = entry(user);
      channels[user.id] = HtSharedChannel(
        user: user,
        progress: current.progress,
        ath: current.ath,
        conductors: [
          for (final c in htList(item, ['conductors'])) ?HtConductor.parse(c),
        ],
      );
    }
    if (channels.isEmpty) return null;
    return HtShared(
      id: htString(raw, ['id']) ?? '',
      channels: channels.values.toList(),
    );
  }

  final String id;
  final List<HtSharedChannel> channels;
}

/// Variant precedence: Mythic, Community, Golden Kappa, Treasure, Regular.
HtVariant htVariantOf(Map raw) {
  final details = htMap(raw, ['variantTrainDetails']);
  final typeName = htString(details, ['__typename']);
  final type = htString(raw, ['hypeTrainType', 'hype_train_type']);
  if (typeName == 'MythicTrainDetails' || type == 'MYTHIC') {
    return HtVariant.mythic;
  }
  if (typeName == 'CommunityTrainDetails' || type == 'COMMUNITY') {
    return HtVariant.community;
  }
  if (htBool(raw, ['isGoldenKappaTrain', 'is_golden_kappa_train']) ||
      typeName == 'GoldenKappaTrainDetails' ||
      type == 'GOLDEN_KAPPA' ||
      type == 'GOLDEN') {
    return HtVariant.goldenKappa;
  }
  if (htBool(raw, ['isTreasureTrain', 'is_treasure_train']) ||
      typeName == 'TreasureTrainDetails' ||
      htMap(raw, ['treasureTrainDetails']) != null ||
      type == 'TREASURE') {
    return HtVariant.treasure;
  }
  return HtVariant.regular;
}

/// A running (or just ended) hype train.
@immutable
class HypeTrainExecution {
  const HypeTrainExecution({
    required this.id,
    required this.progress,
    this.startedAt,
    this.expiresAt,
    this.endedAt,
    this.endReason = HtEndReason.inProgress,
    this.conductors = const [],
    this.config = const HtConfig(),
    this.ath,
    this.variant = HtVariant.regular,
    this.treasure,
    this.community,
    this.mythic,
    this.shared,
    this.isFastMode = false,
  });

  /// The GQL execution, the `hype_train` of a level-up (GQL shape) and the
  /// realtime start payload (camelCase). Null without an id or progress.
  static HypeTrainExecution? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = htString(raw, ['id']);
    final progress = HtProgress.parse(htMap(raw, ['progress']));
    if (id == null || id.isEmpty || progress == null) return null;
    final details = htMap(raw, ['variantTrainDetails']);
    final typeName = htString(details, ['__typename']);
    // GQL sends no reason for a running train.
    final reason = htString(raw, [
      'endReason',
      'endingReason',
      'ending_reason',
    ]);
    final endedAt = htDate(raw, ['endedAt', 'ended_at']);
    return HypeTrainExecution(
      id: id,
      progress: progress,
      startedAt: htDate(raw, ['startedAt', 'started_at']),
      expiresAt: htDate(raw, ['expiresAt', 'expires_at']),
      endedAt: endedAt,
      endReason: reason == null
          ? (endedAt == null ? HtEndReason.inProgress : HtEndReason.unknown)
          : htEndReason(reason),
      conductors: [
        for (final c in htList(raw, ['conductors'])) ?HtConductor.parse(c),
      ],
      config: HtConfig.parse(htMap(raw, ['config'])),
      ath: HtAth.parse(htMap(raw, ['allTimeHigh', 'all_time_high'])),
      variant: htVariantOf(raw),
      treasure:
          HtTreasure.parse(htMap(raw, ['treasureTrainDetails'])) ??
          (typeName == 'TreasureTrainDetails'
              ? HtTreasure.parse(details)
              : null),
      community: typeName == 'CommunityTrainDetails' && details != null
          ? HtCommunity.parse(details)
          : null,
      mythic: typeName == 'MythicTrainDetails' && details != null
          ? HtMythic.parse(details)
          : null,
      shared: HtShared.parse(htMap(raw, ['sharedHypeTrainDetails'])),
      isFastMode: htBool(raw, ['isFastMode', 'is_fast_mode']),
    );
  }

  final String id;
  final HtProgress progress;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;
  final HtEndReason endReason;
  final List<HtConductor> conductors;
  final HtConfig config;
  final HtAth? ath;
  final HtVariant variant;
  final HtTreasure? treasure;
  final HtCommunity? community;
  final HtMythic? mythic;
  final HtShared? shared;
  final bool isFastMode;

  int get level => progress.level.value;

  HypeTrainExecution copyWith({
    HtProgress? progress,
    DateTime? expiresAt,
    DateTime? endedAt,
    HtEndReason? endReason,
    List<HtConductor>? conductors,
    HtConfig? config,
    HtAth? ath,
    HtVariant? variant,
    HtTreasure? treasure,
    HtCommunity? community,
    HtMythic? mythic,
    HtShared? shared,
  }) => HypeTrainExecution(
    id: id,
    progress: progress ?? this.progress,
    startedAt: startedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    endedAt: endedAt ?? this.endedAt,
    endReason: endReason ?? this.endReason,
    conductors: conductors ?? this.conductors,
    config: config ?? this.config,
    ath: ath ?? this.ath,
    variant: variant ?? this.variant,
    treasure: treasure ?? this.treasure,
    community: community ?? this.community,
    mythic: mythic ?? this.mythic,
    shared: shared ?? this.shared,
    isFastMode: isFastMode,
  );
}

/// A train about to start: a few more qualifying events kick it off.
@immutable
class HypeTrainApproaching {
  const HypeTrainApproaching({
    required this.id,
    required this.goal,
    required this.deadlines,
    this.creatorColor,
    this.participants = const {},
    this.levelOneRewards = const [],
    this.variant = HtVariant.regular,
  });

  /// Accepts GQL `eventsRemaining[{events secondsRemaining}]` and realtime
  /// `events_remaining_durations{"1": seconds}`.
  static HypeTrainApproaching? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = htString(raw, ['id', 'approaching_hype_train_id']);
    if (id == null || id.isEmpty) return null;
    final deadlines = <int, int>{};
    for (final item in htList(raw, ['eventsRemaining'])) {
      final events = htInt(item is Map ? item : null, ['events']);
      final seconds = htInt(item is Map ? item : null, ['secondsRemaining']);
      if (events != null && events > 0 && seconds != null && seconds > 0) {
        deadlines[events] = seconds;
      }
    }
    final durations = htField(raw, ['events_remaining_durations']);
    if (durations is Map) {
      durations.forEach((key, value) {
        final events = int.tryParse('$key');
        final seconds = _int(value);
        if (events != null && events > 0 && seconds != null && seconds > 0) {
          deadlines[events] = seconds;
        }
      });
    }
    return HypeTrainApproaching(
      id: id,
      goal: htInt(raw, ['goal']) ?? 3,
      deadlines: deadlines,
      creatorColor: htColor(htString(raw, ['creatorColor', 'creator_color'])),
      participants: {
        for (final p in htList(raw, ['participants']))
          if (p is String) p,
      },
      levelOneRewards: htRewards(
        htList(raw, ['levelOneRewards', 'level_one_rewards']),
      ),
      variant: htVariantOf(raw),
    );
  }

  final String id;

  /// Qualifying events needed to start.
  final int goal;

  /// Events still needed → seconds left for them (from when it arrived).
  final Map<int, int> deadlines;
  final int? creatorColor;

  /// Users who already contributed.
  final Set<String> participants;
  final List<HtReward> levelOneRewards;
  final HtVariant variant;
}
