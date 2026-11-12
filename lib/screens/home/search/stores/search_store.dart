import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'search_store.g.dart';

class SearchStore = SearchStoreBase with _$SearchStore;

abstract class SearchStoreBase with Store {
  final AuthStore authStore;

  final TwitchApi twitchApi;

  final textEditingController = TextEditingController();

  final textFieldFocusNode = FocusNode();

  Timer? _debounceTimer;

  ReactionDisposer? _disposeReaction;

  @readonly
  var _searchText = '';

  @readonly
  var _searchHistory = ObservableList<String>();

  @readonly
  var _isSearching = false;

  /// The query the results are for ('' when there is none), so tabs that
  /// load on demand (Videos) can follow it.
  @readonly
  var _lastQuery = '';

  @readonly
  ObservableFuture<List<ChannelQuery>>? _channelFuture;

  @readonly
  ObservableFuture<CategoriesTwitch?>? _categoryFuture;

  @readonly
  List<StreamTwitch> _relatedLives = const [];

  static const relatedLivesCount = 6;

  Future<void> _loadRelatedLives(
    String query,
    Future<CategoriesTwitch?> categories,
    Future<List<ChannelQuery>> channels,
  ) async {
    try {
      final category = (await categories)?.data.firstOrNull;
      if (category == null || _lastQuery != query) return;
      final shownLive = {
        for (final channel in await channels)
          if (channel.isLive) channel.id,
      };
      final streams = await twitchApi.getStreamsUnderCategory(
        gameId: category.id,
      );
      if (_lastQuery != query) return;
      runInAction(
        () => _relatedLives = [
          for (final stream in streams.data)
            if (!shownLive.contains(stream.userId)) stream,
        ].take(relatedLivesCount).toList(),
      );
    } catch (e) {
      debugPrint('Related lives unavailable: $e');
    }
  }

  SearchStoreBase({
    required this.authStore,
    required this.twitchApi,
    Future<List<SearchSuggestion>> Function(String fragment)? suggest,
  }) : _suggest = suggest {
    init();
  }

  final Future<List<SearchSuggestion>> Function(String fragment)? _suggest;

  Timer? _suggestTimer;

  static const suggestDelay = Duration(milliseconds: 150);

  @readonly
  List<SearchSuggestion> _suggestions = const [];

  List<SearchSuggestion> _fromHistory(String query) {
    final lower = query.toLowerCase();
    return [
      for (final past in _searchHistory)
        if (past.toLowerCase().startsWith(lower) && past.toLowerCase() != lower)
          SearchSuggestion(text: past),
    ];
  }

  void _updateSuggestions(String query) {
    _suggestTimer?.cancel();
    if (query.trim().isEmpty) {
      _suggestions = const [];
      return;
    }
    final local = _fromHistory(query);
    _suggestions = local.take(TwitchDirectoryService.maxSuggestions).toList();
    final suggest = _suggest;
    if (suggest == null) return;
    _suggestTimer = Timer(suggestDelay, () async {
      List<SearchSuggestion> remote;
      try {
        remote = await suggest(query);
      } catch (e) {
        debugPrint('Search suggestions unavailable: $e');
        return;
      }
      if (textEditingController.text != query) return;
      runInAction(
        () => _suggestions = {
          ...remote,
          ...local,
        }.take(TwitchDirectoryService.maxSuggestions).toList(),
      );
    });
  }

  @action
  void clearSuggestions() {
    _suggestTimer?.cancel();
    _suggestions = const [];
  }

  @action
  Future<void> init() async {
    // Retrieve the instance that will allow us to retrieve local search history.
    final prefs = await SharedPreferences.getInstance();

    // Retrieve the search history from local storage. If it doesn't exist, use an empty list.
    _searchHistory =
        prefs.getStringList('search_history')?.asObservable() ??
        ObservableList<String>();

    // Create a reaction that will limit the history to 8 entries and update it to local storage automatically.
    _disposeReaction = autorun((_) {
      if (_searchHistory.length > 8) _searchHistory.removeLast();
      prefs.setStringList('search_history', _searchHistory);
    });

    // Add a listener to update the cancel button visibility whenever the text changes.
    textEditingController.addListener(
      () => _searchText = textEditingController.text,
    );
  }

  /// Debounced handler for search-as-you-type.
  @action
  void onSearchTextChanged(String query) {
    _debounceTimer?.cancel();
    _updateSuggestions(query);

    if (query.isEmpty) {
      _isSearching = false;
      _channelFuture = null;
      _categoryFuture = null;
      _relatedLives = const [];
      _lastQuery = '';
      return;
    }

    // Show loading state immediately for responsive feedback.
    _isSearching = true;

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      runInAction(() => _performSearch(query));
    });
  }

  @action
  void searchFor(String query) {
    textEditingController.text = query;
    _searchText = query;
    handleQuery(query);
  }

  /// Obtain the channels and categories that match the provided [query].
  @action
  void handleQuery(String query) {
    if (query.isEmpty) return;

    // Cancel any pending debounce since we're searching immediately.
    _debounceTimer?.cancel();
    clearSuggestions();

    _performSearch(query);
  }

  /// Performs the actual search API calls and saves the query to history.
  @action
  void _performSearch(String query) {
    // Futures are now pending, so isSearching can be cleared.
    _isSearching = false;
    _lastQuery = query;
    _relatedLives = const [];

    // Move the query to the most recent result (top of the stack).
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);

    // Fetch the matching channels, sort it by live status, and then set it.
    _channelFuture = twitchApi
        .searchChannels(query: query)
        .then(
          (channels) => [
            ...channels.where((c) => c.isLive),
            ...channels.where((c) => !c.isLive),
          ],
        )
        .asObservable();

    // Fetch and set the categories that match the query.
    _categoryFuture = twitchApi.searchCategories(query: query).then((
      categories,
    ) {
      // Move exact matches to the first result
      final matchingIndex = categories.data.indexWhere(
        (c) => c.name.toLowerCase() == query.toLowerCase(),
      );
      if (matchingIndex >= 1) {
        final matchingCategory = categories.data.removeAt(matchingIndex);
        categories.data.insert(0, matchingCategory);
      }
      return categories;
    }).asObservable();

    unawaited(_loadRelatedLives(query, _categoryFuture!, _channelFuture!));
  }

  /// Forgets one past search.
  @action
  void removeFromHistory(String query) => _searchHistory.remove(query);

  /// Find a specific channel provided the [query].
  /// This is used for channels that may not show up in the search results.
  Future<Channel> searchChannel(String query) async {
    final user = await twitchApi.getUser(userLogin: query);
    return await twitchApi.getChannel(userId: user.id);
  }

  void dispose() {
    _disposeReaction?.call();
    _debounceTimer?.cancel();
    _suggestTimer?.cancel();
    textEditingController.dispose();
    textFieldFocusNode.dispose();
  }
}
