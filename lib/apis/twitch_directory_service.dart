import 'package:dio/dio.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/models/stream.dart';

/// A GQL error answered for a directory request.
class DirectoryApiException extends ApiException {
  const DirectoryApiException(super.message);

  @override
  String toString() => 'DirectoryApiException: $message';
}

/// How a directory orders its live streams, as Twitch's "Sort by".
enum StreamSort {
  /// Helix's own order, the only one that pages past the first answer.
  viewersHigh('Viewers (high to low)', 'VIEWER_COUNT'),
  recommended('Recommended', 'RELEVANCE'),
  viewersLow('Viewers (low to high)', 'VIEWER_COUNT_ASC'),
  recent('Recently started', 'RECENT');

  const StreamSort(this.label, this.gql);

  final String label;
  final String gql;
}

/// Live streams of a category or a tag in any order, from anonymous GQL (the
/// public web Client-ID, full documents, no user token).
///
/// Only the first answer is available: cursor paging is integrity-gated for
/// anonymous clients (verified 2026-10-13), so the lists carry no cursor.
class TwitchDirectoryService extends BaseApiClient {
  TwitchDirectoryService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';

  /// The most streams one answer holds (larger `first` values are refused).
  static const categoryPageSize = 100;
  static const tagPageSize = 30;

  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  /// Twitch's tags: letters and digits, at most 25.
  static final tagPattern = RegExp(r'^[\p{L}\p{N}]{1,25}$', unicode: true);

  // Verified anonymously on 2026-10-13.
  static const _streamFields =
      'id title viewersCount createdAt type language freeformTags { name } '
      'broadcaster { id login displayName } game { id name displayName }';

  static const _categoryQuery =
      'query DirectoryStreams(\$id: ID!, \$first: Int, '
      '\$options: GameStreamOptions) { game(id: \$id) { id '
      'streams(first: \$first, options: \$options) { edges { node { '
      '$_streamFields } } } } }';

  static const _tagQuery =
      'query TagStreams(\$first: Int, \$options: StreamOptions) { '
      'streams(first: \$first, options: \$options) { edges { node { '
      '$_streamFields } } } }';

  /// Live streams of the category [gameId] in [sort] order, in [language]
  /// (a Helix code; '' or 'other' is every language).
  Future<StreamsTwitch> getCategoryStreams({
    required String gameId,
    required StreamSort sort,
    String language = '',
  }) async {
    if (!_numericId.hasMatch(gameId)) {
      throw ArgumentError.value(gameId, 'gameId', 'Not a category id');
    }
    final (:data, :errors) = await _gql('DirectoryStreams', _categoryQuery, {
      'id': gameId,
      'first': categoryPageSize,
      'options': _options(sort, language),
    });
    final game = data['game'];
    if (game is! Map) {
      if (errors.isNotEmpty) throw DirectoryApiException(errors);
      throw const NotFoundException('Category not found');
    }
    return _streams(game['streams'], errors);
  }

  /// Live streams tagged [tag] in [sort] order, in [language].
  Future<StreamsTwitch> getTagStreams({
    required String tag,
    required StreamSort sort,
    String language = '',
  }) async {
    if (!tagPattern.hasMatch(tag)) {
      throw ArgumentError.value(tag, 'tag', 'Not a Twitch tag');
    }
    final (:data, :errors) = await _gql('TagStreams', _tagQuery, {
      'first': tagPageSize,
      'options': {
        ..._options(sort, language),
        'freeformTags': [tag],
      },
    });
    return _streams(data['streams'], errors);
  }

  static Map<String, Object> _options(StreamSort sort, String language) => {
    'sort': sort.gql,
    // GQL knows each ISO 639-1 code; 'other' is ignored there.
    if (RegExp(r'^[a-z]{2}$').hasMatch(language))
      'broadcasterLanguages': [language.toUpperCase()],
  };

  /// A `streams` connection as one page without a cursor; one nulled by an
  /// error throws instead of reading as empty.
  static StreamsTwitch _streams(Object? connection, String errors) {
    if (connection is! Map) {
      throw DirectoryApiException(
        errors.isNotEmpty ? errors : 'Unreadable streams',
      );
    }
    final edges = chList(connection['edges'], max: categoryPageSize);
    final streams = [
      for (final edge in edges) ?streamFromGql(chMap(edge)?['node']),
    ];
    return StreamsTwitch(streams, const {});
  }

  /// A GQL `Stream` node as a Helix stream, or null when it is not a live
  /// stream that can be read.
  static StreamTwitch? streamFromGql(Object? node) {
    final map = chMap(node);
    if (map == null || map['type'] != 'live') return null;
    final broadcaster = chMap(map['broadcaster']);
    final userId = broadcaster?['id'];
    final login = broadcaster?['login'];
    final startedAt = chDate(map['createdAt']);
    if (userId is! String ||
        !_numericId.hasMatch(userId) ||
        login is! String ||
        !_login.hasMatch(login) ||
        startedAt == null) {
      return null;
    }
    final game = chMap(map['game']);
    final gameId = game?['id'];
    final language = chString(map['language'], max: 5)?.toLowerCase() ?? '';
    return StreamTwitch(
      userId,
      login,
      chString(broadcaster!['displayName'], max: 64) ?? login,
      gameId is String && _numericId.hasMatch(gameId) ? gameId : '',
      chString(game?['displayName'], max: 100) ??
          chString(game?['name'], max: 100) ??
          '',
      chString(map['title'], max: 300) ?? '',
      (chInt(map['viewersCount']) ?? 0).clamp(0, 1 << 31),
      startedAt.toIso8601String(),
      // Helix's template, built from the login rather than trusted.
      'https://static-cdn.jtvnw.net/previews-ttv/live_user_'
      '${login.toLowerCase()}-{width}x{height}.jpg',
      tags: [
        for (final tag in chList(map['freeformTags'], max: 10))
          ?chString(chMap(tag)?['name'], max: 25),
      ],
      language: RegExp(r'^[a-z]{2}$').hasMatch(language) ? language : '',
    );
  }

  /// The answer's data, and its error messages ('' when none).
  Future<({Map<dynamic, dynamic> data, String errors})> _gql(
    String operationName,
    String query,
    Map<String, Object> variables,
  ) async {
    final Object? body = await post<dynamic>(
      _gqlUrl,
      headers: {'Client-ID': kTwitchWebClientId},
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
    );
    final data = body is Map ? body['data'] : null;
    final rawErrors = body is Map ? body['errors'] : null;
    // Shown to the viewer: a few, short.
    final errors = [
      for (final error in chList(rawErrors, max: 3))
        ?chString(chMap(error)?['message'], max: 200),
    ].join('; ');
    if (data is! Map) {
      throw DirectoryApiException(
        errors.isNotEmpty ? errors : 'Malformed GQL response',
      );
    }
    return (data: data, errors: errors);
  }
}
