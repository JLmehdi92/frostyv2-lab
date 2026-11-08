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
    this.featuredOnly,
    this.clipsBetween,
  }) : _period = period,
       _sort = sort;

  final String login;

  /// A category instead of a channel ([login] is then unused).
  final String? gameId;
  final TwitchClipService clipService;
  final bool Function()? featuredOnly;
  final Future<List<Clip>> Function(DateTime start, DateTime end)?
  clipsBetween;

  static const defaultPeriod = ClipPeriod.lastWeek;

  @readonly
  ClipDateRange? _range;

  final _rangePages = <ClipDateRange, ClipPage>{};

  bool get canPickRange => clipsBetween != null;

  @computed
  bool get isFiltered =>
      _range != null || _period != defaultPeriod || _sort != ClipSort.top;

  @computed
  List<ClipSort> get sorts => [
    for (final sort in ClipSort.values)
      if (_range == null || sort != ClipSort.trending) sort,
  ];

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

  /// Why the list could not load (null when it could); the screen words it.
  @readonly
  ChannelClipsProblem? _error;

  /// Twitch has more clips than the ones listed.
  @readonly
  var _hasMore = false;

  (ClipPeriod, ClipSort) get _key => (_period, _sort.fetched);

  /// Shows the list of the current chips, fetching it once; a call while
  /// loading joins the running request.
  Future<void> load() {
    final range = _range;
    if (range != null) {
      final page = _rangePages[range];
      if (page != null) {
        _show(page);
        return Future.value();
      }
      return _fetchRange(range);
    }
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
      if (period != null) _range = null;
      _period = period ?? _period;
      _sort = sort ?? _sort;
    });
    return load();
  }

  Future<void> selectRange(DateTime start, DateTime end) {
    if (!canPickRange || !end.isAfter(start)) return Future.value();
    runInAction(() {
      _range = (start: start, end: end);
      if (_sort == ClipSort.trending) _sort = ClipSort.top;
    });
    return load();
  }

  Future<void> reset() {
    runInAction(() {
      _range = null;
      _period = defaultPeriod;
      _sort = ClipSort.top;
    });
    return load();
  }

  Future<void> refresh() {
    final range = _range;
    return range != null ? _fetchRange(range) : _fetch(_key);
  }

  Future<void>? _rangeInFlight;
  ClipDateRange? _rangeInFlightKey;

  Future<void> _fetchRange(ClipDateRange range) {
    if (_rangeInFlightKey == range && _rangeInFlight != null) {
      runInAction(() => _isLoading = true);
      return _rangeInFlight!;
    }
    _rangeInFlightKey = range;
    return _rangeInFlight = _loadRange(range).whenComplete(() {
      if (_rangeInFlightKey == range) {
        _rangeInFlight = null;
        _rangeInFlightKey = null;
      }
    });
  }

  Future<void> _loadRange(ClipDateRange range) async {
    final clipsBetween = this.clipsBetween;
    if (clipsBetween == null) return;
    runInAction(() => _isLoading = true);
    try {
      final clips = await clipsBetween(range.start, range.end);
      final page = ClipPage(items: clips, hasMore: clips.length >= 100);
      _rangePages[range] = page;
      if (_range == range) _show(page);
    } catch (e) {
      debugPrint('ChannelClipsStore range failed: $e');
      if (_range != range) return;
      final kept = _rangePages[range];
      if (kept != null) {
        _show(kept);
        return;
      }
      runInAction(() {
        _clips = const [];
        _hasMore = false;
        _error = ChannelClipsProblem.failed;
        _isLoading = false;
        _loaded = true;
      });
    }
  }

  @action
  void _show(ClipPage page) {
    final featured =
        gameId == null && page.featuredKnown && (featuredOnly?.call() ?? false);
    _clips = _sort.order(
      featured
          ? [
              for (final clip in page.items)
                if (clip.isFeatured) clip,
            ]
          : page.items,
    );
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
      if (key == _key && _range == null) _show(page);
    } on NotFoundException {
      _showError(
        key,
        gameId != null
            ? ChannelClipsProblem.categoryNotFound
            : ChannelClipsProblem.channelNotFound,
      );
    } catch (e) {
      debugPrint('ChannelClipsStore ${key.$1} ${key.$2} failed: $e');
      _showError(key, ChannelClipsProblem.failed);
    }
  }

  void _showError((ClipPeriod, ClipSort) key, ChannelClipsProblem problem) {
    if (key != _key || _range != null) return;
    final kept = _pages[key];
    if (kept != null) {
      _show(kept);
      return;
    }
    runInAction(() {
      _clips = const [];
      _hasMore = false;
      _error = problem;
      _isLoading = false;
      _loaded = true;
    });
  }

  void dispose() => scrollController.dispose();
}

/// Why a list of clips could not load ([ChannelClipsStoreBase.error]).
enum ChannelClipsProblem {
  /// The category is not on Twitch.
  categoryNotFound,

  /// The channel is not on Twitch.
  channelNotFound,

  /// Anything else.
  failed,
}
