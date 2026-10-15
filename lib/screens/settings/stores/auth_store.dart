import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/main.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:frosty/widgets/frosty_dialog.dart';
import 'package:mobx/mobx.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'auth_store.g.dart';

class AuthStore = AuthBase with _$AuthStore;

abstract class AuthBase with Store {
  /// Secure storage to store tokens.
  static const _storage = FlutterSecureStorage();

  /// The shared_preferences key for the default token.
  static const _defaultTokenKey = 'default_token';

  /// The shared_preferences key for the user token.
  static const _userTokenKey = 'user_token';

  /// Where the user token is kept, for the go-live background check (its
  /// own isolate, without this store).
  static const userTokenKey = _userTokenKey;

  /// The secure-storage key for the optional twitch.tv web session token.
  static const _twitchWebTokenKey = 'twitch_web_token';

  /// The Twitch API service for making requests.
  final TwitchApi twitchApi;

  /// Whether the token is valid or not.
  var _tokenIsValid = false;

  /// Timer used to retry authentication when offline or on transient failures.
  Timer? _reconnectTimer;

  /// Retry count for reconnection attempts.
  var _reconnectAttempts = 0;

  /// Maximum number of reconnection attempts before giving up.
  static const _maxReconnectAttempts = 5;

  /// The MobX store containing information relevant to the current user.
  final UserStore user;

  /// The user token used to authenticate with the Twitch API.
  @readonly
  String? _token;

  /// Whether the user is logged in or not.
  @readonly
  var _isLoggedIn = false;

  /// Optional twitch.tv web session token (the `auth-token` cookie).
  ///
  /// Twitch's GQL endpoint only accepts tokens minted for its own web
  /// client-id, so Frosty's own login token cannot unlock the
  /// enhanced-broadcast renditions (1440p HEVC / AV1). Pasting the web token
  /// in the video settings lets the player request them; when it is absent
  /// everything falls back to the anonymous request.
  @readonly
  String? _twitchWebToken;

  /// Reads the twitch.tv session cookie out of the login WebView's jar.
  final _webTokenService = const TwitchWebTokenService();

  /// True once a harvest has run and come back empty, meaning the twitch.tv
  /// session behind the enhanced-broadcast renditions is gone.
  ///
  /// Nothing can renew it silently at that point — only a real twitch.tv login
  /// mints a new `auth-token` — so the UI uses this to ask once instead of
  /// letting playback drop to 1080p without explanation.
  @readonly
  var _webSessionExpired = false;

  /// Harvests the twitch.tv `auth-token` cookie and stores it when present.
  ///
  /// Returns true when a token was found. Never clears an existing token on a
  /// miss: the user may have pasted one by hand, and a transient read failure
  /// must not throw away a working credential.
  @action
  Future<bool> harvestTwitchWebToken() async {
    final harvested = await _webTokenService.readAuthToken();

    if (harvested == null) {
      // Only a stored token going stale is worth reporting. Having never had
      // one is the normal state for a user who has not logged in yet.
      _webSessionExpired = _twitchWebToken != null;
      return false;
    }

    _webSessionExpired = false;
    if (harvested == _twitchWebToken) return true;

    await setTwitchWebToken(harvested);
    debugPrint('Harvested a fresh twitch.tv web token from the cookie jar.');
    return true;
  }

  /// Guards against overlapping silent refreshes.
  var _refreshingWebSession = false;

  /// Loads twitch.tv in a detached WebView so Twitch reissues the session
  /// cookie, then harvests it. Returns true when a token was obtained.
  ///
  /// This is what keeps 2K working without the user ever touching a setting.
  /// The `auth-token` cookie is long-lived but not renewable the way an OAuth
  /// token is: it only gets refreshed when a browser actually visits
  /// twitch.tv. The login WebView does that once and is then never used again,
  /// so without this the cookie would simply age out and playback would drop
  /// to 1080p with nothing to explain why.
  ///
  /// No widget is mounted: the controller drives a native WebView that only
  /// needs to fetch and run the page, not paint it.
  Future<bool> refreshTwitchWebSession() async {
    // Android-only: the cookie jar is read through an Android channel, so
    // there is nothing to refresh into on other platforms.
    if (!Platform.isAndroid || _refreshingWebSession) return false;

    _refreshingWebSession = true;
    try {
      final loaded = Completer<void>();
      void finish() {
        if (!loaded.isCompleted) loaded.complete();
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // Same UA as the login WebView: Twitch serves a different session
        // flow to clients it reads as embedded WebViews.
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => finish(),
            // A failed load still ends the wait: the harvest below decides,
            // and a stale token is better diagnosed than hung on.
            onWebResourceError: (_) => finish(),
          ),
        );

      await controller.loadRequest(Uri.parse('https://www.twitch.tv/'));
      await loaded.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {},
      );

      return await harvestTwitchWebToken();
    } catch (e) {
      debugPrint('Silent twitch.tv session refresh failed: $e');
      return false;
    } finally {
      _refreshingWebSession = false;
    }
  }

  /// When the last renewal ran, so a channel that keeps failing cannot spawn a
  /// page load per attempt.
  DateTime? _lastWebTokenRenewal;

  /// How long to wait before another renewal is worth attempting.
  static const _webTokenRenewalCooldown = Duration(minutes: 5);

  /// Mints a replacement web token after Twitch refused the stored one.
  ///
  /// Distinct from [ensureTwitchWebToken]: that one trusts the cookie jar,
  /// which is exactly what cannot be trusted here. A refused token is usually
  /// still sitting in the jar, so re-reading it would hand back the same dead
  /// value. This forces a real twitch.tv load and only accepts a token that
  /// actually changed.
  ///
  /// Returns the new token, or null when the twitch.tv session itself is gone
  /// — the one case no amount of refreshing can fix, which is why it flips
  /// [webSessionExpired] so the UI can say so instead of silently serving
  /// 1080p.
  @action
  Future<String?> renewTwitchWebToken() async {
    final previous = _twitchWebToken;

    final lastRun = _lastWebTokenRenewal;
    if (lastRun != null &&
        DateTime.now().difference(lastRun) < _webTokenRenewalCooldown) {
      return null;
    }
    _lastWebTokenRenewal = DateTime.now();

    await refreshTwitchWebSession();

    final current = _twitchWebToken;
    if (current == null || current == previous) {
      _webSessionExpired = true;
      return null;
    }

    return current;
  }

  /// Makes sure a usable web token is on hand, refreshing the session when the
  /// cookie jar has nothing to give.
  ///
  /// Cheap in the common case: the jar read short-circuits before any network
  /// work happens.
  Future<bool> ensureTwitchWebToken() async {
    if (await harvestTwitchWebToken()) return true;
    return refreshTwitchWebSession();
  }

  /// Stores (or clears, when [token] is null or blank) the twitch.tv web
  /// session token used to unlock the enhanced-broadcast renditions.
  @action
  Future<void> setTwitchWebToken(String? token) async {
    final trimmed = token?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _twitchWebToken = value;
    if (value != null) _webSessionExpired = false;

    if (value == null) {
      await _storage.delete(key: _twitchWebTokenKey);
    } else {
      await _storage.write(key: _twitchWebTokenKey, value: value);
    }
  }

  /// Authentication headers for Twitch API requests.
  @computed
  Map<String, String> get headersTwitch => {
    'Authorization': 'Bearer $_token',
    'Client-Id': clientId,
  };

  /// Error flag that will be non-null and contain an error message if login failed.
  @readonly
  String? _error;

  /// Navigation handler for the login webview. Fires on every navigation request (whenever the URL changes).
  FutureOr<NavigationDecision> handleNavigation({
    required NavigationRequest request,
    Widget? routeAfter,
  }) {
    // Check if the URL is the redirect URI.
    if (request.url.startsWith('https://twitch.tv/login')) {
      // Extract the token from the query parameters.
      final uri = Uri.parse(request.url.replaceFirst('#', '?'));
      final token = uri.queryParameters['access_token'];

      // Login with the provided token.
      if (token != null) login(token: token);
    }

    // Check if the the URL has been redirected to "https://www.twitch.tv/?no-reload=true".
    // When redirected to the redirect_uri, there will be another redirect to "https://www.twitch.tv/?no-reload=true".
    // Checking for this will ensure that the user has automatically logged in to Twitch on the WebView itself.
    if (request.url == 'https://www.twitch.tv/?no-reload=true') {
      // Reaching this URL means Twitch has signed the user in inside the
      // WebView, so its jar now holds the `auth-token` cookie. Grab it here:
      // it is the only credential that unlocks the 1440p HEVC rendition, and
      // harvesting it now spares the user pasting it into settings by hand.
      // Deliberately not awaited — navigation must not wait on a cookie read.
      unawaited(harvestTwitchWebToken());

      if (routeAfter != null) {
        navigatorKey.currentState?.pop();
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => routeAfter),
        );
      } else {
        // Pop the WebView to return to the previous screen
        navigatorKey.currentState?.pop();
      }
    }

    // Always allow navigation to the next URL.
    return NavigationDecision.navigate;
  }

  WebViewController createAuthWebViewController({Widget? routeAfter}) {
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Use platform-specific user agents to allow Google OAuth sign-in.
      // Google blocks OAuth in embedded WebViews (error 403: disallowed_useragent)
      // by detecting WebView markers. These standard browser UAs work around that.
      ..setUserAgent(
        Platform.isIOS
            ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'
            : 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36',
      );

    return webViewController
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              handleNavigation(request: request, routeAfter: routeAfter),
          onWebResourceError: (error) {
            debugPrint('Auth WebView error: ${error.description}');
          },
          onPageFinished: (_) async {
            try {
              await webViewController.runJavaScript('''
                {
                  function modifyElement(element) {
                    element.style.maxHeight = '20vh';
                    element.style.overflow = 'auto';
                  }

                  const observer = new MutationObserver((mutations) => {
                    for (let mutation of mutations) {
                      if (mutation.type === 'childList') {
                        const element = document.querySelector('.fAVISI');
                        if (element) {
                          modifyElement(element);
                          observer.disconnect();
                          break;
                        }
                      }
                    }
                  });

                  observer.observe(document.body, {
                    childList: true,
                    subtree: true
                  });
                }
                ''');
            } catch (e) {
              debugPrint('Auth WebView JavaScript error: $e');
            }
          },
        ),
      )
      ..loadRequest(
        Uri(
          scheme: 'https',
          host: 'id.twitch.tv',
          path: '/oauth2/authorize',
          queryParameters: {
            'client_id': clientId,
            'redirect_uri': 'https://twitch.tv/login',
            'response_type': 'token',
            'scope':
                'chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color '
                'moderator:manage:banned_users moderator:manage:chat_messages '
                'moderator:manage:chat_settings moderator:manage:warnings '
                'moderator:read:followers user:manage:whispers '
                'user:read:emotes user:read:chat',
            'force_verify': 'true',
          },
        ),
      );
  }

  /// Shows a dialog verifying that the user is sure they want to block/unblock the target user.
  Future<void> showBlockDialog(
    BuildContext context, {
    required String targetUser,
    required String targetUserId,
  }) {
    final isBlocked = user.blockedUsers
        .where((blockedUser) => blockedUser.userId == targetUserId)
        .isNotEmpty;

    final title = isBlocked ? 'Unblock' : 'Block';

    final message =
        'Are you sure you want to ${isBlocked ? 'unblock "$targetUser"?' : 'block "$targetUser"? This will remove them from channel lists, search results, and chat messages.'}';

    void onPressed() {
      if (isBlocked) {
        user.unblock(targetId: targetUserId);
      } else {
        user.block(targetId: targetUserId, displayName: targetUser);
      }
      Navigator.pop(context);
    }

    return showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: title,
        message: message,
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: onPressed, child: const Text('Yes')),
        ],
      ),
    );
  }

  AuthBase({required this.twitchApi}) : user = UserStore(twitchApi: twitchApi);

  /// Initialize by retrieving a token if it does not already exist.
  @action
  Future<void> init() async {
    try {
      // Read and set the currently stored user token, if any.
      _token = await _storage.read(key: _userTokenKey);

      // Restore the optional twitch.tv web token used for enhanced-broadcast
      // renditions; its absence is not an error.
      _twitchWebToken = await _storage.read(key: _twitchWebTokenKey);


      // If the token does not exist, get the default token.
      // Otherwise, log in.
      if (_token == null) {
        // Retrieve the currently stored default token if it exists.
        _token = await _storage.read(key: _defaultTokenKey);
        // If the token does not exist or is invalid, get a new token and store it.
        if (_token == null || !await twitchApi.validateToken(token: _token!)) {
          _token = await twitchApi.getDefaultToken();
          await _storage.write(key: _defaultTokenKey, value: _token);
        }
      } else {
        // Validate the existing token. If it fails, start reconnect loop.
        try {
          _tokenIsValid = await twitchApi.validateToken(token: _token!);
        } on ApiException catch (e) {
          debugPrint('Token validation failed: $e');
          _isLoggedIn = false;
          _startReconnectLoop();
          return;
        }

        // If the token is invalid, logout.
        if (!_tokenIsValid) return await logout();

        // Initialize the user store.
        await user.init();

        if (user.details != null) {
          _isLoggedIn = true;
          _stopReconnectLoop();

          // Keep the 2K credential fresh on every launch, but only once we
          // know there is a session to refresh — running this while logged out
          // would just load a signed-out page for nothing. Not awaited: this
          // fork exists to cut latency, and startup must not wait on a page
          // load.
          unawaited(ensureTwitchWebToken());
        }
      }

      FirebaseCrashlytics.instance.setCustomKey('is_logged_in', _isLoggedIn);
      _error = null;
    } catch (e) {
      debugPrint(e.toString());
      _error = e.toString();
    }
  }

  /// Logs in the user with the provided [token] and updates fields accordingly upon successful login.
  @action
  Future<void> login({required String token}) async {
    try {
      // Validate the custom token.
      _tokenIsValid = await twitchApi.validateToken(token: token);
      if (!_tokenIsValid) return;

      // Replace the current default token with the new custom token.
      _token = token;

      // Store the user token.
      await _storage.write(key: _userTokenKey, value: token);

      // Initialize the user with the new token.
      await user.init();

      // Set the login status to logged in.
      if (user.details != null) {
        _isLoggedIn = true;
        FirebaseCrashlytics.instance.setCustomKey('is_logged_in', true);
        FirebaseCrashlytics.instance.setUserIdentifier(user.details!.id);
        _stopReconnectLoop();
      }
    } catch (e) {
      debugPrint('Login failed due to $e');
    }
  }

  /// Logs out the current user and updates fields accordingly.
  @action
  Future<void> logout() async {
    try {
      _stopReconnectLoop();
      // Revoke the user token so it stops working everywhere; logging out
      // goes on even when Twitch cannot be reached.
      final userToken = await _storage.read(key: _userTokenKey);
      if (userToken != null) unawaited(_revoke(userToken));
      // Delete the existing user token.
      await _storage.delete(key: _userTokenKey);
      // Sign the in-app twitch.tv pages out too (follow, report, chat).
      try {
        await WebViewCookieManager().clearCookies();
      } catch (e) {
        debugPrint('Clearing twitch.tv cookies failed: $e');
      }
      _token = null;

      // Drop the twitch.tv session too. Leaving the cookie behind would let
      // the next login silently reuse the previous account's session, and
      // would keep serving 2K for an account the user just signed out of.
      await _webTokenService.clearCookies();
      await setTwitchWebToken(null);
      _webSessionExpired = false;

      // Clear the user info.
      user.dispose();

      // If the default token already exists, set it.
      _token = await _storage.read(key: _defaultTokenKey);

      // If the default token does not already exist or it's invalid, get the new default token and store it.
      if (_token == null || !await twitchApi.validateToken(token: _token!)) {
        _token = await twitchApi.getDefaultToken();
        await _storage.write(key: _defaultTokenKey, value: _token);
      }

      // Set the login status to logged out.
      _isLoggedIn = false;
      FirebaseCrashlytics.instance.setCustomKey('is_logged_in', false);
      FirebaseCrashlytics.instance.setUserIdentifier('');

      debugPrint('Successfully logged out');
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// Revokes [token] at Twitch; never throws.
  Future<void> _revoke(String token) async {
    try {
      await twitchApi
          .revokeToken(token: token)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Token revoke failed: $e');
    }
  }

  void _startReconnectLoop() {
    if (_reconnectTimer != null) return;
    _reconnectAttempts = 0;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        _reconnectAttempts++;
        if (_reconnectAttempts > _maxReconnectAttempts) {
          FirebaseCrashlytics.instance.log(
            'Auth reconnection exhausted after $_maxReconnectAttempts attempts',
          );
          await logout();
          return;
        }

        final stored = await _storage.read(key: _userTokenKey);
        if (stored == null) {
          _stopReconnectLoop();
          return;
        }

        final isValid = await twitchApi.validateToken(token: stored);
        if (!isValid) {
          await logout();
          return;
        }

        // Token valid again — restore session.
        _token = stored;
        await user.init();
        if (user.details != null) {
          _isLoggedIn = true;
          _error = null;
          _stopReconnectLoop();
        }
      } on ApiException catch (_) {
        // Continue trying
      } catch (e) {
        debugPrint('Reconnect loop error: $e');
      }
    });
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }
}
