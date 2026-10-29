import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/followed_category.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/utils/stream_languages.dart';

part 'stream_list_store.g.dart';

class ListStore = ListStoreBase with _$ListStore;

abstract class ListStoreBase with Store {
  /// The authentication store.
  final AuthStore authStore;

  final SettingsStore settingsStore;

  /// Twitch API service class for making requests.
  final TwitchApi twitchApi;

  /// The type of list that this store is handling.
  final ListType listType;

  /// Running hype trains of followed streams (card pills); anonymous GQL.
  final TwitchHypeTrainService? hypeTrainService;

  /// The category id to use when fetching streams if the [listType] is [ListType.category].
  final String? categoryId;

  /// The tag whose streams a [ListType.tag] list shows.
  final String? tag;

  /// False for a store that only gives a category's details (no streams,
  /// no reactions).
  final bool loadStreams;

  /// Sorted category lists and tag lists; anonymous GQL.
  final TwitchDirectoryService? directoryService;

  /// The viewer's followed categories (Following only); private GQL with
  /// the twitch.tv web token.
  final TwitchFollowedCategoriesService? followedCategoriesService;

  /// The viewer's watch streaks, tagged on followed cards like Twitch's
  /// Following tab (Following only); private GQL with the web token.
  final TwitchWatchStreakService? watchStreakService;

  /// The order of a category or tag list. A category in
  /// [StreamSort.viewersHigh] uses Helix and pages; any other order (and
  /// every tag list) is one GQL answer.
  @observable
  StreamSort sort;

  /// The scroll controller used for handling scroll to top (if provided).
  /// If provided, will use the [ScrollToTop] widget to scroll to the top of the list instead of the bottom tab bar.
  final ScrollController? scrollController;

  /// The pagination cursor for the streams.
  String? _streamsCursor;

  /// The pagination cursor for the offline followed channels.
  String? _offlineChannelsCursor;

  /// The last time the streams were refreshed/updated.
  var lastTimeRefreshed = DateTime.now();

  /// Returns whether or not there are more streams and loading status for pagination.
  @computed
  bool get hasMore => isLoading == false && _streamsCursor != null;

  @computed
  bool get isLoading =>
      _isAllStreamsLoading ||
      _isPinnedStreamsLoading ||
      _isCategoryDetailsLoading ||
      _isOfflineChannelsLoading;

  /// The loading status for pagination.

  /// The list of the fetched streams.
  @readonly
  var _allStreams = ObservableList<StreamTwitch>();

  @readonly
  bool _isAllStreamsLoading = false;

  @readonly
  var _pinnedStreams = ObservableList<StreamTwitch>();

  @readonly
  bool _isPinnedStreamsLoading = false;

  @readonly
  CategoryTwitch? _categoryDetails;

  @readonly
  var _isCategoryDetailsLoading = false;

  /// The list of offline followed channels.
  @readonly
  var _allOfflineChannels = ObservableList<FollowedChannel>();

  @readonly
  bool _isOfflineChannelsLoading = false;

  /// Whether or not there are more offline channels for pagination.
  @computed
  bool get hasMoreOfflineChannels =>
      _isOfflineChannelsLoading == false && _offlineChannelsCursor != null;

  /// Whether or not the scroll to top button is visible.
  @observable
  var showJumpButton = false;

  /// Whether the offline channels section is expanded.
  @observable
  var isOfflineChannelsExpanded = false;

  /// The list of the fetched streams with blocked users filtered out, in
  /// the viewer's order for Following.
  @computed
  ObservableList<StreamTwitch> get streams {
    final shown = _allStreams.where(
      (streamInfo) =>
          !authStore.user.blockedUsers
              .map((blockedUser) => blockedUser.userId)
              .contains(streamInfo.userId) &&
          (_showLabeled || !_labeledIds.contains(streamInfo.userId)),
    );
    // Viewers is Helix's own order: kept as is, so a page loaded while
    // scrolling never reorders the cards above it.
    return (listType == ListType.followed &&
                settingsStore.followedSort != FollowedSort.viewers
            ? sortFollowedStreams(shown, settingsStore.followedSort)
            : shown.toList())
        .asObservable();
  }

  /// All pinned channels (only live streams).
  @computed
  List<dynamic> get allPinnedChannels {
    final blockedUserIds = authStore.user.blockedUsers
        .map((blockedUser) => blockedUser.userId)
        .toSet();

    // Get live pinned streams only
    final pinned = _pinnedStreams.where(
      (stream) => !blockedUserIds.contains(stream.userId),
    );
    final sort = settingsStore.followedSort;
    return sort == FollowedSort.viewers
        ? pinned.toList()
        : sortFollowedStreams(pinned, sort);
  }

  /// The list of offline followed channels with blocked users filtered out
  /// and excluding channels that are currently live or pinned.
  @computed
  ObservableList<FollowedChannel> get offlineChannels {
    final liveChannelIds = streams.map((stream) => stream.userId).toSet();
    final pinnedChannelIds = settingsStore.pinnedChannelIds.toSet();
    final blockedUserIds = authStore.user.blockedUsers
        .map((blockedUser) => blockedUser.userId)
        .toSet();

    return _allOfflineChannels
        .where(
          (channel) =>
              !liveChannelIds.contains(channel.broadcasterId) &&
              !pinnedChannelIds.contains(channel.broadcasterId) &&
              !blockedUserIds.contains(channel.broadcasterId),
        )
        .toList()
        .asObservable();
  }

  /// The categories the viewer follows (Following only; empty when Twitch
  /// does not give them, which hides the section).
  @readonly
  List<FollowedCategory> _followedCategories = const [];

  /// When Twitch last refused the followed categories: not asked again for
  /// a while, so a refusal never turns into a request on every refresh.
  DateTime? _followedCategoriesFailedAt;
  static const _followedCategoriesBackoff = Duration(minutes: 30);

  /// The viewer's running watch streaks by channel id (Following only).
  @readonly
  var _watchStreaks = ObservableMap<String, int>();

  /// When Twitch last refused the streaks (same backoff as the categories).
  DateTime? _watchStreaksFailedAt;

  /// Followed streams with a running hype train, by channel id.
  @readonly
  var _hypeTrains = ObservableMap<String, HtCardStatus>();

  /// The error message to show if any. Will be non-null if there is an error.
  @readonly
  String? _error;

  /// Bumped by [refreshStreams] so a page asked for before it is dropped
  /// (a new language must not get the old one's pages).
  var _streamsGeneration = 0;

  ReactionDisposer? _languageReactionDisposer;
  ReactionDisposer? _sortReactionDisposer;
  ReactionDisposer? _labelsReactionDisposer;

  /// Streams (user ids) left out for a label the viewer hides.
  @readonly
  var _labeledIds = ObservableSet<String>();

  /// The viewer chose to see the streams [_labeledIds] hides, for this list.
  @readonly
  var _showLabeled = false;

  /// How many loaded streams are hidden for their labels (0 once shown).
  @computed
  int get hiddenByLabels => _showLabeled
      ? 0
      : _allStreams.where((s) => _labeledIds.contains(s.userId)).length;

  /// Shows the streams hidden for their labels in this list.
  @action
  void showLabeledStreams() => _showLabeled = true;

  /// Which of [page]'s streams carry a label the viewer hides (none for the
  /// followed list, or when Twitch cannot say).
  Future<Set<String>> _labeledIn(List<StreamTwitch> page) async {
    final hidden = settingsStore.hiddenContentLabels.toSet();
    if (listType == ListType.followed || hidden.isEmpty || page.isEmpty) {
      return const {};
    }
    try {
      final channels = await twitchApi.getChannelsByIds([
        for (final stream in page) stream.userId,
      ]);
      return {
        for (final MapEntry(:key, :value) in channels.entries)
          if (value.contentClassificationLabels.any(hidden.contains)) key,
      };
    } catch (e) {
      // Browsing goes on unfiltered rather than not at all.
      debugPrint('Content labels unavailable: $e');
      return const {};
    }
  }

  ReactionDisposer? _pinnedStreamsReactionDisposer;
  ReactionDisposer? _offlineChannelsExpansionDisposer;
  ReactionDisposer? _followedSortReactionDisposer;

  ListStoreBase({
    required this.authStore,
    required this.settingsStore,
    required this.twitchApi,
    required this.listType,
    this.categoryId,
    this.tag,
    this.directoryService,
    this.followedCategoriesService,
    this.watchStreakService,
    this.scrollController,
    this.hypeTrainService,
    this.sort = StreamSort.viewersHigh,
    this.loadStreams = true,
  }) : assert(listType != ListType.tag || tag != null),
       assert(listType != ListType.tag || directoryService != null) {
    scrollController?.addListener(_onScroll);

    if (listType != ListType.followed && loadStreams) {
      // A new language starts the list over.
      _languageReactionDisposer = reaction(
        (_) => settingsStore.streamLanguage,
        (_) => refreshStreams(),
      );
      // So does a new order.
      _sortReactionDisposer = reaction((_) => sort, (_) => refreshStreams());
      // And so do other hidden labels.
      _labelsReactionDisposer = reaction(
        (_) => settingsStore.hiddenContentLabels,
        (_) => refreshStreams(),
      );
    }

    if (listType == ListType.followed) {
      _pinnedStreamsReactionDisposer = reaction(
        (_) => settingsStore.pinnedChannelIds,
        (_) => getPinnedStreams(),
      );

      getPinnedStreams();
      unawaited(_getFollowedCategories());
      unawaited(_getWatchStreaks());

      // Any order but Helix's own needs every live channel to be right.
      _followedSortReactionDisposer = reaction(
        (_) => settingsStore.followedSort,
        (_) => _loadAllForSort(),
      );

      // Fetch offline channels only when expanded
      _offlineChannelsExpansionDisposer = reaction(
        (_) => isOfflineChannelsExpanded,
        (expanded) {
          if (expanded) {
            // Fetch offline channels when expanded (only if not already loaded)
            if (_allOfflineChannels.isEmpty) {
              getOfflineChannels();
            }
          } else {
            // Clear offline channels when collapsed to save memory
            _allOfflineChannels.clear();
            _offlineChannelsCursor = null;
          }
        },
      );
    }

    if (listType == ListType.category) {
      _getCategoryDetails();
    }

    if (loadStreams) getStreams();
  }

  /// Fetches the streams based on the type and current cursor.
  @action
  Future<void> getStreams() async {
    final generation = _streamsGeneration;
    if (_streamsCursor == null) {
      _pagesHiddenInFull = 0;
      _pagesForSort = 0;
    }
    _isAllStreamsLoading = true;

    try {
      final StreamsTwitch newStreams;
      switch (listType) {
        case ListType.followed:
          newStreams = await twitchApi.getFollowedStreams(
            id: authStore.user.details!.id,
            cursor: _streamsCursor,
          );
          break;
        case ListType.top:
          newStreams = await twitchApi.getTopStreams(
            cursor: _streamsCursor,
            language: streamLanguageOrAll(settingsStore.streamLanguage),
          );
          break;
        case ListType.category:
          final directory = directoryService;
          newStreams = sort == StreamSort.viewersHigh || directory == null
              ? await twitchApi.getStreamsUnderCategory(
                  gameId: categoryId!,
                  cursor: _streamsCursor,
                  language: streamLanguageOrAll(settingsStore.streamLanguage),
                )
              : await directory.getCategoryStreams(
                  gameId: categoryId!,
                  sort: sort,
                  language: streamLanguageOrAll(settingsStore.streamLanguage),
                );
          break;
        case ListType.tag:
          newStreams = await directoryService!.getTagStreams(
            tag: tag!,
            sort: sort,
            language: streamLanguageOrAll(settingsStore.streamLanguage),
          );
          break;
      }

      if (generation != _streamsGeneration) return;
      final labeled = await _labeledIn(newStreams.data);
      if (generation != _streamsGeneration) return;

      if (_streamsCursor == null) {
        _allStreams = newStreams.data.asObservable();
        _labeledIds = labeled.asObservable();
        _showLabeled = false;
      } else {
        _allStreams.addAll(newStreams.data);
        _labeledIds.addAll(labeled);
      }
      _streamsCursor = newStreams.pagination['cursor'];

      _error = null;
    } on SocketException {
      if (generation != _streamsGeneration) return;
      _error = 'Unable to connect to Twitch';
      debugPrint('Streams SocketException: No internet connection');
    } on DirectoryApiException catch (e) {
      if (generation != _streamsGeneration) return;
      _error = listType == ListType.tag
          ? 'Tag streams are unavailable right now'
          : 'Twitch could not sort by ${sort.label}. '
                '${StreamSort.viewersHigh.label} still works.';
      debugPrint('Streams DirectoryApiException: $e');
      // Seen in release too: Twitch probably changed the query.
      Telemetry.log('directory streams failed: $e');
    } on ApiException catch (e) {
      if (generation != _streamsGeneration) return;
      _error = e.message;
      debugPrint('Streams ApiException: $e');
    } catch (e) {
      if (generation != _streamsGeneration) return;
      _error = 'Something went wrong loading streams';
      debugPrint('Streams error: $e');
    }

    _isAllStreamsLoading = false;
    unawaited(_refreshHypeTrains());

    if (generation == _streamsGeneration && _error == null) {
      await _loadAllForSort();
    }

    // Nothing to show when every stream so far was hidden for its labels,
    // and nothing scrolls to ask for more: ask now, a few pages at most.
    if (generation == _streamsGeneration &&
        _error == null &&
        hiddenByLabels > 0 &&
        _streamsCursor != null &&
        _pagesHiddenInFull < _maxPagesHiddenInFull &&
        streams.isEmpty) {
      _pagesHiddenInFull++;
      await getStreams();
    }
  }

  /// Pages asked for at once so Following can be sorted by something
  /// other than viewers (Helix pages by viewers only).
  var _pagesForSort = 0;
  static const _maxPagesForSort = 5;

  /// Loads the followed live channels left on later pages, when the order
  /// needs all of them. Helix gives up to 100 per page, so this is rare.
  Future<void> _loadAllForSort() async {
    if (listType != ListType.followed ||
        settingsStore.followedSort == FollowedSort.viewers ||
        _isAllStreamsLoading ||
        _streamsCursor == null ||
        _pagesForSort >= _maxPagesForSort) {
      return;
    }
    _pagesForSort++;
    await getStreams();
  }

  /// Pages asked for in a row because the ones before were hidden in full.
  var _pagesHiddenInFull = 0;
  static const _maxPagesHiddenInFull = 3;

  /// Which followed streams run a hype train (never throws).
  Future<void> _refreshHypeTrains() async {
    final service = hypeTrainService;
    if (listType != ListType.followed ||
        service == null ||
        !settingsStore.showHypeTrain) {
      if (_hypeTrains.isNotEmpty) runInAction(_hypeTrains.clear);
      return;
    }
    final ids = {
      for (final stream in _allStreams) stream.userId,
      for (final stream in _pinnedStreams) stream.userId,
    }.toList();
    if (ids.isEmpty) return;
    final statuses = await service.getActiveStatuses(ids);
    runInAction(() => _hypeTrains = ObservableMap.of(statuses));
  }

  @action
  Future<void> getPinnedStreams() async {
    if (settingsStore.pinnedChannelIds.isEmpty) {
      _pinnedStreams.clear();
      return;
    }

    _isPinnedStreamsLoading = true;

    try {
      _pinnedStreams = (await twitchApi.getStreamsByIds(
        userIds: settingsStore.pinnedChannelIds,
      )).data.asObservable();

      _error = null;
    } on SocketException {
      _error = 'Unable to connect to Twitch';
      debugPrint('Pinned streams SocketException: No internet connection');
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Pinned streams ApiException: $e');
    } catch (e) {
      _error = 'Something went wrong loading pinned streams';
      debugPrint('Pinned streams error: $e');
    }

    _isPinnedStreamsLoading = false;
  }

  /// Reads the followed categories (never throws).
  Future<void> _getFollowedCategories() async {
    final service = followedCategoriesService;
    final token = authStore.twitchWebToken;
    if (listType != ListType.followed || service == null || token == null) {
      return;
    }
    final failedAt = _followedCategoriesFailedAt;
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _followedCategoriesBackoff) {
      return;
    }
    final categories = await service.getFollowedCategories(authToken: token);
    runInAction(() {
      _followedCategoriesFailedAt = categories == null ? DateTime.now() : null;
      _followedCategories = categories ?? const [];
    });
  }

  /// Reads the running watch streaks (never throws).
  Future<void> _getWatchStreaks() async {
    final service = watchStreakService;
    final token = authStore.twitchWebToken;
    if (listType != ListType.followed || service == null || token == null) {
      return;
    }
    final failedAt = _watchStreaksFailedAt;
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _followedCategoriesBackoff) {
      return;
    }
    final streaks = await service.getStreaks(authToken: token);
    runInAction(() {
      _watchStreaksFailedAt = streaks == null ? DateTime.now() : null;
      _watchStreaks = ObservableMap.of(streaks ?? const {});
    });
  }

  @action
  Future<void> getOfflineChannels() async {
    _isOfflineChannelsLoading = true;

    try {
      final followedChannels = await twitchApi.getFollowedChannels(
        userId: authStore.user.details!.id,
        cursor: _offlineChannelsCursor,
      );

      if (_offlineChannelsCursor == null) {
        _allOfflineChannels = followedChannels.data.asObservable();
      } else {
        _allOfflineChannels.addAll(followedChannels.data);
      }
      _offlineChannelsCursor = followedChannels.pagination['cursor'];

      _error = null;
    } on SocketException {
      _error = 'Unable to connect to Twitch';
      debugPrint('Offline channels SocketException: No internet connection');
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Offline channels ApiException: $e');
    } catch (e) {
      _error = 'Something went wrong loading offline channels';
      debugPrint('Offline channels error: $e');
    }

    _isOfflineChannelsLoading = false;
  }

  /// Resets the cursor and then fetches the streams.
  @action
  Future<void> refreshStreams() async {
    // A new list does not keep the last one's error on screen.
    _error = null;

    if (listType == ListType.followed) {
      await getPinnedStreams();
      // Optional extras on private GQL: a slow gql.twitch.tv must never hold
      // the live list back. Neither throws.
      unawaited(_getFollowedCategories());
      unawaited(_getWatchStreaks());

      // Only refresh offline channels if they are currently expanded
      if (isOfflineChannelsExpanded) {
        _offlineChannelsCursor = null;
        await getOfflineChannels();
      }
    }

    _streamsGeneration++;
    _streamsCursor = null;
    await getStreams();
  }

  @action
  Future<void> _getCategoryDetails() async {
    if (categoryId == null) return;

    _isCategoryDetailsLoading = true;

    try {
      final categoryDetails = await twitchApi.getCategory(gameId: categoryId!);
      _categoryDetails = categoryDetails.data.firstOrNull;
    } catch (e) {
      // The header stays a placeholder; the list says what went wrong.
      debugPrint('Category details error: $e');
    } finally {
      // Never left loading: that would also stop paging.
      _isCategoryDetailsLoading = false;
    }
  }

  /// Checks the last time the streams were refreshed and updates them if it has been more than 5 minutes.
  void checkLastTimeRefreshedAndUpdate() {
    final now = DateTime.now();
    final difference = now.difference(lastTimeRefreshed);

    if (difference.inMinutes >= 5) refreshStreams();

    lastTimeRefreshed = now;
  }

  void _onScroll() {
    final position = scrollController!.position;
    showJumpButton = !(position.atEdge || position.outOfRange);
  }

  /// Stops the reactions and the scroll listener. The [scrollController]
  /// belongs to whoever passed it and is left alone.
  void dispose() {
    _languageReactionDisposer?.call();
    _sortReactionDisposer?.call();
    _labelsReactionDisposer?.call();
    _pinnedStreamsReactionDisposer?.call();
    _offlineChannelsExpansionDisposer?.call();
    _followedSortReactionDisposer?.call();

    scrollController?.removeListener(_onScroll);
  }
}

/// [streams] in [sort] order (a new list; ties keep Helix's order).
List<StreamTwitch> sortFollowedStreams(
  Iterable<StreamTwitch> streams,
  FollowedSort sort,
) {
  final sorted = streams.toList();
  int byViewers(StreamTwitch a, StreamTwitch b) =>
      b.viewerCount.compareTo(a.viewerCount);
  int byName(StreamTwitch a, StreamTwitch b) =>
      a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
  final Comparator<StreamTwitch> compare = switch (sort) {
    FollowedSort.viewers => byViewers,
    FollowedSort.recent => (a, b) {
      final started = (
        DateTime.tryParse(a.startedAt),
        DateTime.tryParse(b.startedAt),
      );
      return switch (started) {
        (final x?, final y?) => y.compareTo(x),
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
      };
    },
    FollowedSort.name => byName,
    FollowedSort.category => (a, b) {
      final x = a.gameName.toLowerCase();
      final y = b.gameName.toLowerCase();
      if (x.isEmpty != y.isEmpty) return x.isEmpty ? 1 : -1;
      final byGame = x.compareTo(y);
      return byGame != 0 ? byGame : byViewers(a, b);
    },
  };
  // A stable sort: List.sort is not guaranteed to be.
  final indexed = sorted.indexed.toList()
    ..sort((a, b) {
      final order = compare(a.$2, b.$2);
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, stream) in indexed) stream];
}

/// The possible types of lists that can be displayed.
///
/// [ListType.followed] is the list of streams that the user is following.
/// [ListType.top] is the list of top streams.
/// [ListType.category] is the list of streams under a category.
/// [ListType.tag] is the list of streams with a tag.
enum ListType { followed, top, category, tag }
