import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

DateTime? _dateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

// Twitch (default) user
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class UserTwitch {
  final String id;
  final String login;
  final String displayName;
  final String profileImageUrl;

  /// When the account was made; null when Twitch did not say.
  @JsonKey(fromJson: _dateOrNull)
  final DateTime? createdAt;

  const UserTwitch(
    this.id,
    this.login,
    this.displayName,
    this.profileImageUrl, {
    this.createdAt,
  });

  factory UserTwitch.fromJson(Map<String, dynamic> json) =>
      _$UserTwitchFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class UserBlockedTwitch {
  final String userId;
  final String userLogin;
  final String displayName;

  const UserBlockedTwitch(this.userId, this.userLogin, this.displayName);

  factory UserBlockedTwitch.fromJson(Map<String, dynamic> json) =>
      _$UserBlockedTwitchFromJson(json);
}
