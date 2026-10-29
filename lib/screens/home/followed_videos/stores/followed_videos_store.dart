import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/vod.dart';

part 'followed_videos_store.g.dart';

class FollowedVideosStore = FollowedVideosStoreBase with _$FollowedVideosStore;

/// The newest videos of the channels the viewer follows (PRF-16): their
/// follows from Helix, then a few videos of each from GQL, newest first.
abstract class FollowedVideosStoreBase with Store {
  FollowedVideosStoreBase({
    required this.twitchApi,
    required this.vodService,
    required this.userId,
  });

  final TwitchApi twitchApi;
  final TwitchVodService vodService;
  final String userId;

  /// Followed channels read (20 per Helix page).
  static const maxChannels = 100;

  /// Videos shown at most.
  static const maxVideos = 100;

  @readonly
  List<Vod> _videos = const [];

  @readonly
  var _loading = false;

  @readonly
  String? _error;

  /// Loads (or reloads) the list; a failure keeps what was shown.
  @action
  Future<void> load() async {
    _loading = true;
    try {
      final ids = <String>[];
      String? cursor;
      do {
        final page = await twitchApi.getFollowedChannels(
          userId: userId,
          cursor: cursor,
        );
        ids.addAll(page.data.map((channel) => channel.broadcasterId));
        cursor = page.pagination['cursor'];
        if (page.data.isEmpty) break;
      } while (cursor != null && ids.length < maxChannels);
      final videos = await vodService.getFollowedVideos(
        ids.take(maxChannels).toList(),
      );
      _videos = videos.take(maxVideos).toList();
      _error = null;
    } on NetworkException {
      _error = 'Unable to connect to Twitch';
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Followed videos: $e');
    } catch (e) {
      _error = 'Something went wrong loading videos';
      debugPrint('Followed videos: $e');
    }
    _loading = false;
  }
}
