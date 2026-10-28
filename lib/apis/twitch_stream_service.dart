import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/hls_variant.dart';
import 'package:frosty/models/playback_access_token.dart';
import 'package:frosty/services/playback_token_cache.dart';

/// Fetches the raw Twitch HLS playlist for a channel so it can be played by a
/// native low-latency player instead of the Twitch web embed.
///
/// Flow: POST a `PlaybackAccessToken` to Twitch GQL using the public web
/// client-id, then GET the usher `.m3u8` master playlist with low-latency flags.
///
/// This bypasses the official embed and is intended for personal builds only;
/// the caller is expected to fall back to the WebView engine if this throws.
class TwitchStreamService extends BaseApiClient {
  /// Public web client-id used by twitch.tv itself (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static const _usherBase = 'https://usher.ttvnw.net/api/channel/hls';

  /// The full GQL document for the access token, asking why a stream would
  /// be refused. Using the raw query (instead of a persisted-query hash)
  /// avoids `PersistedQueryNotFound` if Twitch rotates hashes.
  @visibleForTesting
  static const accessTokenQuery =
      '$_accessTokenQueryHead'
      '    value signature authorization { forbiddenReasonCode } __typename'
      '$_accessTokenQueryTail';

  /// The same without the reason, for when Twitch no longer accepts that
  /// field: playing matters more than knowing why it would not.
  @visibleForTesting
  static const plainAccessTokenQuery =
      '$_accessTokenQueryHead'
      '    value signature __typename'
      '$_accessTokenQueryTail';

  static const _accessTokenQueryHead =
      'query PlaybackAccessToken_Template(\$login: String!, \$isLive: Boolean!, '
      '\$vodID: ID!, \$isVod: Boolean!, \$playerType: String!) {'
      '  streamPlaybackAccessToken(channelName: \$login, params: {platform: "web", '
      'playerBackend: "mediaplayer", playerType: \$playerType}) @include(if: \$isLive) {';

  static const _accessTokenQueryTail =
      '  }'
      '  videoPlaybackAccessToken(id: \$vodID, params: {platform: "web", '
      'playerBackend: "mediaplayer", playerType: \$playerType}) @include(if: \$isVod) {'
      '    value signature __typename'
      '  }'
      '}';

  final Dio _http;

  /// Optional token cache (null = always ask GQL, the previous behaviour).
  final PlaybackTokenCache? _tokenCache;

  /// The refusal of each channel's last token (absent when it plays).
  final _refusals = <String, PlaybackRefusal>{};

  TwitchStreamService(Dio dio, {PlaybackTokenCache? tokenCache})
    : _http = dio,
      _tokenCache = tokenCache,
      super(dio, '');

  /// Called (not awaited) when Twitch refuses the authenticated
  /// `PlaybackAccessToken` request with a 401.
  ///
  /// Should mint a fresh web token for the next request, returning it, or
  /// null when none can be obtained. This exists because the common way the 2K credential
  /// dies is not the cookie disappearing but the cookie going stale: it is
  /// still in the jar, still gets sent, and Twitch simply refuses it. Without
  /// this hook the request below would fall back to anonymous and playback
  /// would quietly drop to 1080p forever, with a token that looks set in
  /// settings.
  Future<String?> Function()? onWebTokenRejected;

  /// Returns the available quality variants for [userLogin]'s live stream.
  ///
  /// Pass the viewer's twitch.tv web token as [authToken] to receive the
  /// enhanced-broadcast (1440p HEVC / AV1) renditions — Twitch only includes
  /// them for authenticated viewers. The request falls back to an anonymous
  /// one if the token is rejected.
  ///
  /// Throws if the channel is offline or Twitch rejects the request; callers
  /// should treat a throw as "fall back to the WebView engine".
  ///
  /// [cancelToken] cancels the playlist request (a preview swiped past).
  /// The token request is not cancelled: the token cache shares it with
  /// whoever asks for the same channel meanwhile (its player).
  Future<List<HlsVariant>> getStreamVariants({
    required String userLogin,
    String? authToken,
    CancelToken? cancelToken,
  }) async {
    final token = await _getAccessToken(userLogin, authToken: authToken);

    // Dio returns a non-JSON `.m3u8` body as a plain string under the default
    // transformer (verified against live usher), so `get<String>` is safe here.
    final playlist = await get<String>(
      '$_usherBase/$userLogin.m3u8',
      queryParameters: usherQueryParameters(
        signature: token.signature,
        token: token.value,
        p: _randomP(),
      ),
      cancelToken: cancelToken,
    );

    return HlsVariant.parseMasterPlaylist(playlist);
  }

  /// Returns the full usher master-playlist URL (token + low-latency params) to
  /// hand directly to a player that fetches the playlist itself (the IVS
  /// player). Throws if the channel is offline / Twitch rejects the request.
  ///
  /// A cached token is reused while valid unless [forceFreshToken] is set
  /// (e.g. after the player reported the token as rejected). [authToken]
  /// works as in [getStreamVariants].
  Future<String> getUsherUrl({
    required String userLogin,
    String? authToken,
    bool forceFreshToken = false,
  }) async {
    final token = await _getAccessToken(
      userLogin,
      authToken: authToken,
      forceFresh: forceFreshToken,
    );
    final params = usherQueryParameters(
      signature: token.signature,
      token: token.value,
      p: _randomP(),
    );
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$_usherBase/$userLogin.m3u8?$query';
  }

  /// Query parameters for the usher master playlist, shared by
  /// [getStreamVariants] and [getUsherUrl].
  ///
  /// Matches what the official app sends: no legacy `low_latency` or
  /// `player=twitchweb` flags (`fast_bread` is what enables the low-latency
  /// segments).
  @visibleForTesting
  static Map<String, String> usherQueryParameters({
    required String signature,
    required String token,
    required int p,
  }) => {
    'allow_source': 'true',
    // Lists the "audio_only" rendition, as the official app does; adaptive
    // quality never picks it.
    'allow_audio_only': 'true',
    'fast_bread': 'true', // enables Twitch low-latency segments
    // Advertise the higher-quality codecs so Twitch includes the 1440p/4K
    // "enhanced broadcasting" renditions (which are HEVC/AV1, not H.264).
    // For plain H.264 streams this changes nothing (no other encodes exist).
    'supported_codecs': 'av1,h265,h264',
    // Lets Twitch move the viewer to another transcode without killing
    // playback, and names the renditions with their framerate (1440p60).
    'reassignments_supported': 'true',
    'playlist_include_framerate': 'true',
    'p': '$p',
    'sig': signature,
    'token': token,
    'type': 'any',
  };

  /// Why Twitch said [userLogin]'s stream would be refused, from its last
  /// token; null when it plays (or no token was fetched yet).
  PlaybackRefusal? refusalFor(String userLogin) => _refusals[userLogin];

  /// The reason usher gives when it refuses a playlist URL (from
  /// [getUsherUrl]), such as a region or proxy block; null when the
  /// playlist plays or the answer is unreadable.
  Future<String?> usherRefusal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != Uri.parse(_usherBase).host) return null;
    try {
      final response = await _http.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 400) return null;
      final body = jsonDecode(response.data ?? '');
      if (body is! List || body.isEmpty) return null;
      final first = body.first;
      if (first is! Map) return null;
      final error = first['error'];
      if (error is! String) return null;
      final reason = error.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (reason.isEmpty) return null;
      return reason.length > 200 ? '${reason.substring(0, 200)}…' : reason;
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Releases the underlying HTTP client. Only call when this service owns the
  /// Dio (i.e. it was not injected from the shared app client).
  void close() => _http.close(force: true);

  /// Asks for [userLogin]'s playback token ahead of the player (a press on
  /// a stream card), so opening the channel finds it cached or on its way.
  /// Never throws: the player asks again if this failed.
  Future<void> preload(String userLogin, {String? authToken}) async {
    try {
      await _getAccessToken(userLogin, authToken: authToken);
    } catch (e) {
      debugPrint('Playback token preload failed: $e');
    }
  }

  /// The authenticated attempt comes first when [authToken] is given: Twitch
  /// only advertises the enhanced-broadcast renditions to a logged-in viewer.
  /// Any failure falls back at once to the anonymous request that has always
  /// worked, so a bad token never delays playback.
  Future<PlaybackAccessToken> _getAccessToken(
    String login, {
    String? authToken,
    bool forceFresh = false,
  }) async {
    if (authToken != null && authToken.isNotEmpty) {
      try {
        return await _cachedAccessToken(
          login,
          authToken: authToken,
          forceFresh: forceFresh,
        );
      } on UnauthorizedException catch (e) {
        debugPrint('Authenticated playback token refused: $e');
        // A stale cookie: renew it in the background, for the next request,
        // rather than costing the viewer 2K for the rest of the session. Not
        // awaited, so this stream starts anonymously right away.
        final renew = onWebTokenRejected;
        if (renew != null) {
          unawaited(
            renew().catchError((Object e) {
              debugPrint('Web token renewal failed: $e');
              return null;
            }),
          );
        }
      } catch (e) {
        debugPrint('Authenticated playback token failed: $e');
      }
    }
    return _cachedAccessToken(login, forceFresh: forceFresh);
  }

  /// Authenticated and anonymous tokens are cached apart (they do not unlock
  /// the same renditions), and each viewer's token apart from another's, so
  /// one account's token is never replayed for the next.
  static String _cacheKey(String login, String? authToken) =>
      authToken == null ? login : '$login#${authToken.hashCode}';

  Future<PlaybackAccessToken> _cachedAccessToken(
    String login, {
    String? authToken,
    bool forceFresh = false,
  }) async {
    final cache = _tokenCache;
    final key = _cacheKey(login, authToken);
    if (cache != null) {
      if (forceFresh) {
        cache.invalidate(key);
      } else if (cache.get(key) case final cached?) {
        _remember(login, cached);
        return cached;
      } else if (cache.pending(key) case final pending?) {
        // The same answer a request of our own would get, sooner: a failure
        // goes to the caller's retry policy like its own would.
        final token = await pending;
        _remember(login, token);
        return token;
      }
    }
    final token = _fetchAccessToken(login, authToken: authToken);
    cache?.track(key, token);
    return token;
  }

  Future<PlaybackAccessToken> _fetchAccessToken(
    String login, {
    String? authToken,
  }) async {
    final cache = _tokenCache;

    var data = await _postAccessToken(login, accessTokenQuery, authToken);
    var token = (data['data'] as JsonMap?)?['streamPlaybackAccessToken'];
    if (token is! JsonMap && data['errors'] is List) {
      // Maybe the refusal field was renamed or removed: ask without it.
      debugPrint('Playback token query refused: ${data['errors']}');
      data = await _postAccessToken(login, plainAccessTokenQuery, authToken);
      token = (data['data'] as JsonMap?)?['streamPlaybackAccessToken'];
    }
    if (token is! JsonMap || token['value'] == null) {
      throw const ApiException('No playback access token (channel offline?)');
    }
    final accessToken = PlaybackAccessToken.fromValue(
      value: token['value'] as String,
      signature: token['signature'] as String,
      // Only explains a refusal: an odd shape must not cost the token.
      refusal: switch (token['authorization']) {
        {'forbiddenReasonCode': final String code} => PlaybackRefusal.fromCode(
          code,
        ),
        _ => null,
      },
    );
    // A refused token is not kept: once the stream opens to the viewer
    // (sub-only off, VPN off, unbanned), the next try must ask again.
    if (accessToken.refusal == null) {
      cache?.put(_cacheKey(login, authToken), accessToken);
    }
    _remember(login, accessToken);
    return accessToken;
  }

  Future<JsonMap> _postAccessToken(
    String login,
    String query,
    String? authToken,
  ) => post<JsonMap>(
    _gqlUrl,
    headers: {
      'Client-ID': _gqlClientId,
      if (authToken != null) 'Authorization': 'OAuth $authToken',
    },
    data: accessTokenRequest(login, query),
  );

  /// The GQL request body for [login]'s live token.
  @visibleForTesting
  static Map<String, Object?> accessTokenRequest(String login, String query) =>
      {
        'operationName': 'PlaybackAccessToken_Template',
        'query': query,
        'variables': {
          'isLive': true,
          'login': login,
          'isVod': false,
          'vodID': '',
          'playerType': 'embed',
        },
      };

  void _remember(String login, PlaybackAccessToken token) {
    final refusal = token.refusal;
    if (refusal == null) {
      _refusals.remove(login);
    } else {
      _refusals[login] = refusal;
    }
  }

  /// Twitch's usher endpoint expects a random integer in `p`.
  int _randomP() => DateTime.now().microsecondsSinceEpoch % 10000000;
}
