import 'dart:convert';

import 'package:onset/models/playback_access_token.dart';

/// What a VOD playback token says about access (decoded from its JSON value).
class VodAccessInfo {
  const VodAccessInfo({
    required this.forbidden,
    required this.restrictedBitrates,
    this.reason,
    this.expiresAt,
    this.authenticated = false,
  });

  /// Tolerant: an unreadable value is treated as allowed, usher has the final
  /// word anyway.
  factory VodAccessInfo.fromTokenValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) throw const FormatException();
      final auth = decoded['authorization'];
      final chansub = decoded['chansub'];
      return VodAccessInfo(
        forbidden: auth is Map && auth['forbidden'] == true,
        reason: auth is Map && auth['reason'] is String && auth['reason'] != ''
            ? auth['reason'] as String
            : null,
        restrictedBitrates: [
          if (chansub is Map && chansub['restricted_bitrates'] is List)
            for (final b in chansub['restricted_bitrates'] as List)
              if (b is String) b,
        ],
        expiresAt: PlaybackAccessToken.parseExpiry(value),
        authenticated: switch (decoded['user_id']) {
          num() => true,
          final String id => id.isNotEmpty,
          _ => false,
        },
      );
    } on FormatException {
      return const VodAccessInfo(forbidden: false, restrictedBitrates: []);
    }
  }

  /// The token carried by an usher playlist URL (its `token` parameter);
  /// an unreadable URL reads as an anonymous, allowed token.
  factory VodAccessInfo.fromUsherUrl(String url) {
    final token = Uri.tryParse(url)?.queryParameters['token'];
    if (token == null) {
      return const VodAccessInfo(forbidden: false, restrictedBitrates: []);
    }
    return VodAccessInfo.fromTokenValue(token);
  }

  final bool forbidden;
  final String? reason;

  /// Qualities only subscribers can watch.
  final List<String> restrictedBitrates;
  final DateTime? expiresAt;

  /// Asked with a viewer's credentials (Twitch names the viewer in it): a
  /// refusal is then the viewer's own, not that of an anonymous visitor.
  final bool authenticated;
}
