import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
/// The one exception is the playback token: like the official app, it is
/// asked as the viewer when [webToken] gives their twitch.tv web token, so
/// VODs restricted to subscribers play for the subscribers.
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

  // Many channels in one request (verified anonymously, 2026-10-14).
  static const _followedVideosQuery =
      'query FollowedVideos(\$ids: [ID!], \$first: Int) { users(ids: \$ids) '
      '{ id login displayName videos(first: \$first, sort: TIME) { edges { '
      'node { $_videoFields } } } } }';

  /// Channels per [getFollowedVideos] request.
  static const _followedBatch = 50;

  static const _videoQuery =
      'query Video(\$id: ID!) { video(id: \$id) { $_videoFields } }';

  static const _commentsQuery =
      'query VideoComments(\$id: ID!, \$offset: Int) { video(id: \$id) { '
      'comments(contentOffsetSeconds: \$offset) { edges { node { id '
      'contentOffsetSeconds commenter { id login displayName } message { '
      'fragments { text emote { emoteID } } userBadges { setID version } '
      'userColor } } } pageInfo { hasNextPage } } } }';

  // The video's own labels, as the official app asks for a VOD's warning
  // (not the channel's current ones; verified anonymously, 2026-10-17).
  static const _contentLabelsQuery =
      'query VideoContentLabels(\$id: ID!) { video(id: \$id) { '
      'contentClassificationLabels { id } } }';

  static const _mutedSegmentsQuery =
      'query VideoMutedSegments(\$id: ID!) { video(id: \$id) { muteInfo { '
      'mutedSegmentConnection { nodes { offset duration } } } } }';

  static const _tokenQuery =
      'query VodToken(\$id: ID!) { videoPlaybackAccessToken(id: \$id, '
      'params: {platform: "web", playerBackend: "mediaplayer", '
      'playerType: "site"}) { value signature } }';

  final Dio _http;
  final PlaybackTokenCache _tokens;

  /// The viewer's twitch.tv web token, read for each playback token (null or
  /// empty: anonymous). It is sent to gql.twitch.tv only, with the playback
  /// token request only.
  String? Function()? webToken;

  /// Called (not awaited) when Twitch refuses the web token with a 401, to
  /// mint a fresh one for the next request; this request goes on
  /// anonymously.
  Future<String?> Function()? onWebTokenRejected;

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

  /// The newest videos ([perChannel] each) of the channels [ids], newest
  /// first across channels, for the Following page.
  Future<List<Vod>> getFollowedVideos(
    List<String> ids, {
    int perChannel = 5,
  }) async {
    final numeric = RegExp(r'^[0-9]{1,20}$');
    for (final id in ids) {
      if (!numeric.hasMatch(id)) {
        throw ArgumentError.value(id, 'ids', 'Not a channel id');
      }
    }
    final videos = <Vod>[];
    for (var start = 0; start < ids.length; start += _followedBatch) {
      final batch = ids.sublist(
        start,
        (start + _followedBatch).clamp(0, ids.length),
      );
      final data = await _gql('FollowedVideos', _followedVideosQuery, {
        'ids': batch,
        'first': perChannel,
      });
      final users = data['users'];
      // Twitch changed the query: an error, not "no videos".
      if (users is! List) throw const VodApiException('Unreadable videos');
      for (final user in users) {
        if (user is! Map) continue;
        final owner = {
          'id': user['id'],
          'login': user['login'],
          'displayName': user['displayName'],
        };
        final list = user['videos'] is Map ? user['videos'] as Map : const {};
        final edges = list['edges'] is List ? list['edges'] as List : const [];
        for (final edge in edges) {
          if (edge is! Map || edge['node'] is! Map) continue;
          try {
            videos.add(
              Vod.fromGql(JsonMap.from(edge['node'] as Map), owner: owner),
            );
          } on FormatException {
            // One unreadable video must not hide the others.
          }
        }
      }
    }
    videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return videos;
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
    final videos = game['videos'];
    if (videos is! Map) throw const VodApiException('Unreadable videos');
    final edges = videos['edges'] is List
        ? (videos['edges'] as List).take(100).toList()
        : const [];
    final items = <Vod>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Vod.fromGql(JsonMap.from(edge['node'] as Map)));
      } on FormatException {
        // One unreadable video must not hide the others.
      }
    }
    // All of them unreadable: Twitch changed something, not an empty list.
    if (items.isEmpty && edges.isNotEmpty) {
      throw const VodApiException('Unreadable videos');
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

  /// The content classification label ids of the video itself (empty when
  /// it has none). Throws when the video or the answer cannot be read.
  Future<List<String>> getContentLabels(String vodId) async {
    final data = await _gql('VideoContentLabels', _contentLabelsQuery, {
      'id': normalizeVodId(vodId),
    });
    final video = data['video'];
    if (video is! Map) throw const NotFoundException('Video not found');
    final labels = video['contentClassificationLabels'];
    if (labels == null) return const [];
    if (labels is! List) throw const VodApiException('Unreadable labels');
    return [
      for (final label in labels)
        if (label is Map && label['id'] is String) label['id'] as String,
    ];
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

  /// The viewer's token first when there is one; when that request fails
  /// for any reason but the network (401, 403, a GQL error, Twitch
  /// failing), the anonymous token that always worked. A network failure
  /// would hit the anonymous request too: it goes to the caller's retry
  /// policy instead.
  Future<PlaybackAccessToken> _getToken(
    String id, {
    required bool forceFresh,
  }) async {
    final authToken = webToken?.call();
    if (authToken != null &&
        authToken.isNotEmpty &&
        _tokenId(authToken) != _refusedWebToken) {
      try {
        return await _cachedToken(
          id,
          authToken: authToken,
          forceFresh: forceFresh,
        );
      } on UnauthorizedException {
        debugPrint('Authenticated VOD token refused (401)');
        // Not sent again (each start would pay a refusal) until it changes.
        _refusedWebToken = _tokenId(authToken);
        final renew = onWebTokenRejected;
        if (renew != null) {
          unawaited(
            renew().then<void>(
              (_) {},
              onError: (Object e) =>
                  debugPrint('Web token renewal failed: ${e.runtimeType}'),
            ),
          );
        }
      } on NetworkException {
        rethrow;
      } on TimeoutException {
        rethrow;
      } on ApiException catch (e) {
        debugPrint('Authenticated VOD token failed: ${e.runtimeType}');
      }
    }
    return _cachedToken(id, forceFresh: forceFresh);
  }

  /// The identity of the last web token Twitch refused with a 401.
  String? _refusedWebToken;

  /// Names a web token without holding it (cache keys, the refused one).
  static String _tokenId(String authToken) =>
      sha256.convert(utf8.encode(authToken)).toString().substring(0, 16);

  /// One entry per VOD and viewer: the anonymous token, or the token of the
  /// web token's account (named by a hash, so the cache never holds it), so
  /// a token is never handed to another account after a logout or login.
  static String _cacheKey(String id, String? authToken) =>
      authToken == null ? id : '$id#${_tokenId(authToken)}';

  Future<PlaybackAccessToken> _cachedToken(
    String id, {
    String? authToken,
    required bool forceFresh,
  }) async {
    final key = _cacheKey(id, authToken);
    if (forceFresh) {
      _tokens.invalidate(key);
    } else if (_tokens.get(key) case final cached?) {
      return cached;
    }
    final data = await _gql(
      'VodToken',
      _tokenQuery,
      {'id': id},
      headers: {if (authToken != null) 'Authorization': 'OAuth $authToken'},
    );
    final token = data['videoPlaybackAccessToken'];
    if (token is! Map || token['value'] is! String) {
      throw const ApiException('No playback access token for this video');
    }
    final value = token['value'] as String;
    final accessToken = PlaybackAccessToken.fromValue(
      value: value,
      signature: token['signature'] as String? ?? '',
    );
    // A refused token is not kept: once the video opens to the viewer
    // (subscribed, unblocked), the next try must ask again.
    if (!VodAccessInfo.fromTokenValue(value).forbidden) {
      _tokens.put(key, accessToken);
    }
    return accessToken;
  }

  /// Forgets [vodId]'s cached tokens (anonymous and the current viewer's),
  /// after usher refused one: a retry then asks Twitch again.
  void invalidateToken(String vodId) {
    final id = tryNormalizeVodId(vodId);
    if (id == null) return;
    _tokens.invalidate(_cacheKey(id, null));
    final authToken = webToken?.call();
    if (authToken != null && authToken.isNotEmpty) {
      _tokens.invalidate(_cacheKey(id, authToken));
    }
  }

  Future<JsonMap> _gql(
    String operationName,
    String query,
    JsonMap variables, {
    Map<String, String> headers = const {},
  }) async {
    final body = await post<JsonMap>(
      _gqlUrl,
      headers: {'Client-ID': _gqlClientId, ...headers},
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
