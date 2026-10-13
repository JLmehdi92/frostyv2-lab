import 'dart:convert';

import 'package:frosty/models/playback_access_token.dart';

/// What a VOD playback token says about access (decoded from its JSON value).
class VodAccessInfo {
  const VodAccessInfo({
    required this.forbidden,
    required this.restrictedBitrates,
    this.reason,
    this.expiresAt,
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
      );
    } on FormatException {
      return const VodAccessInfo(forbidden: false, restrictedBitrates: []);
    }
  }

  final bool forbidden;
  final String? reason;

  /// Qualities only subscribers can watch.
  final List<String> restrictedBitrates;
  final DateTime? expiresAt;
}
