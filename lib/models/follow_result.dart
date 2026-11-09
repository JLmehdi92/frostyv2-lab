enum FollowResult {
  done,
  tooManyFollows,
  unverifiedEmail,
  unverifiedPhone,
  unverifiedPhoneAndEmail,
  forbidden,
  refused,
  integrityRefused,
  signedOut,
  failed;

  bool get succeeded => this == done;

  bool get opensTwitch => this == integrityRefused;

  static FollowResult fromBody(Object? body, String field) {
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
