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
  });

  final TwitchClipService clipService;

  /// The browse language ('' for all), like the top streams.
  final String language;

  /// Where the feed ends, so memory stays bounded.
  final int maxClips;

  String? _cursor;

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
        _add(page);
      });
    } catch (e) {
      debugPrint('Clips feed failed: ${e.runtimeType}');
      runInAction(() => _error = 'Unable to load clips');
    } finally {
      runInAction(() => _loading = false);
    }
  }

  /// The next page, once; a failure ends the feed without a word (Twitch
  /// may refuse a page to an anonymous client).
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
      runInAction(() => _hasMore = false);
    } finally {
      runInAction(() => _loadingMore = false);
    }
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
