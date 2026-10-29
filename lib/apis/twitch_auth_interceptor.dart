import 'package:dio/dio.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';

/// Dio interceptor that automatically adds Twitch authentication headers
/// to requests targeting Twitch API endpoints.
class TwitchAuthInterceptor extends Interceptor {
  final AuthStore _authStore;

  const TwitchAuthInterceptor(this._authStore);

  /// A request's `extra` flag: add none of the session's headers (a token
  /// of another app, checked with its own `Authorization` alone).
  static const noSessionHeaders = 'twitch_auth_no_session_headers';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Check if this is a Twitch API request that needs authentication
    if (options.extra[noSessionHeaders] != true &&
        _shouldAddTwitchHeaders(options.uri)) {
      // Add Twitch auth headers automatically, never over a token the
      // request names itself: validating a login page's token (or reading
      // its user) must use that token, not the session's.
      final twitchHeaders = _authStore.headersTwitch;
      for (final MapEntry(:key, :value) in twitchHeaders.entries) {
        final named = options.headers.keys.any(
          (name) => name.toLowerCase() == key.toLowerCase(),
        );
        if (!named) options.headers[key] = value;
      }
    }

    handler.next(options);
  }

  /// Determines if the request URL is for a Twitch API endpoint that requires authentication
  bool _shouldAddTwitchHeaders(Uri uri) {
    final url = uri.toString();

    // Add headers for Twitch Helix API and OAuth endpoints
    return url.startsWith('https://api.twitch.tv/helix') ||
        url.startsWith('https://id.twitch.tv/oauth2');
  }
}
