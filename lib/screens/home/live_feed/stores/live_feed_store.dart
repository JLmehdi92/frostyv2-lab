import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';

part 'live_feed_store.g.dart';

/// A category chip of the Live feed.
typedef LiveFeedChip = ({String id, String name});

/// Builds a list of the feed (tests pass fakes).
typedef LiveFeedListFactory =
    ListStore Function({required ListType type, String? categoryId});

class LiveFeedStore = LiveFeedStoreBase with _$LiveFeedStore;

/// Home's Live feed (boards Live and LiveTablette): the top live streams,
/// one at a time, or those of a category chosen in the chips; the channels
/// the viewer is not interested in are left out for this session.
///
/// The lists are [ListStore]s, so the language, the hidden content labels
/// (with their "Show"), the pages and the refresh work as on any list.
abstract class LiveFeedStoreBase with Store {
  LiveFeedStoreBase({
    required AuthStore authStore,
    required this.settingsStore,
    required TwitchApi twitchApi,
    TwitchDirectoryService? directoryService,
    LiveFeedListFactory? listFactory,
  }) : _listFactory =
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
      );
  }

  final SettingsStore settingsStore;
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
    list.lastTimeRefreshed = DateTime.now();
    await list.refreshStreams();
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
    for (final dispose in _disposers) {
      dispose();
    }
    _all.dispose();
    _category?.dispose();
  }
}
