import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/utils/content_labels.dart';

part 'live_feed_store.g.dart';

/// A category chip of the Live feed.
typedef LiveFeedChip = ({String id, String name});

/// Builds a list of the feed (tests pass fakes).
typedef LiveFeedListFactory =
    ListStore Function({required ListType type, String? categoryId});

class LiveFeedStore = LiveFeedStoreBase with _$LiveFeedStore;

/// Home's Live feed: the top live streams,
/// one at a time, or those of a category chosen in the chips; the channels
/// the viewer is not interested in are left out for this session.
///
/// The lists are [ListStore]s, so the language, the hidden content labels
/// (with their "Show"), the pages and the refresh work as on any list.
///
/// While mature-content warnings are on, it also reads each channel's
/// content labels (a page at a time, once per channel) so that a labelled
/// channel's preview waits for the viewer's consent ([labelsOf]).
abstract class LiveFeedStoreBase with Store {
  LiveFeedStoreBase({
    required AuthStore authStore,
    required this.settingsStore,
    required TwitchApi twitchApi,
    TwitchDirectoryService? directoryService,
    LiveFeedListFactory? listFactory,
    DateTime Function()? now,
  }) : _twitchApi = twitchApi,
       _now = now ?? DateTime.now,
       _listFactory =
           listFactory ??
           (({required type, categoryId}) => ListStore(
             authStore: authStore,
             settingsStore: settingsStore,
             twitchApi: twitchApi,
             listType: type,
             categoryId: categoryId,
             directoryService: directoryService,
           )) {
    _all = _listFactory(type: ListType.top);
    // The chips are the categories of the first page, taken again each time
    // the list starts over (a refresh, another language), not as pages
    // come in: they never shuffle under the finger.
    _disposers
      ..add(
        reaction(
          (_) => _all.allStreams,
          (_) => _takeChips(),
          fireImmediately: true,
        ),
      )
      // Another language: the list starts over, from its first channel.
      ..add(
        reaction(
          (_) => settingsStore.streamLanguage,
          (_) => runInAction(() => _index = 0),
        ),
      )
      // The previews' warnings: the labels of the channels as they come.
      ..add(
        reaction<(bool, List<String>)>(
          (_) => (
            settingsStore.warnMatureContent,
            [for (final stream in streams) stream.userId],
          ),
          (_) => unawaited(_readLabels()),
          fireImmediately: true,
          // The same channels again (a page that changed nothing): no scan.
          equals: (a, b) => a?.$1 == b?.$1 && listEquals(a?.$2, b?.$2),
        ),
      );
  }

  final SettingsStore settingsStore;
  final TwitchApi _twitchApi;
  final DateTime Function() _now;

  /// How long a channel's labels are trusted: a channel may add some
  /// mid-stream, so older ones are read again with the next page (and
  /// every refresh reads them all again).
  static const labelsTtl = Duration(minutes: 10);
  final LiveFeedListFactory _listFactory;
  late final ListStore _all;
  ListStore? _category;
  final _disposers = <ReactionDisposer>[];

  /// Categories shown as chips at most (after "All").
  static const maxChips = 4;

  /// The category chosen (null: All).
  @readonly
  String? _categoryId;

  @readonly
  List<LiveFeedChip> _chips = const [];

  /// Channels the viewer is not interested in (this session).
  @readonly
  var _hidden = ObservableSet<String>();

  /// The stream on screen, in [streams].
  @readonly
  var _index = 0;

  /// The content labels of the channels read so far (Twitch's label ids,
  /// named by the feed; empty when none, null when Twitch could not say).
  final _labels = ObservableMap<String, List<String>?>();

  /// The channels whose labels are being read.
  final _reading = <String>{};

  /// When each channel's labels were last read.
  final _readAt = <String, DateTime>{};
  var _disposed = false;

  /// Whether [userId]'s labels were read (or could not be).
  bool knowsLabelsOf(String userId) => _labels.containsKey(userId);

  /// [userId]'s content label ids: empty when it has none, null when they
  /// are not known (not read yet, or Twitch could not say).
  List<String>? labelsOf(String userId) => _labels[userId];

  /// Reads the labels of the feed's channels not known yet, or read more
  /// than [labelsTtl] ago ([again]: all of them, a refresh). Labels known
  /// before stay when a new read fails: only channels never read become
  /// unknown.
  Future<void> _readLabels({bool again = false}) async {
    if (!settingsStore.warnMatureContent) return;
    final now = _now();
    bool due(String id) {
      if (again || !_labels.containsKey(id)) return true;
      final readAt = _readAt[id];
      return readAt == null || now.difference(readAt) >= labelsTtl;
    }

    final ids = [
      for (final stream in streams)
        if (!_reading.contains(stream.userId) && due(stream.userId))
          stream.userId,
    ];
    if (ids.isEmpty) return;
    _reading.addAll(ids);
    Map<String, List<String>?> read;
    try {
      final channels = await _twitchApi.getChannelsByIds(ids);
      read = {
        for (final id in ids)
          id: switch (channels[id]) {
            // Ids: the feed names them in the language on screen.
            final channel? => contentLabelIds(
              channel.contentClassificationLabels,
            ),
            // Not in Twitch's answer: unknown, so not previewed unasked.
            null => null,
          },
      };
      for (final id in ids) {
        _readAt[id] = now;
      }
    } catch (e) {
      // Unknown: the previews ask first (they never fail open).
      debugPrint('Preview content labels unavailable: ${e.runtimeType}');
      read = {
        for (final id in ids)
          if (_labels[id] == null) id: null,
      };
    }
    _reading.removeAll(ids);
    if (_disposed) return;
    runInAction(() => _labels.addAll(read));
  }

  /// The list on screen.
  @computed
  ListStore get list => _categoryId == null ? _all : _category ?? _all;

  @computed
  List<StreamTwitch> get streams => [
    for (final stream in list.streams)
      if (!_hidden.contains(stream.userId)) stream,
  ];

  /// The stream on screen (null: none, or the page after the last one:
  /// nothing plays there).
  @computed
  StreamTwitch? get current {
    final shown = streams;
    return _index < shown.length ? shown[_index] : null;
  }

  void _takeChips() {
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final stream in _all.streams) {
      if (stream.gameId.isEmpty || stream.gameName.isEmpty) continue;
      counts[stream.gameId] = (counts[stream.gameId] ?? 0) + 1;
      names[stream.gameId] ??= stream.gameName;
    }
    // The chosen category stays a chip while it is chosen.
    final chosen = _categoryId;
    final chosenChip = chosen == null
        ? null
        : _chips.where((chip) => chip.id == chosen).firstOrNull;
    if (counts.isEmpty && chosenChip == null) return;
    // Most streams first; ties keep the list's (viewers) order.
    final order = counts.keys.toList();
    final ranked = order.indexed.toList()
      ..sort((a, b) {
        final byCount = counts[b.$2]!.compareTo(counts[a.$2]!);
        return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
      });
    final chips = [
      for (final (_, id) in ranked.take(maxChips)) (id: id, name: names[id]!),
    ];
    if (chosenChip != null && !chips.any((chip) => chip.id == chosen)) {
      chips.add(chosenChip);
    }
    runInAction(() => _chips = chips);
  }

  /// Shows [categoryId]'s streams (null: All), from the first.
  @action
  void selectCategory(String? categoryId) {
    if (categoryId == _categoryId) return;
    _category?.dispose();
    _category = categoryId == null
        ? null
        : _listFactory(type: ListType.category, categoryId: categoryId);
    _categoryId = categoryId;
    _index = 0;
  }

  /// The feed moved to [index].
  @action
  void setIndex(int index) {
    _index = index < 0 ? 0 : index;
    final shown = streams.length;
    // The next page, before the viewer reaches the end.
    if (index >= shown - 3 && list.hasMore) list.getStreams();
  }

  /// "Not interested": [userId] leaves the feed for this session.
  @action
  void hide(String userId) => _hidden.add(userId);

  /// Undoes [hide].
  @action
  void unhide(String userId) => _hidden.remove(userId);

  /// Pull to refresh: the list on screen starts over, from its first
  /// channel. [keepPosition] (coming back after a while) keeps the channel
  /// on screen where it is in the new list, else the same place.
  Future<void> refresh({bool keepPosition = false}) async {
    final kept = keepPosition ? current?.userId : null;
    final keptIndex = _index;
    if (!keepPosition) runInAction(() => _index = 0);
    // Every channel's labels are read again (one may have added some
    // mid-stream), also when the new list brings the same channels.
    unawaited(_readLabels(again: true));
    list.lastTimeRefreshed = DateTime.now();
    await list.refreshStreams();
    // Not kept when the viewer moved meanwhile: they stay where they went,
    // within the new list (a shorter one must not leave them past its end).
    if (keepPosition && _index != keptIndex) {
      runInAction(() {
        final shown = streams.length;
        if (_index >= shown) _index = shown == 0 ? 0 : shown - 1;
      });
      return;
    }
    if (!keepPosition) return;
    runInAction(() {
      final shown = streams;
      final found = kept == null
          ? -1
          : shown.indexWhere((stream) => stream.userId == kept);
      _index = found >= 0
          ? found
          : keptIndex.clamp(0, shown.isEmpty ? 0 : shown.length - 1);
    });
  }

  /// "Try again" after a failed page: the next page again, or, when the
  /// list lost its place (a failed refresh), the list again where it was.
  Future<void> retry() async {
    if (list.hasMore) {
      await list.getStreams();
    } else {
      await refresh(keepPosition: true);
    }
  }

  /// How old a list may get before coming back to it refreshes it (as
  /// every list does).
  static const staleAfter = Duration(minutes: 5);

  /// Whether the list on screen is older than [staleAfter].
  bool get stale =>
      DateTime.now().difference(list.lastTimeRefreshed) >= staleAfter;

  void dispose() {
    _disposed = true;
    for (final dispose in _disposers) {
      dispose();
    }
    _all.dispose();
    _category?.dispose();
  }
}
