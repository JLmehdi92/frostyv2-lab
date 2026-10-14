import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frosty/apis/twitch_web_session_service.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:mobx/mobx.dart';

part 'web_session_store.g.dart';

/// The `auth-token` cookie in a `document.cookie` string (the raw value a
/// WebView returns may be JSON-quoted), or null.
String? authTokenFromCookies(String cookies) {
  var text = cookies.trim();
  if (text.startsWith('"')) {
    try {
      text = jsonDecode(text) as String;
    } catch (_) {
      return null;
    }
  }
  for (final part in text.split(';')) {
    final index = part.indexOf('=');
    if (index == -1) continue;
    if (part.substring(0, index).trim() != 'auth-token') continue;
    final value = part.substring(index + 1).trim();
    return TwitchWebSessionService.tokenPattern.hasMatch(value) ? value : null;
  }
  return null;
}

class WebSessionStore = WebSessionStoreBase with _$WebSessionStore;

/// The viewer's twitch.tv session, picked up from the login page so the app
/// can do what only twitch.tv itself may do (follow, channel points…). It
/// stays on the device (secure storage), is checked with Twitch at launch,
/// and goes away on logout.
abstract class WebSessionStoreBase with Store {
  WebSessionStoreBase({
    required this.service,
    required this.authStore,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage {
    _logoutReaction = reaction(
      (_) => authStore.isLoggedIn,
      (bool loggedIn) {
        if (!loggedIn) unawaited(disconnect());
      },
    );
  }

  static const _tokenKey = 'twitch_web_auth_token';
  static const _loginKey = 'twitch_web_auth_login';

  final TwitchWebSessionService service;
  final AuthStore authStore;
  final FlutterSecureStorage _storage;
  late final ReactionDisposer _logoutReaction;

  /// Never observable or shown: only sent to Twitch's GQL.
  String? _token;

  /// The account the session belongs to.
  @readonly
  String? _login;

  /// Why the last connection failed, for the account screen.
  @readonly
  String? _error;

  /// The session for GQL calls; null while there is none, or when it is
  /// another account than the one logged in.
  String? get token => isConnected ? _token : null;

  @computed
  bool get isConnected {
    final login = _login;
    if (login == null) return false;
    final current = authStore.user.details?.login;
    return current == null || current.toLowerCase() == login.toLowerCase();
  }

  /// Reads the saved session and checks it is still valid.
  Future<void> init() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return;
    final savedLogin = await _storage.read(key: _loginKey);
    _token = token;
    runInAction(() => _login = savedLogin);
    try {
      final info = await service.validate(token);
      if (info == null || !info.isWebSession) {
        await disconnect();
        return;
      }
      runInAction(() => _login = info.login);
    } catch (e) {
      // Offline: keep the saved session.
      debugPrint('Web session check failed: $e');
    }
  }

  /// Connects with the session found in the login page's [cookies];
  /// returns whether one was found and accepted.
  Future<bool> connectFromCookies(String cookies) async {
    final token = authTokenFromCookies(cookies);
    if (token == null) return false;
    return connect(token);
  }

  /// Checks [token] with Twitch and keeps it when it is a twitch.tv session
  /// of the logged-in account.
  Future<bool> connect(String token) async {
    runInAction(() => _error = null);
    try {
      final info = await service.validate(token);
      if (info == null || !info.isWebSession) {
        runInAction(() => _error = 'Twitch did not accept this session');
        return false;
      }
      final current = authStore.user.details?.login;
      if (current != null && current.toLowerCase() != info.login) {
        runInAction(
          () => _error = 'The session is for ${info.login}, not $current',
        );
        return false;
      }
      _token = token;
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _loginKey, value: info.login);
      runInAction(() => _login = info.login);
      return true;
    } catch (e) {
      debugPrint('Web session connect failed: $e');
      runInAction(() => _error = 'Could not reach Twitch');
      return false;
    }
  }

  /// Forgets the session (logout, or the user's choice).
  Future<void> disconnect() async {
    _token = null;
    runInAction(() {
      _login = null;
      _error = null;
    });
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loginKey);
  }

  void dispose() => _logoutReaction();
}
