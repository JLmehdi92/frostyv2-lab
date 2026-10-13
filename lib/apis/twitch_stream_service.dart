import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/hls_variant.dart';

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
      '    value signature __typename'
      '  }'
      '  videoPlaybackAccessToken(id: \$vodID, params: {platform: "web", '
      'playerBackend: "mediaplayer", playerType: \$playerType}) @include(if: \$isVod) {'
      '    value signature __typename'
      '  }'
      '}';

  final Dio _http;

  TwitchStreamService(Dio dio) : _http = dio, super(dio, '');

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
  Future<String> getUsherUrl({required String userLogin}) async {
    final token = await _getAccessToken(userLogin);
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

  /// Releases the underlying HTTP client. Only call when this service owns the
  /// Dio (i.e. it was not injected from the shared app client).
  void close() => _http.close(force: true);

  Future<_AccessToken> _getAccessToken(String login) async {
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
    return _AccessToken(
      value: token['value'] as String,
      signature: token['signature'] as String,
    );
  }

  /// Twitch's usher endpoint expects a random integer in `p`.
  int _randomP() => DateTime.now().microsecondsSinceEpoch % 10000000;
}

class _AccessToken {
  final String value;
  final String signature;
  const _AccessToken({required this.value, required this.signature});
}
