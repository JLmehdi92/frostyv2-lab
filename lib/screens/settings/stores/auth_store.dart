import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/constants.dart';
import 'package:onset/main.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';
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

  /// The outcome of the login its token started.
  Future<bool>? _outcome;

  /// Whether the redirect brought this page's token back.
  bool get captured => _captured;
}

abstract class AuthBase with Store {
  /// Secure storage to store tokens.
  final FlutterSecureStorage _storage;

  /// The shared_preferences key for the default token.
  static const _defaultTokenKey = 'default_token';

  /// The app the default token was issued to, when it is not this one (the
  /// token proxy's own Twitch application): it goes out as the Client-Id.
  static const _defaultTokenClientIdKey = 'default_token_client_id';

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

  /// The app the stored user token was issued to, when it is not this one
  /// (kept with the token, deleted with it): the go-live background check
  /// and the revoke on logout need it.
  static const _userTokenClientIdKey = 'user_token_client_id';

  /// Where [_userTokenClientIdKey] is kept, for the go-live background
  /// check.
  static const userTokenClientIdKey = _userTokenClientIdKey;

  /// The account last told that its token was created for another app (the
  /// notice is shown once).
  static const _foreignNoticeKey = 'foreign_token_notice_user';

  /// What the app says once when the session's token was issued to another
  /// app (stored by an older version, or pasted from another tool).
  static const foreignTokenNotice =
      'This token was created for another app — some features may not work.';

  /// What the app says once when Twitch refused the stored login at launch
  /// (it expired, was revoked, or its app no longer exists, as after an
  /// update that changes ONSET's Twitch application): logged out, the
  /// viewer is told to log in again instead of finding out later.
  static const sessionEndedNotice =
      'Your Twitch session has ended. Log in again from Settings.';

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

  /// The app [_token] was issued to when it is not this one (a token the
  /// viewer brought from another tool): Helix only takes a token with its
  /// own app's Client-Id. Null for this app's tokens.
  @readonly
  String? _tokenClientId;

  /// Whether the user is logged in or not.
  @readonly
  var _isLoggedIn = false;

  /// Optional twitch.tv web session token (the `auth-token` cookie).
  ///
  /// Twitch's GQL endpoint only accepts tokens minted for its own web
  /// client-id, so the app's own login token cannot unlock the
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

  /// Bumped when a logout starts and again when it ends: a harvest checks
  /// it around its write, so nothing it read while the session was ending
  /// stays stored after. Logins never look at it (one may start during a
  /// slow logout and must still commit after it).
  var _webSessionEpoch = 0;

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
    final webEpoch = _webSessionEpoch;
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

    if (harvested == _twitchWebToken) {
      _webSessionExpired = false;
      return true;
    }

    // The jar is shared by every login page: it may hold the cookie of an
    // account that is not the session's (a login that failed after Twitch
    // signed its page in). Only a cookie of the logged-in account is kept.
    if (!await _isSessionAccounts(harvested, epoch) ||
        webEpoch != _webSessionEpoch) {
      return false;
    }

    _webSessionExpired = false;
    await setTwitchWebToken(harvested);
    // A logout (or a switch) came during the write: what was just written
    // belongs to a session that is gone.
    if (epoch != _authEpoch || webEpoch != _webSessionEpoch) {
      if (_twitchWebToken == harvested) _twitchWebToken = null;
      try {
        await _storage.delete(key: _twitchWebTokenKey);
      } catch (e) {
        debugPrint('Dropping a stale web token failed: ${e.runtimeType}');
      }
      return false;
    }
    debugPrint('Harvested a fresh twitch.tv web token from the cookie jar.');
    return true;
  }

  /// Whether [webToken] is the logged-in account's, still within [epoch].
  /// Signed out, or when Twitch cannot be asked, it is not.
  Future<bool> _isSessionAccounts(String webToken, int epoch) async {
    final account = _isLoggedIn ? user.details?.id : null;
    if (account == null) return false;
    try {
      final owner = await twitchApi.tokenUserId(webToken);
      return owner == account &&
          epoch == _authEpoch &&
          _isLoggedIn &&
          user.details?.id == account;
    } catch (e) {
      debugPrint('Checking the twitch.tv cookie failed: ${e.runtimeType}');
      return false;
    }
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
  ///
  /// No `Authorization` without a token (logged out while the token proxy
  /// could not give one): Twitch answers 401 either way, and a literal
  /// `Bearer null` is not sent.
  ///
  /// A plain getter, not `@computed`: MobX prints every computed in the
  /// store's `toString`, and this one holds the token. It still reads the
  /// observable token and client id, so observers follow them.
  Map<String, String> get headersTwitch => {
    if (_token != null) 'Authorization': 'Bearer $_token',
    'Client-Id': _tokenClientId ?? clientId,
  };

  /// Error flag that will be non-null and contain an error message if login failed.
  @readonly
  String? _error;

  /// A notice for the viewer about the session ([foreignTokenNotice],
  /// [sessionEndedNotice]), until it is shown ([clearTokenNotice]). Never
  /// the token.
  @readonly
  String? _tokenNotice;

  /// The notice was shown.
  @action
  void clearTokenNotice() => _tokenNotice = null;

  /// The session's token is another app's: [foreignTokenNotice], once for
  /// [userId]'s account.
  Future<void> _noticeForeignToken(String userId) async {
    try {
      if (await _storage.read(key: _foreignNoticeKey) == userId) return;
      await _storage.write(key: _foreignNoticeKey, value: userId);
    } catch (e) {
      debugPrint('Token notice state unavailable: ${e.runtimeType}');
    }
    runInAction(() => _tokenNotice = foreignTokenNotice);
  }

  /// Navigation handler for the login webview. Fires on every navigation request (whenever the URL changes).
  ///
  /// [onTokenCaptured] is given the outcome of the login in flight when the
  /// redirect carried a token (the page can say "Signing you in…" until it
  /// ends): true only when that token itself signed in, never merely because
  /// someone is logged in already; it is never given the token. [onSignedIn], when
  /// given, is called once Twitch has signed
  /// the WebView in, instead of the page being popped (the onboarding moves
  /// on to its next step itself).
  ///
  /// [attempt] is the page's own login: only its token is taken. When Twitch
  /// signs the page in without that token having come back (the user said
  /// no), [onNotSignedIn] is told first; the page then moves on as before
  /// ([onSignedIn], or the pop), without any token. Without an attempt, any
  /// open login's state is accepted.
  FutureOr<NavigationDecision> handleNavigation({
    required NavigationRequest request,
    Widget? routeAfter,
    ValueChanged<Future<bool>>? onTokenCaptured,
    VoidCallback? onSignedIn,
    VoidCallback? onNotSignedIn,
    LoginAttempt? attempt,
  }) {
    // The redirect URI, exactly, and only for the page itself: a frame
    // inside it, another path or host, or a token without the state of the
    // login this app opened (an injected redirect: someone else's token,
    // which would sign the user into their account) is never taken.
    final captured = _redirectToken(request, attempt);
    if (captured != null) {
      final (token, owner) = captured;
      final outcome = owner._outcome = _loginWith(token);
      onTokenCaptured?.call(outcome);
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
      // Only once this page's login is known to have gone through: a login
      // that failed keeps the previous account, whose web token must not
      // become the other account's cookie. Deliberately not awaited —
      // navigation must not wait on a cookie read.
      final outcome = attempt != null
          ? attempt._outcome
          : _openLogins
                .map((open) => open._outcome)
                .whereType<Future<bool>>()
                .firstOrNull;
      if (outcome != null) {
        unawaited(
          outcome
              .then((worked) async {
                if (worked) return harvestTwitchWebToken();
                // The page may have signed the shared jar in as an account
                // that is not the session's: then its twitch.tv session goes.
                await _clearJarIfForeign();
                return false;
              })
              .catchError((Object _) => false),
        );
      }

      final signedIn =
          attempt?.captured ?? _openLogins.any((open) => open.captured);
      // Without this page's token (the user said no), nothing is logged in:
      // the page is told, and moves on as it always did (nothing is taken).
      if (!signedIn) onNotSignedIn?.call();
      if (onSignedIn != null) {
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

  /// The token the last successful [login] signed in with (in memory only),
  /// so a login page can tell its own outcome from someone being logged in
  /// already.
  String? _signedInWith;

  /// [login] with [token], then whether that login itself went through
  /// (not merely whether someone is logged in).
  Future<bool> _loginWith(String token) async {
    await login(token: token);
    return _isLoggedIn && _token == token && _signedInWith == token;
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
    attempt
      .._state = null
      .._captured = false
      .._outcome = null;
    _openLogins.remove(attempt);
  }

  /// The token of [request] and the login it belongs to, when it is
  /// Twitch's redirect for [attempt] (or, without one, for any open login),
  /// else null. The state is used up when it matches.
  (String, LoginAttempt)? _redirectToken(
    NavigationRequest request,
    LoginAttempt? attempt,
  ) {
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
        return (token, open);
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
      .._captured = false
      .._outcome = null;
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
    ValueChanged<Future<bool>>? onTokenCaptured,
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
      builder: (context) => OnsetAlertDialog(
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
        await _useAppToken();
      } else {
        // Validate the existing token. If it fails, start reconnect loop.
        // Any token Twitch accepts stays signed in, as it always did: one of
        // another app (stored by an older version, pasted from another
        // tool) gets a notice instead of a logout.
        final TokenCheck check;
        try {
          check = await twitchApi.checkToken(token: _token!);
          _tokenIsValid = !check.isInvalid;
          _tokenClientId = check.clientId;
          if (_tokenIsValid) await _saveTokenClientId(check.clientId);
        } on ApiException catch (e) {
          debugPrint('Token validation failed: $e');
          _isLoggedIn = false;
          _signedInWith = null;
          _startReconnectLoop();
          return;
        }

        // If the token is invalid, logout, and say so.
        if (!_tokenIsValid) {
          await logout();
          runInAction(() => _tokenNotice = sessionEndedNotice);
          return;
        }

        // Initialize the user store.
        await user.init();

        if (user.details != null) {
          _isLoggedIn = true;
          _stopReconnectLoop();
          await _rememberUser(user.details!.id);
          if (check.isForeign) await _noticeForeignToken(user.details!.id);

          // Keep the 2K credential fresh on every launch, but only once we
          // know there is a session to refresh — running this while logged out
          // would just load a signed-out page for nothing. Not awaited: this
          // fork exists to cut latency, and startup must not wait on a page
          // load.
          unawaited(ensureTwitchWebToken());
        }
      }

      Telemetry.setCustomKey('is_logged_in', _isLoggedIn);
      _error = null;
    } catch (e) {
      debugPrint(e.toString());
      _error = e.toString();
    }
  }

  /// How often a logged-out viewer's app token is looked at again after a
  /// Helix 401 ([retryAppToken]).
  static const appTokenRetryInterval = Duration(minutes: 1);

  /// When the app token was last asked for or checked after a 401.
  DateTime? _appTokenAskedAt;

  /// The app token in use while logged out, so a session can tell it from a
  /// user's ([isAnonymous]).
  String? _appToken;

  /// Whether this is a logged-out viewer's session: no user token, only the
  /// app token, or none. False while a user's session reconnects.
  bool get isAnonymous =>
      !_isLoggedIn && (_token == null || _token == _appToken);

  /// Puts a logged-out session's app token in place (launch, logout): the
  /// stored one when Twitch still takes it, else a new one from the token
  /// proxy, else none. Throws an [ApiException] when Twitch cannot say
  /// whether the stored one is still good; it is then kept.
  Future<void> _useAppToken() async {
    final stored = await _storage.read(key: _defaultTokenKey);
    String? storedClient;
    try {
      storedClient = await _storage.read(key: _defaultTokenClientIdKey);
    } catch (e) {
      debugPrint('Reading the app token app failed: ${e.runtimeType}');
    }
    _token = stored;
    _tokenClientId = storedClient;
    _appToken = stored;
    if (stored != null && await _appTokenIsGood(stored, storedClient)) return;

    final fresh = await _fetchAppToken();
    _token = fresh?.token;
    _tokenClientId = fresh?.clientId;
    _appToken = fresh?.token;
  }

  /// Whether Twitch still takes the app [token] as one of [client], the
  /// proxy's application. Network failures throw.
  ///
  /// A token stored without its application ([client] null) is never good:
  /// older builds minted it for the login application, whose app tokens
  /// could reach its users' private events, so it is replaced by the
  /// proxy's without even asking Twitch.
  Future<bool> _appTokenIsGood(String token, String? client) async {
    if (client == null) return false;
    final check = await twitchApi.checkToken(token: token);
    return check.isForeign && !check.hasUser && check.clientId == client;
  }

  /// A new app token from the token proxy, checked with Twitch and stored
  /// with its app for the next launches; null when there is none to be had
  /// (no proxy in this build, the proxy or the network down, a token Twitch
  /// refuses, one of the login application or of a user, or one that is not
  /// of the app the proxy named). The app then runs without one: the
  /// logged-out features that need Helix fail quietly, everything else
  /// works, logging in included, so this is not an [error].
  Future<({String token, String? clientId})?> _fetchAppToken() async {
    _appTokenAskedAt = clock.now();
    final AppToken fresh;
    final TokenCheck check;
    try {
      fresh = await twitchApi.getDefaultToken();
      check = await twitchApi.checkToken(token: fresh.token);
    } on ApiException catch (e) {
      debugPrint('No app token: $e');
      return null;
    }
    // Only an app token of the proxy's own application: one of the login
    // application (a Worker set up with its credentials) could subscribe to
    // the private events of everyone who logged in, and a user's token is
    // someone's account. Neither is used, whatever Twitch says of it.
    final String? refusal = check.isInvalid
        ? 'Twitch refuses it'
        : check.isValid
        ? "it is the login application's (check the Worker's credentials)"
        : check.hasUser
        ? "it is a user's token"
        : check.clientId != fresh.clientId
        ? 'it is not the application the proxy named'
        : null;
    if (refusal != null) {
      debugPrint('No app token from the proxy: $refusal.');
      return null;
    }
    final String client = fresh.clientId;
    try {
      await _storage.write(key: _defaultTokenKey, value: fresh.token);
      await _storage.write(key: _defaultTokenClientIdKey, value: client);
    } catch (e) {
      debugPrint('Saving the app token failed: ${e.runtimeType}');
    }
    return (token: fresh.token, clientId: client);
  }

  /// A logged-out viewer's Helix call was refused (401), [refused] being
  /// the `Authorization` it was sent with (`UnauthorizedInterceptor`, which
  /// shows a logged-out viewer no login dialog). At most once per
  /// [appTokenRetryInterval]:
  ///
  /// - without an app token (the proxy or the network was down), the proxy
  ///   is asked again;
  /// - with one, Twitch is asked whether it still takes it. If not (it
  ///   expired, or someone revoked the shared token), it is dropped and a
  ///   new one asked for; if so, that call needed a login, not a token, and
  ///   the token stays.
  ///
  /// Nothing changes once a login or a logout decided the session.
  Future<void> retryAppToken({String? refused}) async {
    if (!isAnonymous) return;
    final asked = _appTokenAskedAt;
    if (asked != null &&
        clock.now().difference(asked) < appTokenRetryInterval) {
      return;
    }
    _appTokenAskedAt = clock.now();
    final epoch = _authEpoch;
    final generation = _loginGeneration;
    bool undecided() =>
        !_isLoggedIn &&
        epoch == _authEpoch &&
        generation == _loginGeneration &&
        _loginsInFlight == 0;

    final current = _token;
    if (current != null) {
      // Only a refusal of the token in use says anything about it.
      if (refused != 'Bearer $current') return;
      try {
        if (await _appTokenIsGood(current, _tokenClientId)) return;
      } on ApiException catch (e) {
        debugPrint('The app token could not be checked: $e');
        return;
      }
      var dropped = false;
      await _exclusive(() async {
        if (!undecided() || _token != current) return;
        runInAction(() {
          _token = null;
          _tokenClientId = null;
        });
        _appToken = null;
        dropped = true;
        try {
          await _storage.delete(key: _defaultTokenKey);
          await _storage.delete(key: _defaultTokenClientIdKey);
        } catch (e) {
          debugPrint('Forgetting the app token failed: ${e.runtimeType}');
        }
      });
      if (!dropped) return;
    }

    final fresh = await _fetchAppToken();
    if (fresh == null) return;
    // Only into the logged-out session it was asked for.
    await _exclusive(() async {
      if (!undecided() || _token != null) return;
      runInAction(() {
        _token = fresh.token;
        _tokenClientId = fresh.clientId;
      });
      _appToken = fresh.token;
    });
  }

  /// Bumped by every [login] as it starts: only the newest one may commit.
  var _loginGeneration = 0;

  /// Logins between their start and their end: the reconnect loop waits.
  var _loginsInFlight = 0;

  /// The session changes ([login]'s commit, [logout], the reconnect loop's
  /// restore) one at a time.
  Future<void> _sessionChange = Future.value();

  Future<void> _exclusive(Future<void> Function() change) {
    final done = _sessionChange.then((_) => change());
    _sessionChange = done.catchError((Object _) {});
    return done;
  }

  /// Logs in the user with the provided [token] and updates fields accordingly upon successful login.
  ///
  /// The token must have been issued to this app (a login page could be
  /// handed someone else's), unless [acceptAnyApp]: a token the viewer
  /// brought themselves (pasted), which signs in whatever app it was made
  /// for, with [foreignTokenNotice] when it is another app's.
  ///
  /// Nothing of the session changes until the token is validated and its
  /// user read (with that token, not the session's): then, one at a time
  /// with any other session change, the token is saved (and, for another
  /// account, the previous one's web token deleted) first, and the session
  /// switches in memory only once those writes went through. A write that
  /// fails puts back what was written, and the previous session stays,
  /// in memory and on disk. A later login, or a logout, while this one runs
  /// wins: this one then changes nothing.
  @action
  Future<void> login({required String token, bool acceptAnyApp = false}) async {
    final generation = ++_loginGeneration;
    final epoch = _authEpoch;
    _loginsInFlight++;
    try {
      // Who was logged in: a login as another account must not keep their
      // twitch.tv session token.
      final previousId = user.details?.id ?? await _rememberedUser();

      // Validate the custom token.
      final TokenCheck check;
      if (acceptAnyApp) {
        check = await twitchApi.checkToken(token: token);
        if (check.isInvalid) return;
      } else {
        if (!await twitchApi.validateToken(token: token)) return;
        check = TokenCheck.valid;
      }

      // The token's user, read with that token (and its app's Client-Id).
      final foreignClient = check.clientId;
      final details = foreignClient == null
          ? await twitchApi.getUserInfo(token: token)
          : await twitchApi.getUserInfo(token: token, clientId: foreignClient);

      await _exclusive(() async {
        // A later login or a logout came meanwhile: it wins.
        if (generation != _loginGeneration || epoch != _authEpoch) return;

        final switching = previousId != null && details.id != previousId;

        // On disk first: the token's app before the token, so that a token
        // never sits beside another token's app (a refusal fails the login
        // with nothing changed).
        final savedBefore = await _storage.read(key: _userTokenKey);
        final savedClientBefore = await _storage.read(
          key: _userTokenClientIdKey,
        );
        await _writeTokenClientId(foreignClient);
        try {
          await _storage.write(key: _userTokenKey, value: token);
        } catch (_) {
          await _restoreTokenClientId(savedClientBefore);
          rethrow;
        }
        if (switching) {
          // Another account: the stored web token is the previous one's (its
          // playback, watch positions and shelf would be theirs). It goes.
          try {
            await _storage.delete(key: _twitchWebTokenKey);
          } catch (_) {
            await _restoreSavedToken(savedBefore);
            await _restoreTokenClientId(savedClientBefore);
            rethrow;
          }
        }
        await _rememberUser(details.id);

        // Then in memory. Another account: a session read still in flight
        // is dropped (it may be about to store the previous account's token,
        // or this one's), and the jar is read again at once, as the login
        // page just put the new account's cookie there. The cookies are kept.
        if (switching) {
          _authEpoch++;
          _twitchWebToken = null;
        }
        _token = token;
        _tokenClientId = foreignClient;
        _tokenIsValid = true;
        await user.init(details: details);
        _isLoggedIn = true;
        _signedInWith = token;
        _error = null;
        Telemetry.setCustomKey('is_logged_in', true);
        _stopReconnectLoop();
        if (switching && _isAndroid) unawaited(harvestTwitchWebToken());
        if (check.isForeign) await _noticeForeignToken(details.id);
      });
    } catch (e) {
      debugPrint('Login failed: ${e.runtimeType}');
    } finally {
      _loginsInFlight--;
    }
  }

  /// Puts the saved user token back as it was before a login wrote it.
  Future<void> _restoreSavedToken(String? saved) async {
    try {
      if (saved == null) {
        await _storage.delete(key: _userTokenKey);
      } else {
        await _storage.write(key: _userTokenKey, value: saved);
      }
    } catch (e) {
      debugPrint('Restoring the saved token failed: ${e.runtimeType}');
    }
  }

  /// Logs out the current user and updates fields accordingly.
  @action
  Future<void> logout() async {
    // First, and before anything that can throw: a silent refresh still in
    // flight must not store the session being ended, and the twitch.tv
    // session must go even if reading the user token below fails.
    _authEpoch++;
    _webSessionEpoch++;
    _stopReconnectLoop();
    await _exclusive(_endSession);
  }

  Future<void> _endSession() async {
    await _forgetWebSession();

    try {
      // Revoke the user token so it stops working everywhere; logging out
      // goes on even when Twitch cannot be reached.
      final userToken = await _storage.read(key: _userTokenKey);
      String? tokenClient;
      try {
        tokenClient = await _storage.read(key: _userTokenClientIdKey);
      } catch (e) {
        debugPrint('Reading the token app failed: ${e.runtimeType}');
      }
      if (userToken != null) unawaited(_revoke(userToken, tokenClient));
      // Delete the existing user token.
      await _storage.delete(key: _userTokenKey);
      await _saveTokenClientId(null);
      await _storage.delete(key: _userIdKey);
      _token = null;
      _tokenClientId = null;

      // Clear the user info.
      user.dispose();

      // The logged-out session's app token. Offline, Twitch cannot say
      // whether the stored one is still good: it is kept, and the logout
      // goes on (it used to stop here, logged in without a user).
      try {
        await _useAppToken();
      } on ApiException catch (e) {
        debugPrint('The app token could not be checked: $e');
      }

      // Set the login status to logged out.
      _isLoggedIn = false;
      _signedInWith = null;
      Telemetry.setCustomKey('is_logged_in', false);

      debugPrint('Successfully logged out');
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      // Again at the end: a harvest that read the jar while the session was
      // ending must not store it now that it is gone.
      _webSessionEpoch++;
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

  /// Clears the jar after a login page's login failed, only when its
  /// twitch.tv session is another account's than the session's: never the
  /// session account's own (a failed re-login for a new scope), never when
  /// nobody is logged in, never while
  /// a newer login runs (it may be that cookie's), never when Twitch cannot
  /// tell whose it is (the harvest check keeps it out of the session anyway).
  /// The WebView API can only clear every cookie, so the condition is
  /// strict.
  Future<void> _clearJarIfForeign() async {
    try {
      // Logged out, there is nothing to protect, and the jar may hold the
      // user's fresh twitch.tv sign-in.
      if (_loginsInFlight > 0 || !_isLoggedIn || user.details == null) return;
      final cookie = await _webTokenService.readAuthToken();
      if (cookie == null) return;
      final owner = await twitchApi.tokenUserId(cookie);
      if (owner == null || _loginsInFlight > 0) return;
      final account = _isLoggedIn ? user.details?.id : null;
      if (account == null || owner == account) return;
      await _clearJar();
    } catch (e) {
      debugPrint('Checking the login page cookie failed: ${e.runtimeType}');
    }
  }

  /// Clears the WebView cookies (the twitch.tv session in them); never
  /// throws.
  Future<void> _clearJar() async {
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
  }

  /// Revokes [token] at Twitch; never throws.
  Future<void> _revoke(String token, [String? tokenClientId]) async {
    try {
      await (tokenClientId == null
              ? twitchApi.revokeToken(token: token)
              : twitchApi.revokeToken(token: token, clientId: tokenClientId))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Token revoke failed: $e');
    }
  }

  void _startReconnectLoop() {
    if (_reconnectTimer != null) return;
    _reconnectAttempts = 0;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      // A login is running: it decides the session; this tick waits.
      if (_loginsInFlight > 0) return;
      final generation = _loginGeneration;
      final epoch = _authEpoch;
      try {
        _reconnectAttempts++;
        final stored = await _storage.read(key: _userTokenKey);
        if (_reconnectAttempts > _maxReconnectAttempts) {
          Telemetry.log(
            'Auth reconnection exhausted after $_maxReconnectAttempts attempts',
          );
          await _logoutFromReconnect(generation, epoch, stored);
          return;
        }

        if (stored == null) {
          _stopReconnectLoop();
          return;
        }

        // Any token Twitch accepts, as at launch.
        final check = await twitchApi.checkToken(token: stored);
        if (check.isInvalid) {
          await _logoutFromReconnect(generation, epoch, stored);
          return;
        }

        // Token valid again — restore session, unless a login or a logout
        // came meanwhile (it decided the session).
        await _exclusive(() async {
          if (generation != _loginGeneration ||
              epoch != _authEpoch ||
              _loginsInFlight > 0) {
            return;
          }
          _token = stored;
          _tokenClientId = check.clientId;
          await _saveTokenClientId(check.clientId);
          await user.init();
          if (user.details != null) {
            _isLoggedIn = true;
            _error = null;
            _stopReconnectLoop();
            await _rememberUser(user.details!.id);
            if (check.isForeign) await _noticeForeignToken(user.details!.id);
          }
        });
      } on ApiException catch (_) {
        // Continue trying
      } catch (e) {
        debugPrint('Reconnect loop error: $e');
      }
    });
  }

  /// The reconnect loop gives up on [checked] (the token it read, at
  /// [generation] / [epoch]): a logout, one session change at a time, and
  /// only if nothing changed since — no login started or committed, no
  /// logout, the saved token still the one it checked. Otherwise the session
  /// was decided by someone else, and this verdict on an old token says
  /// nothing about it.
  @action
  Future<void> _logoutFromReconnect(
    int generation,
    int epoch,
    String? checked,
  ) => _exclusive(() async {
    if (generation != _loginGeneration ||
        epoch != _authEpoch ||
        _loginsInFlight > 0) {
      return;
    }
    final saved = await _storage.read(key: _userTokenKey);
    if (saved != checked ||
        generation != _loginGeneration ||
        epoch != _authEpoch ||
        _loginsInFlight > 0) {
      return;
    }
    _authEpoch++;
    _webSessionEpoch++;
    _stopReconnectLoop();
    await _endSession();
  });

  /// Keeps the stored user token's app ([clientId], null for this app's),
  /// beside the token. Best effort: without it the background check and
  /// the revoke use this app's client id.
  Future<void> _saveTokenClientId(String? clientId) async {
    try {
      await _writeTokenClientId(clientId);
    } catch (e) {
      debugPrint('Saving the token app failed: ${e.runtimeType}');
    }
  }

  /// Stores the user token's app ([clientId], null for this app's); throws
  /// when the keystore refuses.
  Future<void> _writeTokenClientId(String? clientId) async {
    if (clientId == null) {
      await _storage.delete(key: _userTokenClientIdKey);
    } else {
      await _storage.write(key: _userTokenClientIdKey, value: clientId);
    }
  }

  /// Puts the stored token's app back as it was before a login wrote it.
  Future<void> _restoreTokenClientId(String? saved) async {
    try {
      await _writeTokenClientId(saved);
    } catch (e) {
      debugPrint('Restoring the token app failed: ${e.runtimeType}');
    }
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
