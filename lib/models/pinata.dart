import 'package:flutter/foundation.dart';

enum PinataEligibility { yes, no }

@immutable
class PinataState {
  const PinataState({
    required this.stage,
    this.isEligibleForRewards,
    this.expiresAt,
  });

  final int stage;
  final bool? isEligibleForRewards;
  final DateTime? expiresAt;

  PinataEligibility get eligibility => isEligibleForRewards == true
      ? PinataEligibility.yes
      : PinataEligibility.no;

  static PinataState? fromBody(Object? body) {
    final data = body is Map ? body['data'] : null;
    final user = data is Map ? data['user'] : null;
    final channel = user is Map ? user['channel'] : null;
    final train = channel is Map ? channel['hypeTrain'] : null;
    final execution = train is Map ? train['execution'] : null;
    if (execution is! Map || execution['isActive'] != true) return null;
    final details = execution['variantTrainDetails'];
    if (details is! Map || details['__typename'] != 'PinataTrainDetails') {
      return null;
    }
    final stage = details['deteriorationStage'];
    final self = execution['self'];
    final expires = execution['expiresAt'];
    return PinataState(
      stage: stage is num && stage >= 0 ? stage.toInt() : 0,
      isEligibleForRewards: self is Map
          ? self['isEligibleForRewards'] as bool?
          : null,
      expiresAt: expires is String ? DateTime.tryParse(expires)?.toUtc() : null,
    );
  }
}
