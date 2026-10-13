import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/playback_access_token.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/models/vod_access.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/services/playback_token_cache.dart';

/// A GQL error answered for a VOD request.
class VodApiException extends ApiException {
  const VodApiException(super.message, {this.isIntegrity = false});

  /// Twitch asked for a client-integrity token (feature unavailable to us).
  final bool isIntegrity;

  @override
  String toString() => 'VodApiException: $message';
}

/// The VOD playback token says the viewer may not watch it.
class VodForbiddenException extends ApiException {
  const VodForbiddenException(this.reason)
    : super('Video playback is forbidden');

  final String? reason;
}

/// Why usher refused a VOD playlist.
enum VodPlaybackProblem {
  subscriberOnly,
  geoBlocked,
  tokenRejected,
  notFound,
  unknown,
}

/// Past broadcasts, highlights and uploads from Twitch GQL, anonymously (the
/// public web Client-ID and full query documents, no user token): channel
/// lists, a single video, chat replay by offset and the usher VOD playlist.
///
/// Comments and channel lists are fetched without cursors: cursor paging is
/// integrity-gated for anonymous clients (verified 2026-10-13).
class TwitchVodService extends BaseApiClient {
  TwitchVodService(Dio dio, {PlaybackTokenCache? tokenCache})
    : _http = dio,
      _tokens = tokenCache ?? PlaybackTokenCache(),
      super(dio, '');

  /// Public web client-id used by twitch.tv itself (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static const _usherVodBase = 'https://usher.ttvnw.net/vod';

  static const _videoFields =
      'id title lengthSeconds createdAt viewCount status broadcastType '
      'previewThumbnailURL(width: 640, height: 360) game { id name } '
      'owner { id login displayName } self { isRestricted }';

  static const _channelVideosQuery =
      'query ChannelVideos(\$login: String!, \$type: BroadcastType, '
      '\$first: Int) { user(login: \$login) { id login displayName '
      'videos(first: \$first, type: \$type, sort: TIME) { edges { node { '
      '$_videoFields } } pageInfo { hasNextPage } } } }';

  // `owner` comes with each video (verified anonymously, 2026-10-13).
  static const _categoryVideosQuery =
      'query CategoryVideos(\$id: ID!, \$first: Int, \$sort: VideoSort) { '
      'game(id: \$id) { id videos(first: \$first, sort: \$sort) { edges { '
      'node { $_videoFields } } pageInfo { hasNextPage } } } }';

  static const _videoQuery =
      'query Video(\$id: ID!) { video(id: \$id) { $_videoFields } }';

  static const _commentsQuery =
      'query VideoComments(\$id: ID!, \$offset: Int) { video(id: \$id) { '
      'comments(contentOffsetSeconds: \$offset) { edges { node { id '
      'contentOffsetSeconds commenter { id login displayName } message { '
      'fragments { text emote { emoteID } } userBadges { setID version } '
      'userColor } } } pageInfo { hasNextPage } } } }';

  static const _mutedSegmentsQuery =
      'query VideoMutedSegments(\$id: ID!) { video(id: \$id) { muteInfo { '
      'mutedSegmentConnection { nodes { offset duration } } } } }';

  static const _tokenQuery =
      'query VodToken(\$id: ID!) { videoPlaybackAccessToken(id: \$id, '
      'params: {platform: "web", playerBackend: "mediaplayer", '
      'playerType: "site"}) { value signature } }';

  final Dio _http;
  final PlaybackTokenCache _tokens;

  /// The channel's newest videos of [type] (up to 100, newest first).
  Future<VodPage> getChannelVideos({
    required String login,
    required VodType type,
  }) async {
    final data = await _gql('ChannelVideos', _channelVideosQuery, {
      'login': login,
      'type': type.gqlName,
      'first': 100,
    });
    final user = data['user'];
    if (user is! Map) throw const NotFoundException('Channel not found');
    final owner = {
      'id': user['id'],
      'login': user['login'],
      'displayName': user['displayName'],
    };
    final videos = user['videos'] is Map ? user['videos'] as Map : const {};
    final edges = videos['edges'] is List ? videos['edges'] as List : const [];
    final items = <Vod>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Vod.fromGql(JsonMap.from(edge['node'] as Map), owner: owner));
      } on FormatException {
        // One unreadable video must not hide the others.
      }
    }
    final pageInfo = videos['pageInfo'];
    return VodPage(
      items: items,
      hasMore: pageInfo is Map && pageInfo['hasNextPage'] == true,
    );
  }

  /// A category's 100 most viewed videos.
  Future<VodPage> getCategoryVideos(String gameId) async {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(gameId)) {
      throw ArgumentError.value(gameId, 'gameId', 'Not a category id');
    }
    final data = await _gql('CategoryVideos', _categoryVideosQuery, {
      'id': gameId,
      'first': 100,
      'sort': 'VIEWS',
    });
    final game = data['game'];
    if (game is! Map) throw const NotFoundException('Category not found');
    final videos = game['videos'] is Map ? game['videos'] as Map : const {};
    final edges = videos['edges'] is List ? videos['edges'] as List : const [];
    final items = <Vod>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Vod.fromGql(JsonMap.from(edge['node'] as Map)));
      } on FormatException {
        // One unreadable video must not hide the others.
      }
    }
    final pageInfo = videos['pageInfo'];
    return VodPage(
      items: items,
      hasMore: pageInfo is Map && pageInfo['hasNextPage'] == true,
    );
  }

  /// The video, or null when it does not exist (deleted or wrong id).
  Future<Vod?> getVideo(String vodId) async {
    final data = await _gql('Video', _videoQuery, {
      'id': normalizeVodId(vodId),
    });
    final video = data['video'];
    if (video is! Map) return null;
    try {
      return Vod.fromGql(JsonMap.from(video));
    } on FormatException {
      throw const VodApiException('Unreadable video');
    }
  }

  /// Chat messages recorded around [offsetSeconds] (Twitch returns a page
  /// starting just before it), oldest first.
  Future<VodCommentPage> getComments({
    required String vodId,
    required int offsetSeconds,
  }) async {
    final data = await _gql('VideoComments', _commentsQuery, {
      'id': normalizeVodId(vodId),
      'offset': offsetSeconds,
    });
    final video = data['video'];
    final comments = video is Map && video['comments'] is Map
        ? video['comments'] as Map
        : null;
    if (comments == null) throw const VodApiException('No comments');
    final edges = comments['edges'] is List
        ? comments['edges'] as List
        : const [];
    final pageInfo = comments['pageInfo'];
    return VodCommentPage(
      comments: [
        for (final edge in edges)
          if (edge is Map && edge['node'] is Map)
            VodComment.fromGql(JsonMap.from(edge['node'] as Map)),
      ],
      hasNextPage: pageInfo is Map && pageInfo['hasNextPage'] == true,
    );
  }

  /// Copyright-muted parts of the VOD. Optional data: never throws.
  Future<List<MutedSegment>> getMutedSegments(String vodId) async {
    try {
      final data = await _gql('VideoMutedSegments', _mutedSegmentsQuery, {
        'id': normalizeVodId(vodId),
      });
      final video = data['video'];
      final info = video is Map && video['muteInfo'] is Map
          ? video['muteInfo'] as Map
          : null;
      final connection = info?['mutedSegmentConnection'];
      final nodes = connection is Map ? connection['nodes'] as List? : null;
      return [
        for (final n in nodes ?? const [])
          if (n is Map && n['offset'] is num && n['duration'] is num)
            MutedSegment(
              offset: (n['offset'] as num).toInt(),
              duration: (n['duration'] as num).toInt(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Usher master playlist URL for the VOD (token + signature). Throws
  /// [VodForbiddenException] when the token denies playback.
  Future<String> getVodUsherUrl({
    required String vodId,
    bool forceFreshToken = false,
  }) async {
    final id = normalizeVodId(vodId);
    final token = await _getToken(id, forceFresh: forceFreshToken);
    final access = VodAccessInfo.fromTokenValue(token.value);
    if (access.forbidden) throw VodForbiddenException(access.reason);
    final params = vodUsherQueryParameters(
      signature: token.signature,
      token: token.value,
      p: DateTime.now().microsecondsSinceEpoch % 10000000,
    );
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$_usherVodBase/$id.m3u8?$query';
  }

  /// Asks usher why a playlist is refused. Never throws and never logs the
  /// URL (it carries the playback token).
  ///
  /// Usher answers a bad token and a missing VOD alike (403, empty body), so
  /// both come back as [VodPlaybackProblem.unknown].
  Future<VodPlaybackProblem?> diagnoseVodPlaylist(String url) async {
    // Only ever talk to usher, whatever URL is passed in.
    if (Uri.tryParse(url)?.host != 'usher.ttvnw.net') {
      return VodPlaybackProblem.unknown;
    }
    try {
      final response = await _http.get<Object?>(
        url,
        options: Options(
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return null;
      if (status == 404) return VodPlaybackProblem.notFound;
      final body = response.data;
      final first = body is List && body.isNotEmpty ? body.first : body;
      final code = first is Map ? '${first['error_code']}' : '';
      if (code == 'vod_manifest_restricted') {
        return VodPlaybackProblem.subscriberOnly;
      }
      if (code == 'content_geoblocked') return VodPlaybackProblem.geoBlocked;
      if (code.startsWith('nauth')) return VodPlaybackProblem.tokenRejected;
      return VodPlaybackProblem.unknown;
    } catch (_) {
      return VodPlaybackProblem.unknown;
    }
  }

  /// Usher VOD parameters (no live-only `fast_bread`/`type`). Keeps the same
  /// `supported_codecs` as live so 1440p/4K HEVC/AV1 renditions are offered.
  @visibleForTesting
  static Map<String, String> vodUsherQueryParameters({
    required String signature,
    required String token,
    required int p,
  }) => {
    'allow_source': 'true',
    'allow_audio_only': 'true',
    'supported_codecs': 'av1,h265,h264',
    'playlist_include_framerate': 'true',
    'p': '$p',
    'sig': signature,
    'token': token,
  };

  /// Accepts `123` or `v123`. The id ends up in a URL path, so anything that
  /// is not 1–20 ASCII digits throws an [ArgumentError] (a programming error:
  /// untrusted input such as links must go through [tryNormalizeVodId]).
  @visibleForTesting
  static String normalizeVodId(String raw) {
    final id = tryNormalizeVodId(raw);
    if (id == null) throw ArgumentError.value(raw, 'vodId', 'Not a VOD id');
    return id;
  }

  /// [normalizeVodId] for untrusted input: null when it is not a VOD id.
  static String? tryNormalizeVodId(String raw) {
    final id = raw.startsWith('v') ? raw.substring(1) : raw;
    return RegExp(r'^[0-9]{1,20}$').hasMatch(id) ? id : null;
  }

  Future<PlaybackAccessToken> _getToken(
    String id, {
    required bool forceFresh,
  }) async {
    if (forceFresh) {
      _tokens.invalidate(id);
    } else if (_tokens.get(id) case final cached?) {
      return cached;
    }
    final data = await _gql('VodToken', _tokenQuery, {'id': id});
    final token = data['videoPlaybackAccessToken'];
    if (token is! Map || token['value'] is! String) {
      throw const ApiException('No playback access token for this video');
    }
    final accessToken = PlaybackAccessToken.fromValue(
      value: token['value'] as String,
      signature: token['signature'] as String? ?? '',
    );
    _tokens.put(id, accessToken);
    return accessToken;
  }

  Future<JsonMap> _gql(
    String operationName,
    String query,
    JsonMap variables,
  ) async {
    final body = await post<JsonMap>(
      _gqlUrl,
      headers: {'Client-ID': _gqlClientId},
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
    );
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join('; ');
      throw VodApiException(
        messages,
        isIntegrity: messages.toLowerCase().contains('integrity'),
      );
    }
    final data = body['data'];
    if (data is! Map) throw const VodApiException('Empty GQL response');
    return JsonMap.from(data);
  }
}
