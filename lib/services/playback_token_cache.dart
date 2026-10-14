import 'package:frosty/models/playback_access_token.dart';

/// In-memory cache of playback access tokens per channel login, so reloads,
/// refreshes and reopening a channel skip the GQL round trip while the token
/// is still valid.
///
/// Tokens are anonymous (the GQL request carries only the public Client-ID,
/// no user OAuth), so one cache serves every account. If a user token is ever
/// sent with that request, key the cache by user and clear it on logout.
///
/// Tokens are never persisted or logged. A token without a known expiry is
/// never cached, and a [safetyMargin] before expiry avoids handing out a token
/// that would expire mid-request.
class PlaybackTokenCache {
  PlaybackTokenCache({
    DateTime Function()? now,
    this.safetyMargin = const Duration(seconds: 60),
    this.capacity = 32,
  }) : assert(capacity >= 0),
       _now = now ?? DateTime.now;

  /// App-wide cache shared by every IVS player.
  static final shared = PlaybackTokenCache();

  final DateTime Function() _now;
  final Duration safetyMargin;
  final int capacity;

  // Map literals keep insertion order: the first key is the least recently
  // used one.
  final _entries = <String, PlaybackAccessToken>{};

  PlaybackAccessToken? get(String login) {
    final key = login.toLowerCase();
    final token = _entries.remove(key);
    if (token == null) return null;
    if (!_isValid(token)) return null;
    _entries[key] = token; // mark as most recently used
    return token;
  }

  void put(String login, PlaybackAccessToken token) {
    if (!_isValid(token)) return;
    final key = login.toLowerCase();
    _entries
      ..remove(key)
      ..[key] = token;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidate(String login) => _entries.remove(login.toLowerCase());

  final _pending = <String, Future<PlaybackAccessToken>>{};

  /// The token being asked for [login] right now (a preload), if any.
  Future<PlaybackAccessToken>? pending(String login) =>
      _pending[login.toLowerCase()];

  /// Shares [token]'s request with whoever asks for [login] meanwhile.
  void track(String login, Future<PlaybackAccessToken> token) {
    final key = login.toLowerCase();
    _pending[key] = token;
    void done() {
      if (identical(_pending[key], token)) _pending.remove(key);
    }

    token.then((_) => done(), onError: (Object _) => done());
  }

  bool _isValid(PlaybackAccessToken token) {
    final expiresAt = token.expiresAt;
    if (expiresAt == null) return false;
    return _now().add(safetyMargin).isBefore(expiresAt);
  }
}
