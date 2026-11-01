import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/vod.dart';

part 'channel_videos_store.g.dart';

class ChannelVideosStore = ChannelVideosStoreBase with _$ChannelVideosStore;

/// One tab of a channel's videos (past broadcasts, highlights or uploads):
/// the newest 100, which is all Twitch gives an anonymous client in one
/// page (cursor paging is integrity-gated).
abstract class ChannelVideosStoreBase with Store {
  ChannelVideosStoreBase({
    required this.login,
    this.gameId,
    required this.type,
    required this.vodService,
  });

  final String login;

  /// A category instead of a channel: its most viewed videos ([login] and
  /// [type] are then unused).
  final String? gameId;
  final VodType type;
  final TwitchVodService vodService;

  final scrollController = ScrollController();

  Future<void>? _inFlight;

  @readonly
  var _videos = ObservableList<Vod>();

  @readonly
  var _isLoading = false;

  /// At least one load finished (successfully or not).
  @readonly
  var _loaded = false;

  /// Why the list could not load (null when it could); the screen words it.
  @readonly
  ChannelVideosProblem? _error;

  /// Twitch has older videos than the ones listed.
  @readonly
  var _hasMore = false;

  /// Loads the list; a call while loading joins the running request.
  Future<void> load() =>
      _inFlight ??= _load().whenComplete(() => _inFlight = null);

  /// Fetches the list again (pull to refresh).
  Future<void> refresh() => load();

  @action
  Future<void> _load() async {
    _isLoading = true;
    try {
      final gameId = this.gameId;
      final page = gameId != null
          ? await vodService.getCategoryVideos(gameId)
          : await vodService.getChannelVideos(login: login, type: type);
      runInAction(() {
        _videos = page.items.asObservable();
        _hasMore = page.hasMore;
        _error = null;
      });
    } on NotFoundException {
      runInAction(
        () => _error = gameId != null
            ? ChannelVideosProblem.categoryNotFound
            : ChannelVideosProblem.channelNotFound,
      );
    } catch (e) {
      debugPrint('ChannelVideosStore $type failed: $e');
      runInAction(() => _error = ChannelVideosProblem.failed);
    } finally {
      runInAction(() {
        _isLoading = false;
        _loaded = true;
      });
    }
  }

  void dispose() => scrollController.dispose();
}

/// Why a list of videos could not load ([ChannelVideosStoreBase.error]).
enum ChannelVideosProblem {
  /// The category is not on Twitch.
  categoryNotFound,

  /// The channel is not on Twitch.
  channelNotFound,

  /// Anything else.
  failed,
}
