// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moderation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChannelRoleUser _$ChannelRoleUserFromJson(Map<String, dynamic> json) =>
    ChannelRoleUser(
      userId: json['user_id'] as String? ?? '',
      userLogin: json['user_login'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
    );

ShieldModeStatus _$ShieldModeStatusFromJson(Map<String, dynamic> json) =>
    ShieldModeStatus(
      isActive: json['is_active'] as bool? ?? false,
      moderatorName: json['moderator_name'] as String? ?? '',
      lastActivatedAt: json['last_activated_at'] as String? ?? '',
    );

BlockedTerm _$BlockedTermFromJson(Map<String, dynamic> json) => BlockedTerm(
  id: json['id'] as String? ?? '',
  text: json['text'] as String? ?? '',
  expiresAt: json['expires_at'] as String?,
);

UnbanRequest _$UnbanRequestFromJson(Map<String, dynamic> json) => UnbanRequest(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  userLogin: json['user_login'] as String? ?? '',
  userName: json['user_name'] as String? ?? '',
  text: json['text'] as String? ?? '',
  status: json['status'] as String? ?? '',
  createdAt: json['created_at'] as String? ?? '',
);

BannedUser _$BannedUserFromJson(Map<String, dynamic> json) => BannedUser(
  userId: json['user_id'] as String? ?? '',
  expiresAt: json['expires_at'] as String? ?? '',
  reason: json['reason'] as String? ?? '',
);

PollChoice _$PollChoiceFromJson(Map<String, dynamic> json) => PollChoice(
  id: json['id'] as String? ?? '',
  title: json['title'] as String? ?? '',
  votes: (json['votes'] as num?)?.toInt() ?? 0,
);

ChannelPoll _$ChannelPollFromJson(Map<String, dynamic> json) => ChannelPoll(
  id: json['id'] as String? ?? '',
  title: json['title'] as String? ?? '',
  choices:
      (json['choices'] as List<dynamic>?)
          ?.map((e) => PollChoice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  status: json['status'] as String? ?? '',
);

PredictionOutcome _$PredictionOutcomeFromJson(Map<String, dynamic> json) =>
    PredictionOutcome(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      users: (json['users'] as num?)?.toInt() ?? 0,
      channelPoints: (json['channel_points'] as num?)?.toInt() ?? 0,
    );

ChannelPrediction _$ChannelPredictionFromJson(Map<String, dynamic> json) =>
    ChannelPrediction(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      outcomes:
          (json['outcomes'] as List<dynamic>?)
              ?.map(
                (e) => PredictionOutcome.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      status: json['status'] as String? ?? '',
    );

RedemptionReward _$RedemptionRewardFromJson(Map<String, dynamic> json) =>
    RedemptionReward(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
    );

RewardRedemption _$RewardRedemptionFromJson(Map<String, dynamic> json) =>
    RewardRedemption(
      id: json['id'] as String? ?? '',
      userLogin: json['user_login'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      reward: RedemptionReward.fromJson(json['reward'] as Map<String, dynamic>),
      userInput: json['user_input'] as String? ?? '',
      redeemedAt: json['redeemed_at'] as String? ?? '',
    );

CommercialStart _$CommercialStartFromJson(Map<String, dynamic> json) =>
    CommercialStart(
      length: (json['length'] as num?)?.toInt() ?? 0,
      retryAfter: (json['retry_after'] as num?)?.toInt() ?? 0,
    );
