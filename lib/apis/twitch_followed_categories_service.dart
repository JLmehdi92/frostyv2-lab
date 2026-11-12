import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/followed_category.dart';

/// The categories the viewer follows, from Twitch's private GQL with the
/// viewer's twitch.tv web token (Helix has no such list).
///
/// Every failure (an integrity refusal, a changed schema, a token Twitch no
/// longer accepts, the network) answers null, once, and the caller hides
/// the section: nothing here retries.
class TwitchFollowedCategoriesService extends BaseApiClient {
  TwitchFollowedCategoriesService(Dio dio) : super(dio, '');

  // The `FollowedGamesQuery` fields ONSET shows, plus the slug for the
  // twitch.tv link. Validated anonymously on 2026-10-20.
  static const _followedQuery =
      'query FollowedGamesQuery(\$first: Int) { currentUser { '
      'followedGames(first: \$first) { nodes { id name displayName slug '
      'viewersCount boxArtURL(width: 285, height: 380) } } } }';

  /// The followed categories, in Twitch's order, or null when Twitch does
  /// not give them.
  Future<List<FollowedCategory>?> getFollowedCategories({
    required String authToken,
  }) async {
    if (authToken.isEmpty) return null;
    try {
      final body = await post<JsonMap>(
        kTwitchGqlUrl,
        headers: {
          'Client-ID': kTwitchWebClientId,
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
}
