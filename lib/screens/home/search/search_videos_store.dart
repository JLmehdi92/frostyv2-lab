import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:mobx/mobx.dart';

part 'search_videos_store.g.dart';

class SearchVideosStore = SearchVideosStoreBase with _$SearchVideosStore;

/// The Videos tab of search, like the official app: Twitch's video search,
/// 25 at a time, more as the list is scrolled.
abstract class SearchVideosStoreBase with Store {
  SearchVideosStoreBase({required this.vodService});

  final TwitchVodService vodService;

  /// Pages one search may load (the first included), and videos it may
  /// list: paging ends there, whatever Twitch says is left.
  static const maxPages = 10;
  static const maxVideos = 250;

  /// Bumped by every new search: an answer for an older one is dropped.
  var _generation = 0;

  String? _cursor;

  /// Pages loaded for the current search.
  var _pages = 0;

  @readonly
  var _query = '';

  @readonly
  var _videos = ObservableList<Vod>();

  @readonly
  var _loading = false;

  @readonly
  var _loadingMore = false;

  @readonly
  var _hasMore = false;

  /// Why the first page could not be had (null when it could).
  @readonly
  String? _error;

  /// Shows the videos matching [query] (a blank one clears the tab).
  @action
  Future<void> search(String query) async {
    final text = query.trim();
    if (text == _query && (_loading || _error == null)) return;
    final generation = ++_generation;
    _query = text;
    _videos = ObservableList<Vod>();
    _cursor = null;
    _pages = 0;
    _hasMore = false;
    _error = null;
    _loadingMore = false;
    if (text.isEmpty) {
      _loading = false;
      return;
    }
    _loading = true;
    try {
      final page = await vodService.searchVideos(text);
      if (generation != _generation) return;
      runInAction(() {
        _pages = 1;
        _videos.addAll(page.items.take(maxVideos));
        _cursor = page.cursor;
        _hasMore = page.hasMore && page.cursor != null && _belowCaps;
      });
    } catch (e) {
      debugPrint('Video search failed: ${e.runtimeType}');
      if (generation != _generation) return;
      runInAction(() => _error = 'Unable to load videos');
    } finally {
      if (generation == _generation) runInAction(() => _loading = false);
    }
  }

  bool get _belowCaps => _pages < maxPages && _videos.length < maxVideos;

  /// Runs the current search again (after a failure).
  @action
  Future<void> retry() {
    final query = _query;
    _query = '';
    return search(query);
  }

  /// The next page, once; a failure ends paging without a word (Twitch may
  /// refuse a page to an anonymous client) and keeps what is shown.
  @action
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (!_hasMore || cursor == null || _loading || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    try {
      final page = await vodService.searchVideos(_query, cursor: cursor);
      if (generation != _generation) return;
      runInAction(() {
        _pages++;
        final known = {for (final video in _videos) video.id};
        final added = page.items
            .where((video) => known.add(video.id))
            .take(maxVideos - _videos.length)
            .toList();
        _videos.addAll(added);
        // A page that adds nothing, or points back to itself, would be
        // asked for again on every rebuild of the list's end.
        final next = page.cursor;
        _hasMore =
            page.hasMore &&
            next != null &&
            next != cursor &&
            added.isNotEmpty &&
            _belowCaps;
        _cursor = next;
      });
    } catch (e) {
      debugPrint('Video search paging failed: ${e.runtimeType}');
      if (generation == _generation) runInAction(() => _hasMore = false);
    } finally {
      if (generation == _generation) runInAction(() => _loadingMore = false);
    }
  }
}
