import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/models/video_collection.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/models/vod_access.dart';
import 'package:onset/models/vod_chapter.dart';
import 'package:onset/models/vod_comment.dart';
import 'package:onset/services/playback_token_cache.dart';

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
  proxyDetected,
  wifiRequired,
  unsupportedDevice,
  unknown,
}

/// Past broadcasts, highlights and uploads from Twitch GQL, anonymously (the
/// public web Client-ID and full query documents, no user token): channel
/// lists, a single video, chat replay by offset and the usher VOD playlist.
///
/// The exceptions are asked as the viewer when [webToken] gives their
/// twitch.tv web token, like the official app: the playback token, so VODs
/// restricted to subscribers play for the subscribers, and the viewer's own
/// watch positions ([getViewingHistory], [updateViewedVideo]).
///
/// Comments and channel lists are fetched without cursors: cursor paging is
/// integrity-gated for anonymous clients (verified 2026-10-13).
class TwitchVodService extends BaseApiClient {
  TwitchVodService(Dio dio, {PlaybackTokenCache? tokenCache})
    : _http = dio,
      _tokens = tokenCache ?? PlaybackTokenCache(),
      super(dio, '');

  static const _usherVodBase = 'https://usher.ttvnw.net/vod';

  static const _videoFields =
      'id title lengthSeconds createdAt viewCount status broadcastType '
      'previewThumbnailURL(width: 640, height: 360) game { id name } '
      'owner { id login displayName } broadcast { id } '
      'self { isRestricted }';

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

  // The Videos search tab: `searchFor` on the VOD index, 25 per page with Twitch's cursor (paging answers anonymously, verified
  // 2026-10-20).
  static const _searchVideosQuery =
      'query SearchVideos(\$query: String!, \$target: SearchForTarget) { '
      'searchFor(userQuery: \$query, platform: "android", target: \$target) '
      '{ videos { cursor items { $_videoFields } pageInfo { hasNextPage } } '
      '} }';

  /// Videos per [searchVideos] page, like the official app.
  static const searchPageSize = 25;

  static const _commentsQuery =
      'query VideoComments(\$id: ID!, \$offset: Int) { video(id: \$id) { '
      'comments(contentOffsetSeconds: \$offset) { edges { node { id '
      'contentOffsetSeconds commenter { id login displayName } message { '
      'fragments { text emote { emoteID } } userBadges { setID version } '
      'userColor } } } pageInfo { hasNextPage } } } }';

  // The video's own labels, for a VOD's warning (not the channel's current
  // ones; verified anonymously, 2026-10-17).
  static const _contentLabelsQuery =
      'query VideoContentLabels(\$id: ID!) { video(id: \$id) { '
      'contentClassificationLabels { id } } }';

  static const _streamPaidPromotionQuery =
      'query BrandedContentStreamMetadataQuery(\$channelId: ID!) { '
      'user(id: \$channelId) { id stream { contentPolicyProperties { '
      'hasBrandedContent } } } }';

  static const _vodPaidPromotionQuery =
      'query BrandedContentVodMetadataQuery(\$vodId: ID!) { '
      'video(id: \$vodId) { contentPolicyProperties { hasBrandedContent } } }';

  static const _collectionFirstVideoQuery =
      'query CollectionFirstVideo(\$id: ID!) { collection(id: \$id) { '
      'items(first: 1) { edges { node { id } } } } }';

  static const _collectionVideosQuery =
      'query CollectionVideos(\$id: ID!) { collection(id: \$id) { '
      'items(first: 100) { edges { node { ... on Video { '
      '$_videoFields } } } } } }';

  static final _collectionId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static const _channelCollectionsQuery =
      'query ChannelCollections(\$channelId: ID!) { user(id: \$channelId) { '
      'collections(first: 50) { edges { node { id title '
      'thumbnailURL(width: 300, height: 300) updatedAt lengthSeconds '
      'items(first: 1) { totalCount edges { node { ... on Video { id } } } } '
      '} } } } }';

  static const _mutedSegmentsQuery =
      'query VideoMutedSegments(\$id: ID!) { video(id: \$id) { muteInfo { '
      'mutedSegmentConnection { nodes { offset duration } } } } }';

  static const _chaptersQuery =
      'query VideoChapters(\$id: ID!) { video(id: \$id) { '
      'moments(momentRequestType: VIDEO_CHAPTER_MARKERS, '
      'types: [GAME_CHANGE]) { '
      'edges { node { positionMilliseconds durationMilliseconds description '
      'details { ... on GameChangeMomentDetails { game { id displayName '
      'boxArtURL(width: 40, height: 53) } } } } } } } }';

  // The viewer's own watch position (their account, any device). Needs the
  // web token: anonymous answers `viewingHistory: null`.
  static const _viewingHistoryQuery =
      'query VideoViewingHistory(\$id: ID!) { video(id: \$id) { self { '
      'viewingHistory { position updatedAt } } } }';

  // The "Continue watching" shelf: the viewer's started videos with their
  // positions. Needs
  // the web token: anonymous answers `currentUser: null`.
  static const _resumeWatchingQuery =
      'query ResumeWatchingVideos(\$limit: Int!) { currentUser { id '
      'viewedVideos(first: \$limit) { edges { history { position updatedAt } '
      'node { $_videoFields } } } } }';

  /// Videos per [getVideos] request.
  static const _videosBatch = 25;

  // Saves a position, for a VOD and for a live broadcast (by stream id). The full document is accepted with the web Client-ID (an anonymous
  // try answers "unauthenticated", 2026-10-20).
  static const _updateViewedVideoMutation =
      'mutation UpdateUserViewedVideo(\$input: UpdateUserViewedVideoInput!) '
      '{ updateUserViewedVideo(input: \$input) { video { id } } }';

  static const _tokenQuery =
      'query VodToken(\$id: ID!) { videoPlaybackAccessToken(id: \$id, '
      'params: {platform: "web", playerBackend: "mediaplayer", '
      'playerType: "site"}) { value signature } }';

  final Dio _http;
  final PlaybackTokenCache _tokens;

  /// The viewer's twitch.tv web token, read for each request that needs it
  /// (null or empty: anonymous). It is sent to gql.twitch.tv only, with the
  /// playback token and watch position requests only.
  String? Function()? webToken;

  /// Called (not awaited) when Twitch refuses the web token with a 401, to
  /// mint a fresh one for the next request; this request goes on
  /// anonymously.
  Future<String?> Function()? onWebTokenRejected;

  /// The logged-in viewer's Twitch user id (null when logged out), sent
  /// with the watch positions written to their account.
  String? Function()? viewerId;

  /// The channel's newest videos of [type] (up to 100, newest first);
  /// every kind of video when [type] is null.
  Future<VodPage> getChannelVideos({
    required String login,
    VodType? type,
  }) async {
    final data = await _gql('ChannelVideos', _channelVideosQuery, {
      'login': login,
      'type': type?.gqlName,
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

  /// One page of the videos matching [query] (Twitch's Videos search tab),
  /// from [cursor] (null: the first page).
  Future<VodSearchPage> searchVideos(String query, {String? cursor}) async {
    final text = query.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Nothing to search');
    }
    final data = await _gql('SearchVideos', _searchVideosQuery, {
      'query': text,
      'target': {
        'index': 'VOD',
        'limit': searchPageSize,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    });
    final search = data['searchFor'];
    final videos = search is Map ? search['videos'] : null;
    // Twitch changed the query: an error, not "no videos".
    if (videos is! Map) throw const VodApiException('Unreadable videos');
    final raw = videos['items'] is List ? videos['items'] as List : const [];
    final items = <Vod>[];
    for (final node in raw) {
      if (node is! Map) continue;
      try {
        items.add(Vod.fromGql(JsonMap.from(node)));
      } on FormatException {
        // One unreadable video must not hide the others.
      }
    }
    if (items.isEmpty && raw.any((node) => node is Map)) {
      throw const VodApiException('Unreadable videos');
    }
    final next = videos['cursor'];
    final pageInfo = videos['pageInfo'];
    final hasMore =
        pageInfo is Map &&
        pageInfo['hasNextPage'] == true &&
        next is String &&
        next.isNotEmpty;
    return VodSearchPage(
      items: items,
      cursor: hasMore ? next : null,
      hasMore: hasMore,
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

  /// The videos [ids] (VOD ids; anything else is skipped), anonymously, in
  /// the order asked. One request for up to 25 (the rest are not asked).
  /// [VideoLookup.missing] names the ids Twitch answered with no video and
  /// no error (deleted); one refused with an error is in neither list, so
  /// it can be asked again. Throws when the answer has no data at all.
  Future<VideoLookup> getVideos(List<String> ids) async {
    final wanted = [
      for (final raw in ids) ?tryNormalizeVodId(raw),
    ].take(_videosBatch).toList();
    if (wanted.isEmpty) return const VideoLookup(videos: [], missing: {});
    final fields = StringBuffer();
    final params = <String>[];
    final variables = <String, Object?>{};
    for (final (i, id) in wanted.indexed) {
      params.add('\$i$i: ID!');
      fields.write('v$i: video(id: \$i$i) { $_videoFields } ');
      variables['i$i'] = id;
    }
    // One deleted or restricted video answers an error for its own alias
    // only: the others still come.
    final refused = <String>{};
    final data = await _gql(
      'VideosById',
      'query VideosById(${params.join(', ')}) { $fields}',
      variables,
      partial: true,
      onErrors: (errors) {
        for (final error in errors) {
          final path = error is Map ? error['path'] : null;
          if (path is List && path.isNotEmpty && path.first is String) {
            refused.add(path.first as String);
          }
        }
      },
    );
    final videos = <Vod>[];
    final missing = <String>{};
    for (var i = 0; i < wanted.length; i++) {
      final alias = 'v$i';
      final node = data[alias];
      if (node is! Map) {
        if (node == null && !refused.contains(alias)) missing.add(wanted[i]);
        continue;
      }
      try {
        videos.add(Vod.fromGql(JsonMap.from(node)));
      } catch (e) {
        // One unreadable video must not hide the others.
        debugPrint('Unreadable video skipped: ${e.runtimeType}');
      }
    }
    return VideoLookup(videos: videos, missing: missing);
  }

  /// The logged-in viewer's "Continue watching" shelf on Twitch: the videos
  /// they started, on any device, newest first as Twitch gives them, with
  /// where they stopped. Null when logged out, refused or anything fails
  /// (the caller falls back on this device's positions). Never throws.
  Future<List<ResumeWatchingEntry>?> getResumeWatching({int limit = 20}) async {
    final authToken = _usableWebToken;
    if (authToken == null) return null;
    final tokenId = _tokenId(authToken);
    if (_historyRefused('shelf', tokenId)) return null;
    try {
      final data = await _gql(
        'ResumeWatchingVideos',
        _resumeWatchingQuery,
        {'limit': limit},
        headers: {'Authorization': 'OAuth $authToken'},
        partial: true,
      );
      _historyFailures.remove('shelf#$tokenId');
      final user = data['currentUser'];
      // The shelf is filed under the logged-in viewer: a web token of
      // another account (pasted, left from a previous login) is not theirs.
      final viewer = viewerId?.call();
      if (user is! Map || viewer == null || '${user['id']}' != viewer) {
        if (user is Map) debugPrint('Continue watching of another account');
        return null;
      }
      final viewed = user['viewedVideos'];
      if (viewed is! Map) return null;
      final edges = viewed['edges'] is List ? viewed['edges'] as List : [];
      final entries = <ResumeWatchingEntry>[];
      for (final edge in edges) {
        if (edge is! Map || edge['node'] is! Map) continue;
        final history = edge['history'];
        final position = history is Map ? history['position'] : null;
        if (position is! int || position < 0) continue;
        try {
          final vod = Vod.fromGql(JsonMap.from(edge['node'] as Map));
          // Its id ends up in a page's URL and in the VOD service's paths.
          if (tryNormalizeVodId(vod.id) == null) continue;
          entries.add(
            ResumeWatchingEntry(
              vod: vod,
              history: ViewingHistory(
                positionSec: position,
                updatedAt: DateTime.tryParse(
                  '${(history as Map)['updatedAt']}',
                ),
              ),
            ),
          );
        } catch (e) {
          // One unreadable video must not hide the others.
          debugPrint('Unreadable video skipped: ${e.runtimeType}');
        }
      }
      return entries;
    } on UnauthorizedException {
      debugPrint('Continue watching refused (401)');
      _onWebTokenUnauthorized(authToken);
    } on VodApiException catch (e) {
      debugPrint('Continue watching refused (integrity: ${e.isIntegrity})');
      _historyFailed('shelf', tokenId, e);
    } catch (e) {
      debugPrint('Continue watching failed: ${e.runtimeType}');
    }
    return null;
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

  Future<bool> streamHasPaidPromotion(String channelId) async {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(channelId)) return false;
    return _paidPromotion(
      'BrandedContentStreamMetadataQuery',
      _streamPaidPromotionQuery,
      {'channelId': channelId},
      (data) => data['user'] is Map ? (data['user'] as Map)['stream'] : null,
    );
  }

  Future<bool> vodHasPaidPromotion(String vodId) => _paidPromotion(
    'BrandedContentVodMetadataQuery',
    _vodPaidPromotionQuery,
    {'vodId': normalizeVodId(vodId)},
    (data) => data['video'],
  );

  Future<bool> _paidPromotion(
    String operation,
    String query,
    JsonMap variables,
    Object? Function(JsonMap data) holder,
  ) async {
    try {
      final data = await _gql(operation, query, variables);
      final owner = holder(data);
      final policy = owner is Map ? owner['contentPolicyProperties'] : null;
      return policy is Map && policy['hasBrandedContent'] == true;
    } catch (e) {
      debugPrint('Paid promotion unavailable: ${e.runtimeType}');
      return false;
    }
  }

  Future<List<Vod>> getCollectionVideos(String collectionId) async {
    if (!_collectionId.hasMatch(collectionId)) return const [];
    try {
      final data = await _gql('CollectionVideos', _collectionVideosQuery, {
        'id': collectionId,
      });
      final collection = data['collection'];
      final items = collection is Map ? collection['items'] : null;
      final edges = items is Map ? items['edges'] : null;
      return [
        if (edges is List)
          for (final edge in edges)
            if (edge is Map && edge['node'] is Map) ?_tryVod(edge['node']),
      ];
    } catch (e) {
      debugPrint('Collection videos unavailable: ${e.runtimeType}');
      return const [];
    }
  }

  Future<List<VideoCollection>?> getChannelCollections(String channelId) async {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(channelId)) return null;
    try {
      final data = await _gql('ChannelCollections', _channelCollectionsQuery, {
        'channelId': channelId,
      });
      return VideoCollection.listFrom(data);
    } catch (e) {
      debugPrint('Channel collections unavailable: ${e.runtimeType}');
      return null;
    }
  }

  static Vod? _tryVod(Object? node) {
    try {
      return Vod.fromGql(JsonMap.from(node! as Map));
    } on FormatException {
      return null;
    }
  }

  Future<String?> firstVideoOfCollection(String collectionId) async {
    if (!_collectionId.hasMatch(collectionId)) return null;
    try {
      final data = await _gql(
        'CollectionFirstVideo',
        _collectionFirstVideoQuery,
        {'id': collectionId},
      );
      final collection = data['collection'];
      final items = collection is Map ? collection['items'] : null;
      final edges = items is Map ? items['edges'] : null;
      if (edges is! List || edges.isEmpty) return null;
      final edge = edges.first;
      final node = edge is Map ? edge['node'] : null;
      final id = node is Map ? node['id'] : null;
      return id is String && RegExp(r'^[0-9]{1,20}$').hasMatch(id) ? id : null;
    } catch (e) {
      debugPrint('Collection unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Future<List<VodChapter>> getChapters(String vodId) async {
    try {
      final data = await _gql('VideoChapters', _chaptersQuery, {
        'id': normalizeVodId(vodId),
      });
      final video = data['video'];
      final moments = video is Map ? video['moments'] : null;
      final edges = moments is Map ? moments['edges'] : null;
      return sortedChapters([
        if (edges is List)
          for (final edge in edges)
            if (edge is Map) ?VodChapter.tryParse(edge['node']),
      ]);
    } catch (e) {
      debugPrint('Chapters unavailable: ${e.runtimeType}');
      return const [];
    }
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
  ///
  /// [anonymous] skips the viewer's web token (when usher keeps refusing
  /// the tokens asked with it).
  Future<String> getVodUsherUrl({
    required String vodId,
    bool forceFreshToken = false,
    bool anonymous = false,
  }) async {
    final id = normalizeVodId(vodId);
    final token = await _getToken(
      id,
      forceFresh: forceFreshToken,
      anonymous: anonymous,
    );
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
      if (code == 'anonymizer_blocked') return VodPlaybackProblem.proxyDetected;
      if (code == 'cellular_geoblocked') return VodPlaybackProblem.wifiRequired;
      if (code == 'no_cdm_specified') {
        return VodPlaybackProblem.unsupportedDevice;
      }
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
    bool anonymous = false,
  }) async {
    final authToken = anonymous ? null : webToken?.call();
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
        _onWebTokenUnauthorized(authToken);
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

  /// GQL errors in a row for each kind of watch-position request and web
  /// token (`read#token`, `write#token`, tokens by identity). At
  /// [_historyMaxFailures] (at once for an integrity check), that request
  /// is not sent again with that token this session: Twitch changed it or
  /// keeps refusing it. A success starts the count again.
  final _historyFailures = <String, int>{};
  static const _historyMaxFailures = 3;

  bool _historyRefused(String kind, String tokenId) =>
      (_historyFailures['$kind#$tokenId'] ?? 0) >= _historyMaxFailures;

  void _historyFailed(String kind, String tokenId, VodApiException e) {
    final key = '$kind#$tokenId';
    _historyFailures[key] = e.isIntegrity
        ? _historyMaxFailures
        : (_historyFailures[key] ?? 0) + 1;
  }

  /// The viewer's web token, when there is one that Twitch did not refuse.
  String? get _usableWebToken {
    final token = webToken?.call();
    if (token == null || token.isEmpty) return null;
    if (_tokenId(token) == _refusedWebToken) return null;
    return token;
  }

  /// Not sent again (each request would pay a refusal) until it changes,
  /// and renewed in the background for the next requests.
  void _onWebTokenUnauthorized(String authToken) {
    _refusedWebToken = _tokenId(authToken);
    final renew = onWebTokenRejected;
    if (renew == null) return;
    unawaited(
      renew().then<void>(
        (_) {},
        onError: (Object e) =>
            debugPrint('Web token renewal failed: ${e.runtimeType}'),
      ),
    );
  }

  /// Where the logged-in viewer stopped in [vodId] on Twitch (null when
  /// never watched, logged out, or anything fails). A live session watched
  /// before shows up here once Twitch tied it to its VOD. Never throws.
  Future<ViewingHistory?> getViewingHistory(String vodId) async {
    final id = tryNormalizeVodId(vodId);
    final authToken = _usableWebToken;
    if (id == null || authToken == null) return null;
    final tokenId = _tokenId(authToken);
    if (_historyRefused('read', tokenId)) return null;
    try {
      final data = await _gql(
        'VideoViewingHistory',
        _viewingHistoryQuery,
        {'id': id},
        headers: {'Authorization': 'OAuth $authToken'},
      );
      _historyFailures.remove('read#$tokenId');
      final video = data['video'];
      final self = video is Map ? video['self'] : null;
      final history = self is Map ? self['viewingHistory'] : null;
      final position = history is Map ? history['position'] : null;
      if (position is! int || position < 0) return null;
      return ViewingHistory(
        positionSec: position,
        updatedAt: DateTime.tryParse('${(history as Map)['updatedAt']}'),
      );
    } on UnauthorizedException {
      debugPrint('Watch position read refused (401)');
      _onWebTokenUnauthorized(authToken);
    } on VodApiException catch (e) {
      debugPrint('Watch position read refused (integrity: ${e.isIntegrity})');
      _historyFailed('read', tokenId, e);
    } catch (e) {
      debugPrint('Watch position read failed: ${e.runtimeType}');
    }
    return null;
  }

  /// Saves where the logged-in viewer is in a video to their Twitch
  /// account, like the official app: a VOD by its id, a live broadcast by
  /// its stream id. Only with a session; false when nothing was saved.
  /// Never throws.
  Future<bool> updateViewedVideo({
    required String videoId,
    required WatchedVideoType type,
    required int positionSec,
  }) async {
    final id = tryNormalizeVodId(videoId);
    final userId = viewerId?.call();
    final authToken = _usableWebToken;
    if (id == null ||
        userId == null ||
        !RegExp(r'^[0-9]{1,20}$').hasMatch(userId) ||
        positionSec <= 0 ||
        authToken == null) {
      return false;
    }
    final tokenId = _tokenId(authToken);
    if (_historyRefused('write', tokenId)) return false;
    try {
      final data = await _gql(
        'UpdateUserViewedVideo',
        _updateViewedVideoMutation,
        {
          'input': {
            'userID': userId,
            'videoID': id,
            'videoType': type.gqlName,
            'position': positionSec,
          },
        },
        headers: {'Authorization': 'OAuth $authToken'},
      );
      _historyFailures.remove('write#$tokenId');
      return data['updateUserViewedVideo'] is Map;
    } on UnauthorizedException {
      debugPrint('Watch position write refused (401)');
      _onWebTokenUnauthorized(authToken);
    } on VodApiException catch (e) {
      debugPrint('Watch position write refused (integrity: ${e.isIntegrity})');
      _historyFailed('write', tokenId, e);
    } catch (e) {
      debugPrint('Watch position write failed: ${e.runtimeType}');
    }
    return false;
  }

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
    } else if (_tokens.pending(key) case final pending?) {
      // A preload is on its way: its answer, sooner than our own.
      return pending;
    }
    final token = _fetchToken(id, key, authToken);
    _tokens.track(key, token);
    return token;
  }

  Future<PlaybackAccessToken> _fetchToken(
    String id,
    String key,
    String? authToken,
  ) async {
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

  /// Asks for [vodId]'s playback token ahead of the player (while the
  /// screen waits for other data), so the player finds it cached or on its
  /// way. Never throws: the player asks again if this failed.
  Future<void> preloadToken(String vodId) async {
    try {
      await _getToken(normalizeVodId(vodId), forceFresh: false);
    } catch (e) {
      debugPrint('VOD token preload failed: ${e.runtimeType}');
    }
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

  /// [partial]: an answer with data and errors (one field refused) gives
  /// its data, and its errors to [onErrors]; without data, the errors
  /// still throw.
  Future<JsonMap> _gql(
    String operationName,
    String query,
    JsonMap variables, {
    Map<String, String> headers = const {},
    bool partial = false,
    void Function(List<Object?> errors)? onErrors,
  }) async {
    final body = await post<JsonMap>(
      kTwitchGqlUrl,
      headers: {'Client-ID': kTwitchWebClientId, ...headers},
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
    );
    final errors = body['errors'];
    final hasData = body['data'] is Map;
    if (errors is List && errors.isNotEmpty && partial && hasData) {
      onErrors?.call(errors);
    } else if (errors is List && errors.isNotEmpty) {
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
