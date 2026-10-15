import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads the twitch.tv web session token (`auth-token`) out of the in-app
/// WebView's cookie jar.
///
/// Why this exists: Twitch only serves the enhanced-broadcast renditions
/// (1440p60 HEVC / AV1) to a viewer whose `PlaybackAccessToken` request is
/// authenticated, and its GQL endpoint only honours allowlisted client-ids.
/// The fork's own OAuth token is minted for the fork's client-id, so it is
/// rejected — measured, not assumed. The one credential that works is the
/// `auth-token` cookie a real twitch.tv login leaves behind.
///
/// The login flow already performs that login inside a `webview_flutter`
/// WebView, so the cookie is sitting in the app's own jar. This service reads
/// it, which turns a setting the user had to paste by hand into something that
/// happens on its own.
class TwitchWebTokenService {
  /// [isAndroid] overrides the platform check, for tests.
  const TwitchWebTokenService({bool? isAndroid})
    : _isAndroidOverride = isAndroid;

  final bool? _isAndroidOverride;

  /// Only Android has the native side of the channel.
  bool get _isAndroid => _isAndroidOverride ?? Platform.isAndroid;

  static const _channel = MethodChannel('frosty/cookies');

  /// The URL whose jar entry is read. `auth-token` is set on the `.twitch.tv`
  /// domain, so it is returned for any twitch.tv host.
  static const twitchUrl = 'https://www.twitch.tv';

  /// Whether the hidden session WebView may load [url]: https on twitch.tv
  /// or one of its subdomains, plus the blank page it is parked on.
  ///
  /// That WebView runs with JavaScript and the viewer's session cookies and
  /// nobody sees it, so a redirect anywhere else — another site, an
  /// `intent:` or `file:` URL — is refused rather than followed.
  static bool isTwitchPageUrl(String url) {
    if (url == 'about:blank') return true;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return uri.host == 'twitch.tv' || uri.host.endsWith('.twitch.tv');
  }

  /// Returns the current `auth-token` cookie, or null when the jar holds none
  /// (not logged in on the WebView, or the session has expired).
  ///
  /// Returns null on platforms without the native channel rather than
  /// throwing: the manual field in video settings stays as the fallback, so a
  /// missing token degrades to the previous behaviour instead of an error.
  Future<String?> readAuthToken() async {
    if (!_isAndroid) return null;

    try {
      final raw = await _channel.invokeMethod<String>('getCookie', {
        'url': twitchUrl,
      });
      return parseAuthToken(raw);
    } on PlatformException catch (e) {
      debugPrint('Could not read the twitch.tv cookie jar: ${e.message}');
      return null;
    } on MissingPluginException {
      // Older build without the native side; fall back to the manual field.
      return null;
    }
  }

  /// Extracts `auth-token` from a raw `name=value; name=value` cookie header.
  ///
  /// Exposed for testing: the parsing is the part that can silently return the
  /// wrong thing, since Twitch sets several cookies whose names contain
  /// "token" (`auth-token`, `twitch.lohp.countryCode`, CSRF pairs).
  @visibleForTesting
  static String? parseAuthToken(String? rawCookies) {
    if (rawCookies == null || rawCookies.isEmpty) return null;

    for (final pair in rawCookies.split(';')) {
      final separator = pair.indexOf('=');
      if (separator == -1) continue;

      final name = pair.substring(0, separator).trim();
      if (name != 'auth-token') continue;

      final value = pair.substring(separator + 1).trim();
      return value.isEmpty ? null : value;
    }

    return null;
  }

  /// Clears the WebView cookie jar, dropping the twitch.tv session.
  ///
  /// Used on logout so the next login starts from a clean slate instead of
  /// silently reusing the previous account's session.
  Future<void> clearCookies() async {
    if (!_isAndroid) return;

    try {
      await _channel.invokeMethod<void>('clearCookies');
    } on PlatformException catch (e) {
      debugPrint('Could not clear the cookie jar: ${e.message}');
    } on MissingPluginException {
      // Nothing to clear without the native side.
    }
  }
}
