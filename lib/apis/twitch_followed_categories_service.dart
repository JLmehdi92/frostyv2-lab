import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/followed_category.dart';

/// The categories the viewer follows, from Twitch's private GQL with the
/// viewer's twitch.tv web token (Helix has no such list).
///
/// Every failure (an integrity refusal, a changed schema, a token Twitch no
/// longer accepts, the network) answers null, once, and the caller hides
/// the section: nothing here retries.
class TwitchFollowedCategoriesService extends BaseApiClient {
  TwitchFollowedCategoriesService(Dio dio) : super(dio, '');

  /// The public web client-id twitch.tv itself uses (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const _gqlUrl = 'https://gql.twitch.tv/gql';

  static final _numericId = RegExp(r'^[0-9]{1,20}$');

  // The `FollowedGamesQuery` fields ONSET shows, plus the slug for the
  // twitch.tv link. Validated anonymously on 2026-10-20.
  static const _followedQuery =
      'query FollowedGamesQuery(\$first: Int) { currentUser { '
      'followedGames(first: \$first) { nodes { id name displayName slug '
      'viewersCount boxArtURL(width: 285, height: 380) } } } }';

  static const _slugQuery =
      'query OnsetCategorySlug(\$id: ID!) { game(id: \$id) { slug } }';

  /// The followed categories, in Twitch's order, or null when Twitch does
  /// not give them.
  Future<List<FollowedCategory>?> getFollowedCategories({
    required String authToken,
  }) async {
    if (authToken.isEmpty) return null;
    try {
      final body = await post<JsonMap>(
        _gqlUrl,
        headers: {
          'Client-ID': _gqlClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': 'FollowedGamesQuery',
          'query': _followedQuery,
          'variables': {'first': 100},
        },
      );
      if (body['errors'] is List) return null;
      final user = (body['data'] as Map?)?['currentUser'];
      if (user is! Map) return null;
      final nodes = (user['followedGames'] as Map?)?['nodes'];
      if (nodes is! List) return null;
      return [for (final node in nodes) ?FollowedCategory.tryParse(node)];
    } catch (e) {
      if (kDebugMode) debugPrint('Followed categories unavailable: $e');
      return null;
    }
  }

  /// The twitch.tv slug of the category [gameId] (anonymous), or null.
  Future<String?> getCategorySlug(String gameId) async {
    if (!_numericId.hasMatch(gameId)) return null;
    try {
      final body = await post<JsonMap>(
        _gqlUrl,
        headers: {'Client-ID': _gqlClientId},
        data: {
          'query': _slugQuery,
          'variables': {'id': gameId},
        },
      );
      final game = (body['data'] as Map?)?['game'];
      return game is Map ? FollowedCategory.validSlug(game['slug']) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('Category slug unavailable: $e');
      return null;
    }
  }
}
