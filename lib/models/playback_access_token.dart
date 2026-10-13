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
  });

  factory PlaybackAccessToken.fromValue({
    required String value,
    required String signature,
  }) => PlaybackAccessToken(
    value: value,
    signature: signature,
    expiresAt: parseExpiry(value),
  );

  final String value;
  final String signature;

  /// When the token stops being accepted (null when unknown).
  final DateTime? expiresAt;

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
