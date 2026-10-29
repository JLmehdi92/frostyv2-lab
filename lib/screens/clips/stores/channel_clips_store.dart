import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';

part 'channel_clips_store.g.dart';

class ChannelClipsStore = ChannelClipsStoreBase with _$ChannelClipsStore;

/// A channel's clips for the chosen period and sort: the top 100, which is
/// all Twitch gives an anonymous client (cursor paging is integrity-gated).
/// Each chip's list is kept, so switching back is instant.
abstract class ChannelClipsStoreBase with Store {
  ChannelClipsStoreBase({
    required this.login,
    this.gameId,
    required this.clipService,
    ClipPeriod period = ClipPeriod.lastWeek,
    ClipSort sort = ClipSort.top,
  }) : _period = period,
       _sort = sort;

  final String login;

  /// A category instead of a channel ([login] is then unused).
  final String? gameId;
  final TwitchClipService clipService;

  final scrollController = ScrollController();

  final _pages = <(ClipPeriod, ClipSort), ClipPage>{};
  final _inFlight = <(ClipPeriod, ClipSort), Future<void>>{};

  @readonly
  ClipPeriod _period;

  @readonly
  ClipSort _sort;

  @readonly
  List<Clip> _clips = const [];

  @readonly
  var _isLoading = false;

  /// At least one load finished (successfully or not).
  @readonly
  var _loaded = false;

  @readonly
  String? _error;

  /// Twitch has more clips than the ones listed.
  @readonly
  var _hasMore = false;

  (ClipPeriod, ClipSort) get _key => (_period, _sort);

  /// Shows the list of the current chips, fetching it once; a call while
  /// loading joins the running request.
  Future<void> load() {
    final key = _key;
    final page = _pages[key];
    if (page != null) {
      _show(page);
      return Future.value();
    }
    return _fetch(key);
  }

  /// One request per chip at a time; a call while loading joins it.
  Future<void> _fetch((ClipPeriod, ClipSort) key) {
    final running = _inFlight[key];
    if (running != null) {
      // Back on a chip still loading: its spinner, not the last list.
      runInAction(() => _isLoading = true);
      return running;
    }
    // A block body: `remove` returns this very future, which `whenComplete`
    // would then wait for.
    return _inFlight[key] = _load(key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Switches chips (keeping the other one as it is).
  Future<void> select({ClipPeriod? period, ClipSort? sort}) {
    runInAction(() {
      _period = period ?? _period;
      _sort = sort ?? _sort;
    });
    return load();
  }

  /// Fetches the current chips' list again (pull to refresh). A failure
  /// keeps the list already shown.
  Future<void> refresh() => _fetch(_key);

  @action
  void _show(ClipPage page) {
    _clips = page.items;
    _hasMore = page.hasMore;
    _error = null;
    _isLoading = false;
    _loaded = true;
  }

  Future<void> _load((ClipPeriod, ClipSort) key) async {
    runInAction(() => _isLoading = true);
    try {
      final gameId = this.gameId;
      final page = gameId != null
          ? await clipService.getCategoryClips(
              gameId: gameId,
              period: key.$1,
              sort: key.$2,
            )
          : await clipService.getChannelClips(
              login: login,
              period: key.$1,
              sort: key.$2,
            );
      _pages[key] = page;
      // The viewer may have picked other chips meanwhile.
      if (key == _key) _show(page);
    } on NotFoundException {
      _showError(
        key,
        gameId != null ? 'Category not found' : 'Channel not found',
      );
    } catch (e) {
      debugPrint('ChannelClipsStore ${key.$1} ${key.$2} failed: $e');
      _showError(key, "Couldn't load clips");
    }
  }

  void _showError((ClipPeriod, ClipSort) key, String message) {
    if (key != _key) return;
    final kept = _pages[key];
    if (kept != null) {
      _show(kept);
      return;
    }
    runInAction(() {
      _clips = const [];
      _hasMore = false;
      _error = message;
      _isLoading = false;
      _loaded = true;
    });
  }

  void dispose() => scrollController.dispose();
}
