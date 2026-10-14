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

  /// The full GQL document for the access token. Using the raw query (instead
  /// of a persisted-query hash) avoids `PersistedQueryNotFound` if Twitch
  /// rotates hashes.
  static const _accessTokenQuery =
      'query PlaybackAccessToken_Template(\$login: String!, \$isLive: Boolean!, '
      '\$vodID: ID!, \$isVod: Boolean!, \$playerType: String!) {'
      '  streamPlaybackAccessToken(channelName: \$login, params: {platform: "web", '
      'playerBackend: "mediaplayer", playerType: \$playerType}) @include(if: \$isLive) {'
      '    value signature authorization { forbiddenReasonCode } __typename'
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

  /// Returns the available quality variants for [userLogin]'s live stream.
  ///
  /// Throws if the channel is offline or Twitch rejects the request; callers
  /// should treat a throw as "fall back to the WebView engine".
  Future<List<HlsVariant>> getStreamVariants({
    required String userLogin,
  }) async {
    final token = await _getAccessToken(userLogin);

    // Dio returns a non-JSON `.m3u8` body as a plain string under the default
    // transformer (verified against live usher), so `get<String>` is safe here.
    final playlist = await get<String>(
      '$_usherBase/$userLogin.m3u8',
      queryParameters: usherQueryParameters(
        signature: token.signature,
        token: token.value,
        p: _randomP(),
      ),
    );

    return HlsVariant.parseMasterPlaylist(playlist);
  }

  /// Returns the full usher master-playlist URL (token + low-latency params) to
  /// hand directly to a player that fetches the playlist itself (the IVS
  /// player). Throws if the channel is offline / Twitch rejects the request.
  ///
  /// A cached token is reused while valid unless [forceFreshToken] is set
  /// (e.g. after the player reported the token as rejected).
  Future<String> getUsherUrl({
    required String userLogin,
    bool forceFreshToken = false,
  }) async {
    final token = await _getAccessToken(userLogin, forceFresh: forceFreshToken);
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

  Future<PlaybackAccessToken> _getAccessToken(
    String login, {
    bool forceFresh = false,
  }) async {
    final cache = _tokenCache;
    if (cache != null) {
      if (forceFresh) {
        cache.invalidate(login);
      } else if (cache.get(login) case final cached?) {
        _remember(login, cached);
        return cached;
      }
    }

    final data = await post<JsonMap>(
      _gqlUrl,
      headers: {'Client-ID': _gqlClientId},
      data: {
        'operationName': 'PlaybackAccessToken_Template',
        'query': _accessTokenQuery,
        'variables': {
          'isLive': true,
          'login': login,
          'isVod': false,
          'vodID': '',
          'playerType': 'embed',
        },
      },
    );

    final token = (data['data'] as JsonMap?)?['streamPlaybackAccessToken'];
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
    cache?.put(login, accessToken);
    _remember(login, accessToken);
    return accessToken;
  }

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
