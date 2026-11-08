import 'package:json_annotation/json_annotation.dart';

part 'moderation.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ChannelRoleUser {
  const ChannelRoleUser({
    required this.userId,
    required this.userLogin,
    required this.userName,
  });

  @JsonKey(defaultValue: '')
  final String userId;
  @JsonKey(defaultValue: '')
  final String userLogin;
  @JsonKey(defaultValue: '')
  final String userName;

  String get displayName => userName.isEmpty ? userLogin : userName;

  factory ChannelRoleUser.fromJson(Map<String, dynamic> json) =>
      _$ChannelRoleUserFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ShieldModeStatus {
  const ShieldModeStatus({
    required this.isActive,
    this.moderatorName = '',
    this.lastActivatedAt = '',
  });

  @JsonKey(defaultValue: false)
  final bool isActive;
  @JsonKey(defaultValue: '')
  final String moderatorName;
  @JsonKey(defaultValue: '')
  final String lastActivatedAt;

  factory ShieldModeStatus.fromJson(Map<String, dynamic> json) =>
      _$ShieldModeStatusFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class BlockedTerm {
  const BlockedTerm({required this.id, required this.text, this.expiresAt});

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String text;
  final String? expiresAt;

  factory BlockedTerm.fromJson(Map<String, dynamic> json) =>
      _$BlockedTermFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class UnbanRequest {
  const UnbanRequest({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String userId;
  @JsonKey(defaultValue: '')
  final String userLogin;
  @JsonKey(defaultValue: '')
  final String userName;
  @JsonKey(defaultValue: '')
  final String text;
  @JsonKey(defaultValue: '')
  final String status;
  @JsonKey(defaultValue: '')
  final String createdAt;

  String get displayName => userName.isEmpty ? userLogin : userName;

  factory UnbanRequest.fromJson(Map<String, dynamic> json) =>
      _$UnbanRequestFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class BannedUser {
  const BannedUser({
    required this.userId,
    required this.expiresAt,
    this.reason = '',
  });

  @JsonKey(defaultValue: '')
  final String userId;
  @JsonKey(defaultValue: '')
  final String expiresAt;
  @JsonKey(defaultValue: '')
  final String reason;

  DateTime? get timeoutEndsAt =>
      expiresAt.isEmpty ? null : DateTime.tryParse(expiresAt);

  factory BannedUser.fromJson(Map<String, dynamic> json) =>
      _$BannedUserFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class PollChoice {
  const PollChoice({required this.id, required this.title, this.votes = 0});

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: 0)
  final int votes;

  factory PollChoice.fromJson(Map<String, dynamic> json) =>
      _$PollChoiceFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ChannelPoll {
  const ChannelPoll({
    required this.id,
    required this.title,
    required this.choices,
    required this.status,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: <PollChoice>[])
  final List<PollChoice> choices;
  @JsonKey(defaultValue: '')
  final String status;

  bool get isActive => status == 'ACTIVE';

  int get totalVotes => choices.fold(0, (sum, choice) => sum + choice.votes);

  factory ChannelPoll.fromJson(Map<String, dynamic> json) =>
      _$ChannelPollFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class PredictionOutcome {
  const PredictionOutcome({
    required this.id,
    required this.title,
    this.users = 0,
    this.channelPoints = 0,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: 0)
  final int users;
  @JsonKey(defaultValue: 0)
  final int channelPoints;

  factory PredictionOutcome.fromJson(Map<String, dynamic> json) =>
      _$PredictionOutcomeFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ChannelPrediction {
  const ChannelPrediction({
    required this.id,
    required this.title,
    required this.outcomes,
    required this.status,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: <PredictionOutcome>[])
  final List<PredictionOutcome> outcomes;
  @JsonKey(defaultValue: '')
  final String status;

  bool get isActive => status == 'ACTIVE';
  bool get isLocked => status == 'LOCKED';
  bool get isOpen => isActive || isLocked;

  factory ChannelPrediction.fromJson(Map<String, dynamic> json) =>
      _$ChannelPredictionFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RedemptionReward {
  const RedemptionReward({
    required this.id,
    required this.title,
    this.cost = 0,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: 0)
  final int cost;

  factory RedemptionReward.fromJson(Map<String, dynamic> json) =>
      _$RedemptionRewardFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.userLogin,
    required this.userName,
    required this.reward,
    this.userInput = '',
    this.redeemedAt = '',
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String userLogin;
  @JsonKey(defaultValue: '')
  final String userName;
  final RedemptionReward reward;
  @JsonKey(defaultValue: '')
  final String userInput;
  @JsonKey(defaultValue: '')
  final String redeemedAt;

  String get displayName => userName.isEmpty ? userLogin : userName;

  factory RewardRedemption.fromJson(Map<String, dynamic> json) =>
      _$RewardRedemptionFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class CommercialStart {
  const CommercialStart({required this.length, this.retryAfter = 0});

  @JsonKey(defaultValue: 0)
  final int length;
  @JsonKey(defaultValue: 0)
  final int retryAfter;

  factory CommercialStart.fromJson(Map<String, dynamic> json) =>
      _$CommercialStartFromJson(json);
}
