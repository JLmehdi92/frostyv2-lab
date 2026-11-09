import 'dart:convert';

/// A Twitch playback access token (GQL `streamPlaybackAccessToken`).
///
/// The token [value] is itself a JSON document carrying an `expires` unix
/// timestamp, which lets the token be reused until it expires instead of
/// asking GQL again on every reload.
class PlaybackAccessToken {
  const PlaybackAccessToken({
    required this.value,
    required this.signature,
    required this.expiresAt,
    this.refusal,
    this.previewEndsAt,
  });

  factory PlaybackAccessToken.fromValue({
    required String value,
    required String signature,
    PlaybackRefusal? refusal,
  }) => PlaybackAccessToken(
    value: value,
    signature: signature,
    expiresAt: parseExpiry(value),
    refusal: refusal,
    previewEndsAt: parsePreviewEnd(value),
  );

  final String value;
  final String signature;

  /// Why Twitch would refuse this stream to the viewer (a token is still
  /// given, e.g. for a subscribers-only free preview); null when it plays.
  final PlaybackRefusal? refusal;

  /// When the token stops being accepted (null when unknown).
  final DateTime? expiresAt;

  final DateTime? previewEndsAt;

  static DateTime? parsePreviewEnd(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final viewUntil = switch (decoded['chansub']) {
        {'view_until': final num seconds} => _utcSeconds(seconds),
        _ => null,
      };
      final expires = switch (decoded['expires']) {
        final num seconds => _utcSeconds(seconds),
        _ => null,
      };
      if (viewUntil == null || expires == null) return null;
      return viewUntil.isBefore(expires) ? viewUntil : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime _utcSeconds(num seconds) =>
      DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      );

  /// Reads the `expires` unix time (seconds) from a token value, or null if
  /// it is missing or the value is not the expected JSON object.
  static DateTime? parseExpiry(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final expires = decoded['expires'];
      if (expires is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (expires * 1000).round(),
        isUtc: true,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Why Twitch refuses a stream, from the token's
/// `authorization.forbiddenReasonCode`.
enum PlaybackRefusal {
  /// The stream is for subscribers (`UNAUTHORIZED_ENTITLEMENTS`).
  subscribersOnly,

  /// Not available in the viewer's region.
  geoblocked,

  /// The viewer is banned from the channel.
  bannedFromChannel,

  /// Refused without a more precise reason.
  unauthorized,

  proxyDetected,

  wifiRequired,

  unsupportedDevice;

  static PlaybackRefusal? fromUsherCode(String? code) => switch (code) {
    'anonymizer_blocked' => proxyDetected,
    'cellular_geoblocked' => wifiRequired,
    'no_cdm_specified' => unsupportedDevice,
    _ => null,
  };

  /// Null for `NONE` and for codes this app does not know.
  static PlaybackRefusal? fromCode(String? code) => switch (code) {
    'UNAUTHORIZED_ENTITLEMENTS' => subscribersOnly,
    'GEOBLOCKED' => geoblocked,
    'CHANNEL_RESTRICTED_BANNED_USER' => bannedFromChannel,
    'UNAUTHORIZED' => unauthorized,
    _ => null,
  };
}

enum SubscriberTier {
  any,
  tier2,
  tier3;

  static SubscriberTier fromRestrictionOptions(List<Object?> options) =>
      options.contains('ALLOW_TIER_3_ONLY')
      ? tier3
      : options.contains('ALLOW_TIER_2_AND_3_ONLY')
      ? tier2
      : any;
}
