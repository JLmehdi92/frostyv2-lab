import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:mobx/mobx.dart';

part 'clips_feed_store.g.dart';

class ClipsFeedStore = ClipsFeedStoreBase with _$ClipsFeedStore;

/// The clips of the vertical clips feed: Twitch's top clips, page after
/// page as the viewer swipes, up to [maxClips].
abstract class ClipsFeedStoreBase with Store {
  ClipsFeedStoreBase({
    required this.clipService,
    this.language = '',
    this.maxClips = 200,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// How long the feed may stay left before it starts over with fresh
  /// clips when it is opened again (Twitch's top clips move, and an ended
  /// feed would otherwise stay ended). Watching it never ages it.
  static const staleAfter = Duration(minutes: 10);

  /// When the feed was last left (null: loaded since, or on screen).
  DateTime? _leftAt;

  /// The feed was left (its page let go): staleness counts from now.
  void left() => _leftAt = _now();

  /// Whether the feed was left more than [staleAfter] ago.
  bool get stale {
    final leftAt = _leftAt;
    return leftAt != null && _now().difference(leftAt) >= staleAfter;
  }

  final TwitchClipService clipService;

  /// The browse language ('' for all), like the top streams.
  final String language;

  /// Where the feed ends, so memory stays bounded.
  final int maxClips;

  String? _cursor;

  /// The clip the viewer is on (the end page is one past the last clip):
  /// the feed opens there again when it is made again on this list.
  int position = 0;

  @readonly
  var _clips = ObservableList<Clip>();

  @readonly
  var _loading = false;

  @readonly
  var _loadingMore = false;

  @readonly
  var _hasMore = false;

  /// Why the first page could not be had (null when it could).
  @readonly
  String? _error;

  /// The feed ended because a page could not be had (it can be tried
  /// again), not because there are no more clips.
  @readonly
  var _endedOnError = false;

  /// Lets the list go (a stale one): the feed starts over, empty, at the
  /// first clip.
  @action
  void clear() {
    _clips = ObservableList<Clip>();
    position = 0;
    _cursor = null;
    _hasMore = false;
    _endedOnError = false;
    _leftAt = null;
  }

  /// Loads the first page (again, after a failure).
  @action
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    try {
      final page = await clipService.getTopClips(language: language);
      runInAction(() {
        _clips = ObservableList<Clip>();
        position = 0;
        _endedOnError = false;
        _leftAt = null;
        _add(page);
      });
    } catch (e) {
      debugPrint('Clips feed failed: ${e.runtimeType}');
      runInAction(() => _error = 'Unable to load clips');
    } finally {
      runInAction(() => _loading = false);
    }
  }

  /// The next page, once; a failure ends the feed ([endedOnError]: its
  /// end offers to try again; Twitch may refuse a page to an anonymous
  /// client).
  @action
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (!_hasMore || cursor == null || _loading || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await clipService.getTopClips(
        cursor: cursor,
        language: language,
      );
      runInAction(() => _add(page));
    } catch (e) {
      debugPrint('Clips feed paging failed: ${e.runtimeType}');
      runInAction(() {
        _hasMore = false;
        _endedOnError = true;
      });
    } finally {
      runInAction(() => _loadingMore = false);
    }
  }

  /// "Try again" at the end of a feed a failed page ended: that page again.
  @action
  Future<void> retryMore() async {
    if (!_endedOnError || _cursor == null) return;
    _endedOnError = false;
    _hasMore = true;
    await loadMore();
  }

  void _add(ClipFeedPage page) {
    final known = {for (final clip in _clips) clip.slug};
    for (final clip in page.items) {
      if (_clips.length >= maxClips) break;
      if (known.add(clip.slug)) _clips.add(clip);
    }
    _cursor = page.cursor;
    _hasMore = page.hasMore && _clips.length < maxClips;
  }
}
