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
    String? Function()? tvToken,
    required String? Function() viewerId,
    required Future<bool> Function() connectWebSession,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _service = service,
       _api = api,
       _categories = categories,
       _webToken = webToken,
       _tvToken = tvToken ?? _none,
       _viewerId = viewerId,
       _connectWebSession = connectWebSession;

  static const suggestionLimit = 5;
  static const connectCooldown = Duration(minutes: 1);

  final TwitchViewerActionsService _service;
  final TwitchApi _api;
  final TwitchFollowedCategoriesService _categories;
  final String? Function() _webToken;
  final String? Function() _tvToken;
  final String? Function() _viewerId;
  final Future<bool> Function() _connectWebSession;
  final DateTime Function() _now;
  DateTime? _lastFailedConnect;

  static String? _none() => null;

  String get _webSession => _webToken() ?? '';

  String get _token {
    final tv = _tvToken();
    return tv != null && tv.isNotEmpty ? tv : _webSession;
  }

  bool get isSignedIn => _viewerId() != null;

  bool get canFollowInApp => _token.isNotEmpty && isSignedIn;

  Future<bool> connectWebSession() async {
    if (canFollowInApp) return true;
    if (!isSignedIn) return false;
    final lastFailure = _lastFailedConnect;
    if (lastFailure != null &&
        _now().difference(lastFailure) < connectCooldown) {
      return false;
    }
    try {
      await _connectWebSession();
    } catch (e) {
      debugPrint('Connecting the Twitch web session failed: ${e.runtimeType}');
    }
    final connected = canFollowInApp;
    _lastFailedConnect = connected ? null : _now();
    return connected;
  }

  Future<FollowResult> followChannel(String channelId) =>
      _service.followChannel(channelId: channelId, authToken: _token);

  Future<FollowResult> unfollowChannel(String channelId) =>
      _service.unfollowChannel(channelId: channelId, authToken: _token);

  Future<FollowResult> followCategory(String categoryId) =>
      _service.followCategory(categoryId: categoryId, authToken: _token);

  Future<FollowResult> unfollowCategory(String categoryId) =>
      _service.unfollowCategory(categoryId: categoryId, authToken: _token);

  Future<bool?> followsCategory(String categoryId) async {
    if (!isSignedIn || _webSession.isEmpty) return null;
    final followed = await _categories.getFollowedCategories(
      authToken: _webSession,
    );
    if (followed == null) return null;
    return followed.any((category) => category.id == categoryId);
  }

  Future<bool?> followsChannel(String channelId) async {
    final viewer = _viewerId();
    if (viewer == null) return null;
    try {
      return await _api.isFollowing(userId: viewer, broadcasterId: channelId);
    } catch (e) {
      debugPrint('Channel follow state unavailable: $e');
      return null;
    }
  }

  Future<({String id, bool following})?> channelFollowState(
    String login,
  ) async {
    final viewer = _viewerId();
    if (viewer == null) return null;
    try {
      final user = await _api.getUser(userLogin: login);
      final following = await _api.isFollowing(
        userId: viewer,
        broadcasterId: user.id,
      );
      return (id: user.id, following: following);
    } catch (e) {
      debugPrint('Channel follow state unavailable: $e');
      return null;
    }
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
