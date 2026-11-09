import 'package:flutter/foundation.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';

class FollowActions {
  FollowActions({
    required TwitchViewerActionsService service,
    required TwitchApi api,
    required TwitchFollowedCategoriesService categories,
    required String? Function() webToken,
    required String? Function() viewerId,
  }) : _service = service,
       _api = api,
       _categories = categories,
       _webToken = webToken,
       _viewerId = viewerId;

  static const suggestionLimit = 5;

  final TwitchViewerActionsService _service;
  final TwitchApi _api;
  final TwitchFollowedCategoriesService _categories;
  final String? Function() _webToken;
  final String? Function() _viewerId;

  String get _token => _webToken() ?? '';

  bool get canFollowInApp => _token.isNotEmpty && _viewerId() != null;

  Future<FollowResult> followChannel(String channelId) =>
      _service.followChannel(channelId: channelId, authToken: _token);

  Future<FollowResult> unfollowChannel(String channelId) =>
      _service.unfollowChannel(channelId: channelId, authToken: _token);

  Future<FollowResult> followCategory(String categoryId) =>
      _service.followCategory(categoryId: categoryId, authToken: _token);

  Future<FollowResult> unfollowCategory(String categoryId) =>
      _service.unfollowCategory(categoryId: categoryId, authToken: _token);

  Future<bool?> followsCategory(String categoryId) async {
    final followed = await _categories.getFollowedCategories(authToken: _token);
    if (followed == null) return null;
    return followed.any((category) => category.id == categoryId);
  }

  Future<List<StreamTwitch>> suggestionsAfterFollowing(String channelId) async {
    final viewer = _viewerId();
    if (viewer == null) return const [];
    try {
      final current = await _api.getStreamsByIds(userIds: [channelId]);
      final gameId = current.data.isEmpty ? '' : current.data.first.gameId;
      if (gameId.isEmpty) return const [];
      final results = await Future.wait([
        _api.getStreamsUnderCategory(gameId: gameId),
        _api.getFollowedStreams(id: viewer, first: 100, quiet: true),
      ]);
      final followed = {
        for (final stream in results[1].data) stream.userId,
        channelId,
      };
      return List.unmodifiable(
        results[0].data
            .where((stream) => !followed.contains(stream.userId))
            .take(suggestionLimit),
      );
    } catch (e) {
      debugPrint('Follow suggestions unavailable: $e');
      return const [];
    }
  }
}
