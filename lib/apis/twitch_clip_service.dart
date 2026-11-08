import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/clip.dart';

/// A GQL error answered for a clip request.
class ClipApiException extends ApiException {
  const ClipApiException(super.message, {this.isIntegrity = false});

  /// Twitch asked for a client-integrity token (feature unavailable to us).
  final bool isIntegrity;

  @override
  String toString() => 'ClipApiException: $message';
}

/// The clip playback token says the viewer may not watch it.
class ClipForbiddenException extends ApiException {
  const ClipForbiddenException(this.reason)
    : super('Clip playback is forbidden');

  final String? reason;
}

/// Clips from Twitch GQL, anonymously (the public web Client-ID and full
/// query documents, no user token): a channel's top clips, one clip, and its
/// signed MP4 renditions.
///
/// Channel and category lists are fetched without cursors: their cursor
/// paging is integrity-gated for anonymous clients (verified 2026-10-13).
/// The top clips feed pages with its cursor (verified 2026-10-20).
class TwitchClipService extends BaseApiClient {
  TwitchClipService(Dio dio) : super(dio, '');

  /// Public web client-id used by twitch.tv itself (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const _gqlUrl = 'https://gql.twitch.tv/gql';

  static const _clipFields =
      'id slug title viewCount createdAt durationSeconds thumbnailURL '
      'videoOffsetSeconds curator { id login displayName } '
      'broadcaster { id login displayName } game { id name } video { id }';

  static const _channelClipsQuery =
      'query ChannelClips(\$login: String!, \$first: Int, '
      '\$period: ClipsPeriod, \$sort: ClipsSort) { user(login: \$login) { '
      'id login displayName clips(first: \$first, criteria: {period: '
      '\$period, sort: \$sort}) { edges { node { $_clipFields } } '
      'pageInfo { hasNextPage } } } }';

  static final _channelClipsFeaturedQuery = _channelClipsQuery.replaceFirst(
    '$_clipFields }',
    '$_clipFields isFeatured }',
  );

  static const _curatedClipsQuery =
      'query CuratedClips(\$id: ID!, \$first: Int, \$period: ClipsPeriod, '
      '\$sort: ClipsSort) { user(id: \$id) { id clips(first: \$first, '
      'criteria: {role: CURATOR, period: \$period, sort: \$sort}) { edges { '
      'node { $_clipFields } } pageInfo { hasNextPage } } } }';

  static const _categoryClipsQuery =
      'query CategoryClips(\$id: ID!, \$first: Int, \$period: ClipsPeriod, '
      '\$sort: ClipsSort) { game(id: \$id) { id clips(first: \$first, '
      'criteria: {period: \$period, sort: \$sort}) { edges { node { '
      '$_clipFields } } pageInfo { hasNextPage } } } }';

  // The clips feed: Twitch's top clips, paged with its cursor (answers anonymously, verified 2026-10-20).
  static const _topClipsQuery =
      'query TopClipsFeed(\$first: Int, \$after: Cursor, '
      '\$languages: [String!]) { topClips(first: \$first, after: \$after, '
      'languages: \$languages) { edges { node { $_clipFields } } '
      'pageInfo { hasNextPage endCursor } } }';

  /// Clips per [getTopClips] page.
  static const topClipsPageSize = 20;

  static const _clipQuery =
      'query Clip(\$slug: ID!) { clip(slug: \$slug) { $_clipFields } }';

  static const _playbackQuery =
      'query ClipPlayback(\$slug: ID!) { clip(slug: \$slug) { id '
      'playbackAccessToken(params: {platform: "web", playerBackend: '
      '"mediaplayer", playerType: "site"}) { signature value } '
      'videoQualities { quality frameRate sourceURL } '
      'assets { type videoQualities { quality frameRate sourceURL } } } }';

  /// The channel's top 100 clips of [period], in [sort] order.
  Future<ClipPage> getChannelClips({
    required String login,
    required ClipPeriod period,
    required ClipSort sort,
  }) async {
    final variables = <String, Object?>{
      'login': login,
      'first': 100,
      'period': period.gqlName,
      'sort': sort.gqlName,
    };
    JsonMap data;
    var featuredKnown = true;
    try {
      data = await _gql('ChannelClips', _channelClipsFeaturedQuery, variables);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on ClipApiException catch (e) {
      if (e.isIntegrity) rethrow;
      featuredKnown = false;
      data = await _gql('ChannelClips', _channelClipsQuery, variables);
    } on ApiException {
      featuredKnown = false;
      data = await _gql('ChannelClips', _channelClipsQuery, variables);
    }
    final user = data['user'];
    if (user is! Map) throw const NotFoundException('Channel not found');
    final owner = {
      'id': user['id'],
      'login': user['login'],
      'displayName': user['displayName'],
    };
    final clips = user['clips'] is Map ? user['clips'] as Map : const {};
    final edges = clips['edges'] is List ? clips['edges'] as List : const [];
    final items = <Clip>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(
          Clip.fromGql(JsonMap.from(edge['node'] as Map), broadcaster: owner),
        );
      } on FormatException {
        // One unreadable clip must not hide the others.
      }
    }
    final pageInfo = clips['pageInfo'];
    return ClipPage(
      items: items,
      hasMore: pageInfo is Map && pageInfo['hasNextPage'] == true,
      featuredKnown: featuredKnown,
    );
  }

  Future<ClipPage> getCuratedClips({
    required String curatorId,
    required ClipPeriod period,
    required ClipSort sort,
  }) async {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(curatorId)) {
      throw const NotFoundException('Not a user id');
    }
    final data = await _gql('CuratedClips', _curatedClipsQuery, {
      'id': curatorId,
      'first': 100,
      'period': period.gqlName,
      'sort': sort.gqlName,
    });
    final user = data['user'];
    if (user is! Map) throw const NotFoundException('User not found');
    final clips = user['clips'] is Map ? user['clips'] as Map : const {};
    final edges = clips['edges'] is List ? clips['edges'] as List : const [];
    final items = <Clip>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Clip.fromGql(JsonMap.from(edge['node'] as Map)));
      } on FormatException {
        continue;
      }
    }
    final pageInfo = clips['pageInfo'];
    return ClipPage(
      items: items,
      hasMore: pageInfo is Map && pageInfo['hasNextPage'] == true,
    );
  }

  /// A category's top 100 clips of [period], in [sort] order.
  Future<ClipPage> getCategoryClips({
    required String gameId,
    required ClipPeriod period,
    required ClipSort sort,
  }) async {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(gameId)) {
      throw ArgumentError.value(gameId, 'gameId', 'Not a category id');
    }
    final data = await _gql('CategoryClips', _categoryClipsQuery, {
      'id': gameId,
      'first': 100,
      'period': period.gqlName,
      'sort': sort.gqlName,
    });
    final game = data['game'];
    if (game is! Map) throw const NotFoundException('Category not found');
    final clips = game['clips'];
    if (clips is! Map) throw const ClipApiException('Unreadable clips');
    final edges = clips['edges'] is List
        ? (clips['edges'] as List).take(100).toList()
        : const [];
    final items = <Clip>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Clip.fromGql(JsonMap.from(edge['node'] as Map)));
      } on FormatException {
        // One unreadable clip must not hide the others.
      }
    }
    // All of them unreadable: Twitch changed something, not an empty list.
    if (items.isEmpty && edges.isNotEmpty) {
      throw const ClipApiException('Unreadable clips');
    }
    final pageInfo = clips['pageInfo'];
    return ClipPage(
      items: items,
      hasMore: pageInfo is Map && pageInfo['hasNextPage'] == true,
    );
  }

  /// A page of Twitch's top clips (the clips feed), from [cursor] (null:
  /// the first page), in [language] (an ISO code; null or empty: all).
  Future<ClipFeedPage> getTopClips({String? cursor, String? language}) async {
    final data = await _gql('TopClipsFeed', _topClipsQuery, {
      'first': topClipsPageSize,
      if (cursor != null && cursor.isNotEmpty) 'after': cursor,
      if (language != null && language.isNotEmpty) 'languages': [language],
    });
    final clips = data['topClips'];
    if (clips is! Map) throw const ClipApiException('Unreadable clips');
    final edges = clips['edges'] is List ? clips['edges'] as List : const [];
    final items = <Clip>[];
    for (final edge in edges) {
      if (edge is! Map || edge['node'] is! Map) continue;
      try {
        items.add(Clip.fromGql(JsonMap.from(edge['node'] as Map)));
      } on FormatException {
        // One unreadable clip must not hide the others.
      }
    }
    if (items.isEmpty && edges.isNotEmpty) {
      throw const ClipApiException('Unreadable clips');
    }
    final pageInfo = clips['pageInfo'];
    final next = pageInfo is Map ? pageInfo['endCursor'] : null;
    final hasMore =
        pageInfo is Map &&
        pageInfo['hasNextPage'] == true &&
        next is String &&
        next.isNotEmpty;
    return ClipFeedPage(items: items, cursor: hasMore ? next : null);
  }

  /// The clip, or null when it does not exist (deleted or wrong slug).
  /// Throws an [ArgumentError] for a [slug] that is not a clip slug.
  Future<Clip?> getClip(String slug) async {
    _checkSlug(slug);
    final data = await _gql('Clip', _clipQuery, {'slug': slug});
    final clip = data['clip'];
    if (clip is! Map) return null;
    try {
      return Clip.fromGql(JsonMap.from(clip));
    } on FormatException {
      throw const ClipApiException('Unreadable clip');
    }
  }

  /// The clip's renditions and access token. Throws [NotFoundException] when
  /// the clip is gone and [ClipForbiddenException] when the token denies
  /// playback.
  Future<File> downloadClip(String slug, Directory folder) async {
    final playback = await getClipPlayback(slug);
    if (playback.renditions.isEmpty) {
      throw const ApiException('No rendition for this clip');
    }
    final rendition = playback.renditions.firstWhere(
      (r) => r.height <= 720,
      orElse: () => playback.renditions.last,
    );
    final response = await dio.get<List<int>>(
      playback.signedUrl(rendition),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const ApiException('Empty clip download');
    }
    final file = File('${folder.path}/onset-clip-$slug.mp4');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<ClipPlayback> getClipPlayback(String slug) async {
    _checkSlug(slug);
    final data = await _gql('ClipPlayback', _playbackQuery, {'slug': slug});
    final clip = data['clip'];
    if (clip is! Map) throw const NotFoundException('Clip not found');
    final token = clip['playbackAccessToken'];
    if (token is! Map || token['value'] is! String) {
      throw const ApiException('No playback access token for this clip');
    }
    final value = token['value'] as String;
    final authorization = _authorization(value);
    if (authorization?['forbidden'] == true) {
      final reason = authorization?['reason'];
      throw ClipForbiddenException(
        reason is String && reason.isNotEmpty ? reason : null,
      );
    }
    final renditions = renditionsFrom(JsonMap.from(clip));
    if (renditions.isEmpty) {
      throw const ApiException('No playable rendition for this clip');
    }
    return ClipPlayback(
      renditions: renditions,
      signature: token['signature'] is String
          ? token['signature'] as String
          : '',
      token: value,
    );
  }

  /// The clip's landscape renditions, best first: the `SOURCE` asset (the
  /// `RECOMPOSED` one is a vertical remake), else `videoQualities`. Only
  /// https URLs on Twitch's clip CDNs are kept.
  @visibleForTesting
  static List<ClipRendition> renditionsFrom(JsonMap clip) {
    List<Object?> sourceQualities = const [];
    final assets = clip['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map &&
            asset['type'] == 'SOURCE' &&
            asset['videoQualities'] is List) {
          sourceQualities = asset['videoQualities'] as List;
          break;
        }
      }
    }
    final fromSource = _renditions(sourceQualities);
    if (fromSource.isNotEmpty) return fromSource;
    final qualities = clip['videoQualities'];
    return _renditions(qualities is List ? qualities : const []);
  }

  /// Playable renditions of a `videoQualities` list, best first, one per
  /// label.
  static List<ClipRendition> _renditions(List<Object?> qualities) {
    final renditions = <ClipRendition>[];
    for (final quality in qualities) {
      if (quality is! Map) continue;
      final height = int.tryParse('${quality['quality']}');
      final url = quality['sourceURL'];
      if (height == null || height <= 0) continue;
      if (url is! String || !_isClipCdnUrl(url)) continue;
      final rate = quality['frameRate'];
      final frameRate = rate is num
          ? rate.toDouble()
          : double.tryParse('$rate');
      renditions.add(
        ClipRendition(
          height: height,
          frameRate: frameRate != null && frameRate.isFinite && frameRate > 0
              ? frameRate
              : 30,
          url: url,
        ),
      );
    }
    renditions.sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      return byHeight != 0 ? byHeight : b.frameRate.compareTo(a.frameRate);
    });
    final labels = <String>{};
    return [
      for (final rendition in renditions)
        if (labels.add(rendition.label)) rendition,
    ];
  }

  /// [sourceUrl] signed with the clip access token (see [signClipUrl]).
  @visibleForTesting
  static String signedClipUrl(
    String sourceUrl, {
    required String signature,
    required String token,
  }) => signClipUrl(sourceUrl, signature: signature, token: token);

  /// Hosts the clip access token may be sent to: the CloudFront
  /// distribution Twitch serves clips from (verified 2026-10-13), and
  /// Twitch's own domains. Any other host gets no token: the clip then plays
  /// in the Twitch embed instead.
  static const _cdnHosts = {'d1ndex63qxojbr.cloudfront.net'};
  static const _cdnSuffixes = [
    '.twitch.tv',
    '.twitchcdn.net',
    '.ttvnw.net',
    '.jtvnw.net',
  ];

  static bool _isClipCdnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return _cdnHosts.contains(host) || _cdnSuffixes.any(host.endsWith);
  }

  static Map<String, dynamic>? _authorization(String tokenValue) {
    try {
      final decoded = jsonDecode(tokenValue);
      final authorization = decoded is Map ? decoded['authorization'] : null;
      return authorization is Map
          ? Map<String, dynamic>.from(authorization)
          : null;
    } on FormatException {
      return null;
    }
  }

  static void _checkSlug(String slug) {
    if (!isValidClipSlug(slug)) {
      throw ArgumentError.value(slug, 'slug', 'Not a clip slug');
    }
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
      throw ClipApiException(
        messages,
        isIntegrity: messages.toLowerCase().contains('integrity'),
      );
    }
    final data = body['data'];
    if (data is! Map) throw const ClipApiException('Empty GQL response');
    return JsonMap.from(data);
  }
}
