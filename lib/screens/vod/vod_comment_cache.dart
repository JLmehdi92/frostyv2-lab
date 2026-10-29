import 'package:onset/models/vod_comment.dart';

/// Replayed chat fetched by offset, indexed by second, with the ranges of
/// seconds known to be complete.
///
/// Twitch answers an offset with a page of about 50 comments starting at (or
/// just before) it; there is no anonymous way to page further inside one
/// second (cursors are integrity-gated), so a second with more comments than
/// a page loses the rest.
class VodCommentCache {
  final _bySecond = <int, List<VodComment>>{};
  final _seenKeys = <String>{};

  /// Complete seconds as sorted, merged, inclusive ranges.
  final _covered = <(int, int)>[];

  /// Number of cached comments.
  int get length => _seenKeys.length;

  /// Stores [page], fetched for [requestedSecond], and marks the seconds it
  /// completes: from [requestedSecond] (or from the second after its first
  /// comment, when it starts earlier: that second may be cut) to the second
  /// before its last comment (the page may stop in the middle of that
  /// second), or to the end of the video when it is the last page. A page
  /// stuck in one busy second still covers that second so replay moves on.
  void addPage({
    required int requestedSecond,
    required VodCommentPage page,
    required int videoLengthSeconds,
  }) {
    var minOffset = requestedSecond;
    var maxOffset = requestedSecond;
    final pageBySecond = <int, List<VodComment>>{};
    for (final comment in page.comments) {
      final second = comment.offsetSeconds;
      if (second > maxOffset) maxOffset = second;
      if (second < minOffset) minOffset = second;
      (pageBySecond[second] ??= []).add(comment);
    }
    pageBySecond.forEach(_merge);
    var end = page.hasNextPage ? maxOffset - 1 : videoLengthSeconds;
    if (end > videoLengthSeconds) end = videoLengthSeconds;
    if (end < requestedSecond) end = requestedSecond;
    final start = minOffset < requestedSecond ? minOffset + 1 : requestedSecond;
    _cover(start, end);
  }

  /// Adds a page's comments of one second. When the page shares a comment
  /// with what is cached, its order is the true one (it saw the second from
  /// earlier on); comments only cached so far come after it.
  void _merge(int second, List<VodComment> fromPage) {
    final cached = _bySecond[second];
    if (cached == null) {
      final fresh = [
        for (final c in fromPage)
          if (_seenKeys.add(c.key)) c,
      ];
      if (fresh.isNotEmpty) _bySecond[second] = fresh;
      return;
    }
    final pageKeys = {for (final c in fromPage) c.key};
    final overlaps = cached.any((c) => pageKeys.contains(c.key));
    if (!overlaps) {
      for (final c in fromPage) {
        if (_seenKeys.add(c.key)) cached.add(c);
      }
      return;
    }
    final ordered = <VodComment>[];
    final added = <String>{};
    for (final c in fromPage) {
      if (added.add(c.key)) ordered.add(c);
      _seenKeys.add(c.key);
    }
    for (final c in cached) {
      if (added.add(c.key)) ordered.add(c);
    }
    _bySecond[second] = ordered;
  }

  bool isCovered(int second) => _rangeOf(second) != null;

  /// [second] when it is not covered, else the first second after its range.
  int firstUncoveredFrom(int second) {
    final range = _rangeOf(second);
    return range == null ? second : range.$2 + 1;
  }

  /// Comments with `fromExclusive < offset <= toInclusive`, oldest first.
  List<VodComment> commentsIn(int fromExclusive, int toInclusive) {
    final seconds =
        _bySecond.keys
            .where((s) => s > fromExclusive && s <= toInclusive)
            .toList()
          ..sort();
    return [for (final s in seconds) ..._bySecond[s]!];
  }

  /// The newest [n] comments at or before [second], oldest first, taken only
  /// from the covered stretch around [second] (an earlier part of the video
  /// must not pass for what led up to it).
  List<VodComment> lastN(int second, int n) {
    final from = _rangeOf(second)?.$1 ?? second;
    final seconds =
        _bySecond.keys.where((s) => s >= from && s <= second).toList()
          ..sort((a, b) => b.compareTo(a));
    final newestFirst = <VodComment>[];
    for (final s in seconds) {
      newestFirst.addAll(_bySecond[s]!.reversed);
      if (newestFirst.length >= n) break;
    }
    return newestFirst.take(n).toList().reversed.toList();
  }

  /// Forgets everything more than [keepSeconds] away from [second], halving
  /// the window until at most [maxComments] remain. Forgotten seconds are no
  /// longer covered, so they are fetched again when needed.
  void evictFarFrom(
    int second, {
    int keepSeconds = 1800,
    int maxComments = 20000,
  }) {
    var keep = keepSeconds;
    while (true) {
      _keepWindow(second - keep, second + keep);
      if (length <= maxComments || keep == 0) return;
      keep ~/= 2;
    }
  }

  void _keepWindow(int from, int to) {
    for (final s in _bySecond.keys.where((s) => s < from || s > to).toList()) {
      for (final comment in _bySecond.remove(s)!) {
        _seenKeys.remove(comment.key);
      }
    }
    final trimmed = [
      for (final (start, end) in _covered)
        if (end >= from && start <= to)
          (start < from ? from : start, end > to ? to : end),
    ];
    _covered
      ..clear()
      ..addAll(trimmed);
  }

  (int, int)? _rangeOf(int second) {
    for (final range in _covered) {
      if (second < range.$1) return null;
      if (second <= range.$2) return range;
    }
    return null;
  }

  void _cover(int start, int end) {
    final ranges = [..._covered, (start, end)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && range.$1 <= merged.last.$2 + 1) {
        final last = merged.removeLast();
        merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
      } else {
        merged.add(range);
      }
    }
    _covered
      ..clear()
      ..addAll(merged);
  }
}
