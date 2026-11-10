import 'package:onset/apis/integrity_retry_interceptor.dart';

enum FollowResult {
  done,
  tooManyFollows,
  unverifiedEmail,
  unverifiedPhone,
  unverifiedPhoneAndEmail,
  forbidden,
  refused,
  noWebSession,
  signedOut,
  mintTimeout,
  mintFailed,
  integrityRefused,
  gqlError,
  failed;

  bool get succeeded => this == done;

  bool get needsWebSession => this == noWebSession || this == signedOut;

  bool get canRetry => switch (this) {
    refused ||
    mintTimeout ||
    mintFailed ||
    integrityRefused ||
    gqlError ||
    failed => true,
    _ => false,
  };

  static FollowResult fromBody(
    Object? body,
    String field, {
    IntegrityStage? stage,
  }) {
    if (body is! Map) return failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      if (!IntegrityRetryInterceptor.isIntegrityRefusal(body)) return gqlError;
      return switch (stage) {
        IntegrityStage.mintTimedOut => mintTimeout,
        IntegrityStage.mintFailed => mintFailed,
        _ => integrityRefused,
      };
    }
    final data = body['data'];
    final payload = data is Map ? data[field] : null;
    if (payload is! Map) return failed;
    final error = payload['error'];
    if (error is! Map) return done;
    return switch (error['code']) {
      'TOO_MANY_FOLLOWS' => tooManyFollows,
      'UNVERIFIED_EMAIL' => unverifiedEmail,
      'UNVERIFIED_PHONE' => unverifiedPhone,
      'UNVERIFIED_PHONE_AND_EMAIL' => unverifiedPhoneAndEmail,
      'FORBIDDEN' => forbidden,
      _ => refused,
    };
  }
}

class GiftSettings {
  const GiftSettings({
    required this.followedChannelsOnly,
    required this.countHidden,
  });

  final bool followedChannelsOnly;
  final bool countHidden;

  GiftSettings copyWith({bool? followedChannelsOnly, bool? countHidden}) =>
      GiftSettings(
        followedChannelsOnly: followedChannelsOnly ?? this.followedChannelsOnly,
        countHidden: countHidden ?? this.countHidden,
      );

  static GiftSettings? fromSettings(Object? settings) {
    if (settings is! Map) return null;
    final onlyFollowed = settings['giftsToFollowedChannelsOnly'];
    final hidden = settings['isGiftCountHidden'];
    if (onlyFollowed is! bool || hidden is! bool) return null;
    return GiftSettings(
      followedChannelsOnly: onlyFollowed,
      countHidden: hidden,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GiftSettings &&
      other.followedChannelsOnly == followedChannelsOnly &&
      other.countHidden == countHidden;

  @override
  int get hashCode => Object.hash(followedChannelsOnly, countHidden);
}
