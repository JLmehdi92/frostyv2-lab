import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/models/twitch_tv_session.dart';

part 'twitch_tv_session_store.g.dart';

enum TwitchTvSessionStatus { disconnected, connected, expired }

enum TwitchTvConnectOutcome {
  connected,
  expired,
  denied,
  wrongAccount,
  cancelled,
  failed,
}

typedef TwitchTvWait = Future<void> Function(Duration delay);

class TwitchTvSessionStore = TwitchTvSessionBase with _$TwitchTvSessionStore;

abstract class TwitchTvSessionBase with Store {
  TwitchTvSessionBase({
    required TwitchTvAuthService auth,
    required String? Function() viewerId,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    Random? random,
    TwitchTvWait? wait,
  }) : _auth = auth,
       _viewerId = viewerId,
       _storage = storage,
       _random = random ?? Random.secure(),
       _wait = wait ?? Future<void>.delayed {
    clientSessionId = _hex(16);
  }

  final TwitchTvAuthService _auth;
  final String? Function() _viewerId;
  final FlutterSecureStorage _storage;
  final Random _random;
  final TwitchTvWait _wait;

  static const sessionKey = 'twitch_tv_session';
  static const promptedKey = 'twitch_tv_prompted';
  static const refreshRetry = Duration(seconds: 30);
  static const _checkAttempts = 3;

  late final String clientSessionId;

  @readonly
  TwitchTvSession? _session;

  @readonly
  var _status = TwitchTvSessionStatus.disconnected;

  String? _accountId;
  var _generation = 0;
  Future<void>? _refreshing;
  final _forgottenTokens = <String>{};

  bool get hasAccount => _accountId != null;

  bool get isConnected => _status == TwitchTvSessionStatus.connected;

  String? get accessToken => credentials?.session.accessToken;

  TwitchTvCredentials? get credentials {
    final session = _session;
    if (!isConnected ||
        session == null ||
        session.userId != _accountId ||
        session.userId != _viewerId()) {
      return null;
    }
    return TwitchTvCredentials(
      session: session,
      clientSessionId: clientSessionId,
    );
  }

  @action
  Future<void> attach(String accountId) async {
    if (_accountId == accountId && _session != null) return;
    final generation = ++_generation;
    _accountId = accountId;
    _session = null;
    _status = TwitchTvSessionStatus.disconnected;
    final stored = TwitchTvSession.decode(await _read(sessionKey));
    if (generation != _generation || stored == null) return;
    if (_forgottenTokens.contains(stored.accessToken)) {
      await _delete(sessionKey);
      return;
    }
    if (stored.userId != accountId) {
      _revoke(stored.accessToken);
      await _delete(sessionKey);
      return;
    }
    await _adopt(stored, generation);
  }

  @action
  void detach() {
    _generation++;
    _accountId = null;
    _session = null;
    _status = TwitchTvSessionStatus.disconnected;
  }

  @action
  Future<void> _adopt(TwitchTvSession stored, int generation) async {
    _session = stored;
    _status = TwitchTvSessionStatus.connected;
    final check = await _auth.validate(stored.accessToken);
    if (generation != _generation) return;
    switch (check.validity) {
      case TwitchTvValidity.valid when check.userId == stored.userId:
      case TwitchTvValidity.unknown:
        return;
      case TwitchTvValidity.valid:
        await forget();
      case TwitchTvValidity.invalid:
        await _refreshOnce(generation);
    }
  }

  void markRejected(String rejectedToken) {
    if (!isConnected || _session?.accessToken != rejectedToken) return;
    unawaited(_refreshOnce(_generation));
  }

  Future<void> _refreshOnce(int generation) {
    return _refreshing ??= _refresh(generation).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> _refresh(int generation) async {
    while (true) {
      final session = _session;
      final refreshToken = session?.refreshToken;
      if (session == null || refreshToken == null) {
        _setStatus(TwitchTvSessionStatus.expired, generation);
        return;
      }
      final refresh = await _auth.refresh(refreshToken);
      if (generation != _generation) return;
      switch (refresh.outcome) {
        case TwitchTvRefreshOutcome.rejected:
          _setStatus(TwitchTvSessionStatus.expired, generation);
          return;
        case TwitchTvRefreshOutcome.unreachable:
          await _wait(refreshRetry);
          if (generation != _generation) return;
        case TwitchTvRefreshOutcome.granted:
          await _renew(session, refresh.grant!, generation);
          return;
      }
    }
  }

  Future<void> _renew(
    TwitchTvSession session,
    TwitchTvGrant grant,
    int generation,
  ) async {
    final check = await _auth.validate(grant.accessToken);
    if (generation != _generation) return;
    if (check.validity == TwitchTvValidity.invalid ||
        (check.userId != null && check.userId != session.userId)) {
      _setStatus(TwitchTvSessionStatus.expired, generation);
      return;
    }
    final renewed = session.withGrant(grant);
    await _write(sessionKey, renewed.encode());
    if (generation != _generation) return;
    runInAction(() {
      _session = renewed;
      _status = TwitchTvSessionStatus.connected;
    });
  }

  void _setStatus(TwitchTvSessionStatus status, int generation) {
    if (generation != _generation) return;
    runInAction(() => _status = status);
  }

  Future<TwitchTvDeviceCode?> requestCode() => _auth.requestDeviceCode();

  Future<TwitchTvConnectOutcome> approve(
    TwitchTvDeviceCode code, {
    required bool Function() isCancelled,
  }) async {
    final accountId = _accountId;
    if (accountId == null) return TwitchTvConnectOutcome.failed;
    var interval = code.interval;
    var failures = 0;
    while (true) {
      await _wait(interval);
      if (isCancelled()) return TwitchTvConnectOutcome.cancelled;
      final poll = await _auth.pollToken(code);
      if (isCancelled()) {
        if (poll case TwitchTvPollGranted(:final grant)) {
          _revoke(grant.accessToken);
        }
        return TwitchTvConnectOutcome.cancelled;
      }
      switch (poll) {
        case TwitchTvPollPending():
          failures = 0;
        case TwitchTvPollSlowDown():
          failures = 0;
          interval += const Duration(seconds: 5);
        case TwitchTvPollExpired():
          return TwitchTvConnectOutcome.expired;
        case TwitchTvPollDenied():
          return TwitchTvConnectOutcome.denied;
        case TwitchTvPollFailed():
          if (++failures >= 3) return TwitchTvConnectOutcome.failed;
        case TwitchTvPollGranted(:final grant):
          return _store(grant, accountId, isCancelled);
      }
    }
  }

  Future<TwitchTvValidation> _checkGrant(String accessToken) async {
    var check = await _auth.validate(accessToken);
    for (
      var attempt = 1;
      attempt < _checkAttempts && check.validity == TwitchTvValidity.unknown;
      attempt++
    ) {
      await _wait(const Duration(seconds: 2));
      check = await _auth.validate(accessToken);
    }
    return check;
  }

  Future<TwitchTvConnectOutcome> _store(
    TwitchTvGrant grant,
    String accountId,
    bool Function() isCancelled,
  ) async {
    final check = await _checkGrant(grant.accessToken);
    if (isCancelled() || _accountId != accountId) {
      _revoke(grant.accessToken);
      return TwitchTvConnectOutcome.cancelled;
    }
    if (check.validity != TwitchTvValidity.valid) {
      _revoke(grant.accessToken);
      return TwitchTvConnectOutcome.failed;
    }
    if (check.userId != accountId) {
      _revoke(grant.accessToken);
      return TwitchTvConnectOutcome.wrongAccount;
    }
    final session = TwitchTvSession(
      accessToken: grant.accessToken,
      refreshToken: grant.refreshToken,
      userId: accountId,
      deviceId: _session?.deviceId ?? _hex(16),
    );
    final generation = ++_generation;
    await _write(sessionKey, session.encode());
    if (generation != _generation) return TwitchTvConnectOutcome.cancelled;
    runInAction(() {
      _session = session;
      _status = TwitchTvSessionStatus.connected;
    });
    return TwitchTvConnectOutcome.connected;
  }

  @action
  Future<void> forget() async {
    final token = _session?.accessToken;
    _generation++;
    _session = null;
    _status = TwitchTvSessionStatus.disconnected;
    if (token != null) {
      _forgottenTokens.add(token);
      _revoke(token);
    }
    await _delete(sessionKey);
  }

  @action
  Future<void> endAccountSession() async {
    _accountId = null;
    await forget();
    await _delete(promptedKey);
  }

  void _revoke(String token) {
    try {
      unawaited(_auth.revoke(token).catchError((Object _) {}));
    } catch (e) {
      debugPrint('Revoking the Twitch session failed: ${e.runtimeType}');
    }
  }

  Future<bool> shouldPrompt() async => await _read(promptedKey) != 'true';

  Future<void> markPrompted() => _write(promptedKey, 'true');

  String _hex(int bytes) => List.generate(
    bytes,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Reading the Twitch session failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Saving the Twitch session failed: ${e.runtimeType}');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Forgetting the Twitch session failed: ${e.runtimeType}');
    }
  }
}
