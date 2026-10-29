import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
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

/// One opened login page ([AuthBase.beginLogin]): the `state` its
/// authorization carries, and whether Twitch handed it a token. Several can
/// be open at once (a login opened over the onboarding's), each taking only
/// its own token.
class LoginAttempt {
  LoginAttempt._();

  String? _state;
  bool _captured = false;

  /// Whether the redirect brought this page's token back.
  bool get captured => _captured;
}

abstract class AuthBase with Store {
  /// Secure storage to store tokens.
  final FlutterSecureStorage _storage;

  /// The shared_preferences key for the default token.
  static const _defaultTokenKey = 'default_token';

  /// The shared_preferences key for the user token.
  static const _userTokenKey = 'user_token';

  /// The permissions asked for at login. A token from an older login keeps
  /// the scopes it had: what needs a newer one (creating clips) checks the
  /// token and offers to reconnect, instead of logging everyone out.
  static const loginScopes =
      'chat:read chat:edit user:read:follows user:read:blocked_users '
      'user:manage:blocked_users user:manage:chat_color '
      'moderator:manage:banned_users moderator:manage:chat_messages '
      'moderator:manage:chat_settings moderator:manage:warnings '
      'moderator:read:followers user:manage:whispers '
      'user:read:emotes user:read:chat clips:edit';

  /// Where the user token is kept, for the go-live background check (its
  /// own isolate, without this store).
  static const userTokenKey = _userTokenKey;

  /// The secure-storage key for the optional twitch.tv web session token.
  static const _twitchWebTokenKey = 'twitch_web_token';

  /// The id of the account last logged in, so a login knows whether the
  /// stored web token is that account's, also when its details are not
  /// loaded (a launch still reconnecting).
  static const _userIdKey = 'user_id';

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
  final TwitchWebTokenService _webTokenService;

  /// Loads twitch.tv so Twitch reissues its session cookie. Injected by tests;
  /// the app drives a detached WebView.
  late final Future<void> Function() _loadTwitchPage;

  /// Bumped on every logout, so a harvest or refresh that started before it
  /// can tell its result belongs to a session that no longer exists.
  var _authEpoch = 0;

  /// Whether the cookie jar can be read at all — only Android has the native
  /// channel. Off Android a jar miss says nothing about a token the user
  /// pasted by hand, so it must never mark the session expired.
  final bool _isAndroid;

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
    final epoch = _authEpoch;
    final harvested = await _webTokenService.readAuthToken();

    // Signed out while reading: the jar it read belonged to the session that
    // just ended, and storing it would hand the next account its token.
    if (epoch != _authEpoch) return false;

    if (harvested == null) {
      // Only a stored token going stale is worth reporting. Having never had
      // one is the normal state for a user who has not logged in yet — and
      // without a jar (off Android) there is nothing to judge staleness from.
      if (_isAndroid) _webSessionExpired = _twitchWebToken != null;
      return false;
    }

    _webSessionExpired = false;
    if (harvested == _twitchWebToken) return true;

    await setTwitchWebToken(harvested);
    debugPrint('Harvested a fresh twitch.tv web token from the cookie jar.');
    return true;
  }

  /// The silent refresh in flight, so overlapping callers share one page load
  /// instead of each starting their own.
  Future<bool>? _webSessionRefresh;

  /// Loads twitch.tv in a detached WebView so Twitch reissues the session
  /// cookie, then harvests it. Returns true when a token was obtained.
  ///
  /// This is what keeps 2K working without the user ever touching a setting.
  /// The `auth-token` cookie is long-lived but not renewable the way an OAuth
  /// token is: it only gets refreshed when a browser actually visits
  /// twitch.tv. The login WebView does that once and is then never used again,
  /// so without this the cookie would simply age out and playback would drop
  /// to 1080p with nothing to explain why.
  Future<bool> refreshTwitchWebSession() {
    // Android-only: the cookie jar is read through an Android channel, so
    // there is nothing to refresh into on other platforms.
    if (!_isAndroid) return Future.value(false);

    return _webSessionRefresh ??= _refreshWebSession().whenComplete(
      () => _webSessionRefresh = null,
    );
  }

  Future<bool> _refreshWebSession() async {
    // Signed out, there is no session to refresh: the page would load signed
    // out and only spend a request.
    if (!_isLoggedIn) return false;

    final epoch = _authEpoch;
    try {
      await _loadTwitchPage();
      if (epoch != _authEpoch || !_isLoggedIn) return false;
      return await harvestTwitchWebToken();
    } catch (e) {
      debugPrint('Silent twitch.tv session refresh failed: ${e.runtimeType}');
      return false;
    } finally {
      _releaseHiddenWebView();
    }
  }

  /// The detached WebView of the refresh in flight, if any.
  WebViewController? _hiddenWebView;

  /// Points the detached WebView at a blank page, so a page holding the
  /// session does not stay alive (and scripted) once its cookie is read.
  void _releaseHiddenWebView() {
    final controller = _hiddenWebView;
    _hiddenWebView = null;
    if (controller == null) return;
    unawaited(
      controller.loadRequest(Uri.parse('about:blank')).catchError((Object e) {
        debugPrint('Releasing the hidden WebView failed: ${e.runtimeType}');
      }),
    );
  }

  /// Drives a native WebView that only needs to fetch and run twitch.tv, not
  /// paint it: no widget is mounted.
  Future<void> _loadTwitchPageInWebView() async {
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
          onNavigationRequest: (request) =>
              TwitchWebTokenService.isTwitchPageUrl(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) => finish(),
          // A failed load still ends the wait: the harvest decides, and a
          // stale token is better diagnosed than hung on.
          onWebResourceError: (_) => finish(),
        ),
      );
    _hiddenWebView = controller;

    await controller.loadRequest(Uri.parse('https://www.twitch.tv/'));
    await loaded.future.timeout(const Duration(seconds: 20), onTimeout: () {});
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
    // No jar to refresh into: a pasted token stays as it is, and is not
    // declared dead on the strength of a read that cannot happen.
    if (!_isAndroid) return null;

    final previous = _twitchWebToken;

    // A refresh is already loading the page (the launch-time one, usually):
    // wait for it rather than start a second load, and leave the cooldown and
    // the expired flag alone — this call did not get a verdict of its own.
    final running = _webSessionRefresh;
    if (running != null) {
      await running;
      final current = _twitchWebToken;
      return current != null && current != previous ? current : null;
    }

    final lastRun = _lastWebTokenRenewal;
    if (lastRun != null &&
        clock.now().difference(lastRun) < _webTokenRenewalCooldown) {
      return null;
    }
    _lastWebTokenRenewal = clock.now();

    final epoch = _authEpoch;
    await refreshTwitchWebSession();
    // A logout during the load already forgot the session: no verdict.
    if (epoch != _authEpoch || !_isLoggedIn) return null;

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
  ///
  /// [onTokenCaptured] is given the login in flight when the redirect
  /// carried a token (the page can say "Signing you in…" until it ends, then
  /// read [isLoggedIn]); it is never given the token. [onSignedIn], when
  /// given, is called once Twitch has signed
  /// the WebView in, instead of the page being popped (the onboarding moves
  /// on to its next step itself).
  ///
  /// [attempt] is the page's own login: only its token is taken, and
  /// Twitch's sign-in counts only once that token came back; otherwise the
  /// page stays (nothing is popped, no next step) and [onNotSignedIn] is
  /// told. Without one, any open login's state is accepted.
  FutureOr<NavigationDecision> handleNavigation({
    required NavigationRequest request,
    Widget? routeAfter,
    ValueChanged<Future<void>>? onTokenCaptured,
    VoidCallback? onSignedIn,
    VoidCallback? onNotSignedIn,
    LoginAttempt? attempt,
  }) {
    // The redirect URI, exactly, and only for the page itself: a frame
    // inside it, another path or host, or a token without the state of the
    // login this app opened (an injected redirect: someone else's token,
    // which would sign the user into their account) is never taken.
    final token = _redirectToken(request, attempt);
    if (token != null) {
      final signingIn = login(token: token);
      onTokenCaptured?.call(signingIn);
    }

    // Check if the the URL has been redirected to "https://www.twitch.tv/?no-reload=true".
    // When redirected to the redirect_uri, there will be another redirect to "https://www.twitch.tv/?no-reload=true".
    // Checking for this will ensure that the user has automatically logged in to Twitch on the WebView itself.
    if (request.isMainFrame &&
        request.url == 'https://www.twitch.tv/?no-reload=true') {
      // Reaching this URL means Twitch has signed the user in inside the
      // WebView, so its jar now holds the `auth-token` cookie. Grab it here:
      // it is the only credential that unlocks the 1440p HEVC rendition, and
      // harvesting it now spares the user pasting it into settings by hand.
      // Deliberately not awaited — navigation must not wait on a cookie read.
      unawaited(harvestTwitchWebToken());

      final signedIn =
          attempt?.captured ?? _openLogins.any((open) => open.captured);
      if (!signedIn) {
        // Twitch signed the page in, but no token of this login came back
        // (the user said no, or another page's login was the one asked):
        // nothing is logged in, so nothing moves on.
        onNotSignedIn?.call();
      } else if (onSignedIn != null) {
        onSignedIn();
      } else if (routeAfter != null) {
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

  /// The login pages open now, each with the state its redirect must bring
  /// back.
  final _openLogins = <LoginAttempt>{};

  /// Opens a login (a login page): [authorizationUri] gives its address,
  /// [endLogin] closes it.
  LoginAttempt beginLogin() {
    final attempt = LoginAttempt._();
    _openLogins.add(attempt);
    return attempt;
  }

  /// Closes [attempt]: its state is no longer accepted.
  void endLogin(LoginAttempt attempt) {
    attempt._state = null;
    _openLogins.remove(attempt);
  }

  /// The token of [request] when it is Twitch's redirect for [attempt] (or,
  /// without one, for any open login), else null. The state is used up
  /// when it matches.
  String? _redirectToken(NavigationRequest request, LoginAttempt? attempt) {
    if (!request.isMainFrame) return null;
    final uri = Uri.tryParse(request.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'twitch.tv' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/login') {
      return null;
    }
    final Map<String, String> fragment;
    try {
      fragment = Uri.splitQueryString(uri.fragment);
    } on FormatException {
      return null;
    }
    final token = fragment['access_token'];
    final state = fragment['state'];
    if (token == null || token.isEmpty || state == null) return null;
    final candidates = attempt == null
        ? _openLogins.toList()
        : [if (_openLogins.contains(attempt)) attempt];
    for (final open in candidates) {
      final expected = open._state;
      if (expected != null && _sameText(state, expected)) {
        open
          .._state = null
          .._captured = true;
        return token;
      }
    }
    return null;
  }

  /// [a] == [b], in a time that does not tell how much of them matched.
  static bool _sameText(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// The Twitch authorization page for [attempt]: the implicit grant with
  /// this app's scopes, always asking the user to confirm them
  /// (`force_verify`), and a fresh unguessable `state` (32 random bytes)
  /// that the redirect must bring back. Asked again (Try again), the page
  /// gets a new state and its earlier one is no longer accepted.
  Uri authorizationUri(LoginAttempt attempt) {
    final random = Random.secure();
    final state = base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    _openLogins.add(attempt);
    attempt
      .._state = state
      .._captured = false;
    return Uri(
      scheme: 'https',
      host: 'id.twitch.tv',
      path: '/oauth2/authorize',
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': 'https://twitch.tv/login',
        'response_type': 'token',
        'scope': loginScopes,
        'force_verify': 'true',
        'state': state,
      },
    );
  }

  /// A new login's authorization page ([beginLogin] then
  /// [authorizationUri]).
  @visibleForTesting
  Uri startAuthorization() => authorizationUri(beginLogin());

  /// The login of each login WebView.
  final _loginOf = Expando<LoginAttempt>('login');

  /// Opens [controller]'s login again, with a new state (Try again).
  Future<void> retryLogin(WebViewController controller) {
    final attempt = _loginOf[controller] ??= beginLogin();
    return controller.loadRequest(authorizationUri(attempt));
  }

  /// [controller]'s page is gone: its login is closed.
  void closeLogin(WebViewController controller) {
    final attempt = _loginOf[controller];
    if (attempt != null) endLogin(attempt);
  }

  /// The login WebView's controller. [onTokenCaptured] and [onSignedIn] are
  /// passed to [handleNavigation]; [onPage] is told each page the WebView
  /// moves to (the login page shows its host, never the rest of the URL,
  /// which carries the token); [onError] each resource that failed to load.
  WebViewController createAuthWebViewController({
    Widget? routeAfter,
    ValueChanged<Future<void>>? onTokenCaptured,
    VoidCallback? onSignedIn,
    VoidCallback? onNotSignedIn,
    ValueChanged<Uri>? onPage,
    ValueChanged<WebResourceError>? onError,
  }) {
    final attempt = beginLogin();
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

    void page(String? url) {
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null && onPage != null) onPage(uri);
    }

    _loginOf[webViewController] = attempt;
    return webViewController
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => handleNavigation(
            request: request,
            routeAfter: routeAfter,
            onTokenCaptured: onTokenCaptured,
            onSignedIn: onSignedIn,
            onNotSignedIn: onNotSignedIn,
            attempt: attempt,
          ),
          onPageStarted: page,
          onUrlChange: (change) => page(change.url),
          onWebResourceError: (error) {
            debugPrint('Auth WebView error: ${error.description}');
            onError?.call(error);
          },
          onPageFinished: (url) async {
            page(url);
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
      ..loadRequest(authorizationUri(attempt));
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

  AuthBase({
    required this.twitchApi,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    TwitchWebTokenService webTokenService = const TwitchWebTokenService(),
    Future<void> Function()? loadTwitchPage,
    bool? isAndroid,
  }) : user = UserStore(twitchApi: twitchApi),
       _storage = storage,
       _webTokenService = webTokenService,
       _isAndroid = isAndroid ?? Platform.isAndroid {
    _loadTwitchPage = loadTwitchPage ?? _loadTwitchPageInWebView;
  }

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
          await _rememberUser(user.details!.id);

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
    // Who was logged in: a login as another account must not keep their
    // twitch.tv session token.
    String? previousId = user.details?.id;
    try {
      previousId ??= await _rememberedUser();

      // Validate the custom token.
      _tokenIsValid = await twitchApi.validateToken(token: token);
      if (!_tokenIsValid) return;

      // Replace the current default token with the new custom token.
      _token = token;

      // Store the user token.
      await _storage.write(key: _userTokenKey, value: token);

      // Initialize the user with the new token.
      await user.init();

      // Another account: the stored web token is the previous one's (its
      // playback, watch positions and shelf would be theirs). It goes, and
      // a session read still in flight is dropped (it may have stored the
      // new account's token already, or be about to store either); the jar
      // is read again at once, as the login page just put the new account's
      // cookie there. The cookies are kept.
      final newId = user.details?.id;
      if (previousId != null && newId != null && newId != previousId) {
        _authEpoch++;
        await setTwitchWebToken(null);
        if (_isAndroid) unawaited(harvestTwitchWebToken());
      }

      // Set the login status to logged in.
      if (user.details != null) {
        _isLoggedIn = true;
        await _rememberUser(user.details!.id);
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
    // First, and before anything that can throw: a silent refresh still in
    // flight must not store the session being ended, and the twitch.tv
    // session must go even if reading the user token below fails.
    _authEpoch++;
    _stopReconnectLoop();
    await _forgetWebSession();

    try {
      // Revoke the user token so it stops working everywhere; logging out
      // goes on even when Twitch cannot be reached.
      final userToken = await _storage.read(key: _userTokenKey);
      if (userToken != null) unawaited(_revoke(userToken));
      // Delete the existing user token.
      await _storage.delete(key: _userTokenKey);
      await _storage.delete(key: _userIdKey);
      _token = null;

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

  /// Drops every trace of the twitch.tv session: the stored web token, the
  /// WebView cookies (follow, report and chat pages, and the `auth-token`
  /// the next login would otherwise silently reuse) and the hidden page.
  ///
  /// Never throws: each step is attempted whatever the previous one did.
  Future<void> _forgetWebSession() async {
    _releaseHiddenWebView();
    _twitchWebToken = null;
    _webSessionExpired = false;

    try {
      await WebViewCookieManager().clearCookies();
    } catch (e) {
      debugPrint('Clearing twitch.tv cookies failed: ${e.runtimeType}');
    }
    try {
      await _webTokenService.clearCookies();
    } catch (e) {
      debugPrint('Clearing the cookie jar failed: ${e.runtimeType}');
    }
    try {
      await _storage.delete(key: _twitchWebTokenKey);
    } catch (e) {
      debugPrint('Forgetting the web token failed: ${e.runtimeType}');
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
          await _rememberUser(user.details!.id);
        }
      } on ApiException catch (_) {
        // Continue trying
      } catch (e) {
        debugPrint('Reconnect loop error: $e');
      }
    });
  }

  /// Keeps [id] as the account last logged in. Best effort: a keystore that
  /// refuses it never changes a login or a launch (the next one tries
  /// again).
  Future<void> _rememberUser(String id) async {
    try {
      await _storage.write(key: _userIdKey, value: id);
    } catch (e) {
      debugPrint('Saving the account id failed: ${e.runtimeType}');
    }
  }

  /// The account last logged in, or null (unknown, or unreadable).
  Future<String?> _rememberedUser() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (e) {
      debugPrint('Reading the account id failed: ${e.runtimeType}');
      return null;
    }
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }
}
