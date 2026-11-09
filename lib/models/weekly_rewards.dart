import 'package:flutter/foundation.dart';

@immutable
class WeeklyRewardTier {
  const WeeklyRewardTier({
    required this.tier,
    required this.channelPoints,
    this.badgeUrl,
  });

  final int tier;
  final int channelPoints;
  final String? badgeUrl;

  static WeeklyRewardTier? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final tier = raw['tier'];
    if (tier is! num) return null;
    final badge = raw['badge'];
    final image = badge is Map ? badge['image4x'] : null;
    return WeeklyRewardTier(
      tier: tier.toInt(),
      channelPoints: (raw['channelPoints'] as num?)?.toInt() ?? 0,
      badgeUrl: image is String && image.startsWith('https://') ? image : null,
    );
  }
}

enum WeeklyRewardsStatus { earned, complete, progress }

@immutable
class WeeklyRewards {
  const WeeklyRewards({
    required this.daysVisitedThisWeek,
    required this.daysRequiredPerWeek,
    this.accumulatedWeeks = 0,
    this.hasEarnedThisWeek = false,
    this.hasVisitedToday = false,
    this.currentTier,
    this.tiers = const [],
    this.endsAt,
    this.weekResets = const [],
  });

  final int daysVisitedThisWeek;
  final int daysRequiredPerWeek;
  final int accumulatedWeeks;
  final bool hasEarnedThisWeek;
  final bool hasVisitedToday;
  final WeeklyRewardTier? currentTier;
  final List<WeeklyRewardTier> tiers;
  final DateTime? endsAt;
  final List<DateTime> weekResets;

  WeeklyRewardsStatus get status => isComplete
      ? WeeklyRewardsStatus.complete
      : hasEarnedThisWeek
      ? WeeklyRewardsStatus.earned
      : WeeklyRewardsStatus.progress;

  int get daysShown => daysVisitedThisWeek.clamp(0, daysRequiredPerWeek);

  bool get isComplete =>
      tiers.isNotEmpty &&
      currentTier != null &&
      currentTier!.tier >= tiers.last.tier &&
      hasEarnedThisWeek;

  DateTime? nextResetAfter(DateTime now) {
    for (final reset in weekResets) {
      if (reset.isAfter(now)) return reset;
    }
    return null;
  }

  static WeeklyRewards? fromBody(Object? body) {
    final data = body is Map ? body['data'] : null;
    final channel = data is Map ? data['channel'] : null;
    final self = channel is Map ? channel['self'] : null;
    final raw = self is Map ? self['weeklyVisitRewards'] : null;
    if (raw is! Map) return null;
    final config = raw['eventConfig'];
    if (config is! Map) return null;
    final required = (config['daysRequiredPerWeek'] as num?)?.toInt() ?? 0;
    if (required <= 0) return null;
    final rawTiers = config['rewardTiers'];
    final tiers =
        (rawTiers is List
              ? rawTiers.map(WeeklyRewardTier.tryParse).nonNulls.toList()
              : <WeeklyRewardTier>[])
          ..sort((a, b) => a.tier.compareTo(b.tier));
    final rawResets = config['weekResetDates'];
    final resets =
        (rawResets is List
              ? rawResets
                    .whereType<String>()
                    .map(DateTime.tryParse)
                    .nonNulls
                    .map((date) => date.toUtc())
                    .toList()
              : <DateTime>[])
          ..sort();
    final end = config['endDate'];
    return WeeklyRewards(
      daysVisitedThisWeek: (raw['daysVisitedThisWeek'] as num?)?.toInt() ?? 0,
      daysRequiredPerWeek: required,
      accumulatedWeeks: (raw['accumulatedWeeks'] as num?)?.toInt() ?? 0,
      hasEarnedThisWeek: raw['hasEarnedWeeklyRewardThisWeek'] == true,
      hasVisitedToday: raw['hasVisitedToday'] == true,
      currentTier: WeeklyRewardTier.tryParse(raw['currentReward']),
      tiers: tiers,
      endsAt: end is String ? DateTime.tryParse(end)?.toUtc() : null,
      weekResets: resets,
    );
  }
}

@immutable
class CommunityMoment {
  const CommunityMoment({required this.id, this.clipSlug});

  final String id;
  final String? clipSlug;

  static final _id = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');

  static CommunityMoment? fromEvent(Map<String, dynamic> data) {
    final id = data['moment_id'];
    if (id is! String || !_id.hasMatch(id)) return null;
    final slug = data['clip_slug'];
    return CommunityMoment(
      id: id,
      clipSlug: slug is String && slug.isNotEmpty ? slug : null,
    );
  }
}

enum MomentClaimResult {
  claimed,
  alreadyClaimed,
  expired,
  invalid,
  integrityRefused,
  signedOut,
  failed;

  bool get isClaimed => this == claimed || this == alreadyClaimed;

  static MomentClaimResult fromBody(Object? body) {
    if (body is! Map) return failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return text.contains('integrity') ? integrityRefused : failed;
    }
    final data = body['data'];
    final payload = data is Map ? data['claimCommunityMoment'] : null;
    if (payload is! Map) return failed;
    return switch (payload['error']) {
      null => payload['moment'] is Map ? claimed : failed,
      'ALREADY_CLAIMED' => alreadyClaimed,
      'CLAIM_PERIOD_EXPIRED' => expired,
      'INVALID_MOMENT_ID' => invalid,
      _ => failed,
    };
  }
}
