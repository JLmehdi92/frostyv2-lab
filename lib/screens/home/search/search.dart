import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/home/search/search_results_categories.dart';
import 'package:frosty/screens/home/search/search_results_channels.dart';
import 'package:frosty/screens/home/search/search_results_videos.dart';
import 'package:frosty/screens/home/search/search_store.dart';
import 'package:frosty/screens/home/search/search_videos_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:mobx/mobx.dart';
import 'package:provider/provider.dart';

/// The search section that contians search history and search results for channels and categories.
class Search extends StatefulWidget {
  // The scroll controller for handling scroll to top functionality.
  final ScrollController scrollController;

  const Search({super.key, required this.scrollController});

  @override
  State<Search> createState() => _SearchState();
}

// Constants for consistent sizing
const double _kSearchBarHeight = 80.0;

/// The result tabs, like the official app's search.
enum _SearchTab {
  top('Top'),
  channels('Channels'),
  categories('Categories'),
  videos('Videos');

  const _SearchTab(this.label);

  final String label;
}

class _SearchState extends State<Search> with SingleTickerProviderStateMixin {
  late final _searchStore = SearchStore(
    authStore: context.read<AuthStore>(),
    twitchApi: context.read<TwitchApi>(),
  );

  late final _tabController = TabController(
    length: _SearchTab.values.length,
    vsync: this,
  );

  /// Made the first time the Videos tab is opened.
  late final _videosStore = SearchVideosStore(
    vodService: context.read<TwitchVodService>(),
  );

  var _tab = _SearchTab.top;

  ReactionDisposer? _disposeQueryReaction;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    // The Videos tab follows each new query while it is open.
    _disposeQueryReaction = reaction((_) => _searchStore.lastQuery, (
      String query,
    ) {
      if (_tab == _SearchTab.videos) _videosStore.search(query);
    });
  }

  void _onTabChanged() {
    final tab = _SearchTab.values[_tabController.index];
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (widget.scrollController.hasClients) {
      widget.scrollController.jumpTo(0);
    }
    if (tab == _SearchTab.videos) {
      _videosStore.search(_searchStore.lastQuery);
    }
  }

  /// The results of the open tab.
  List<Widget> _resultSlivers(BuildContext context) {
    Widget header(String title, {bool first = false}) => SliverToBoxAdapter(
      child: Builder(
        builder: (context) => SectionHeader(
          title,
          isFirst: first,
          padding: EdgeInsets.fromLTRB(
            16 + MediaQuery.of(context).padding.left,
            first ? 16 : 8,
            16 + MediaQuery.of(context).padding.right,
            8,
          ),
        ),
      ),
    );

    final channels = SearchResultsChannels(
      searchStore: _searchStore,
      query: _searchStore.searchText,
    );
    final categories = SearchResultsCategories(searchStore: _searchStore);
    return switch (_tab) {
      _SearchTab.top => [
        header('Channels', first: true),
        channels,
        header('Categories'),
        categories,
      ],
      _SearchTab.channels => [channels],
      _SearchTab.categories => [categories],
      _SearchTab.videos => [SearchResultsVideos(store: _videosStore)],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content behind the search bar
        Positioned.fill(
          child: Observer(
            builder: (context) {
              if (_searchStore.searchText.isEmpty) {
                if (_searchStore.searchHistory.isEmpty) {
                  return CustomScrollView(
                    controller: widget.scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).padding.top +
                              _kSearchBarHeight,
                        ),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom,
                          ),
                          child: const AlertMessage(
                            message: 'No recent searches',
                            vertical: true,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return FrostyScrollbar(
                  controller: widget.scrollController,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + _kSearchBarHeight,
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  child: ListView(
                    controller: widget.scrollController,
                    padding: EdgeInsets.only(
                      top:
                          MediaQuery.of(context).padding.top +
                          _kSearchBarHeight,
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16 + MediaQuery.of(context).padding.left,
                          right: 4 + MediaQuery.of(context).padding.right,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionHeader(
                              'History',
                              padding: EdgeInsets.zero,
                              isFirst: true,
                            ),
                            TextButton(
                              onPressed: _searchStore.searchHistory.clear,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                      ..._searchStore.searchHistory.mapIndexed(
                        (index, searchTerm) => ListTile(
                          leading: const Icon(Icons.history_rounded),
                          title: Text(searchTerm),
                          trailing: IconButton(
                            tooltip: 'Remove $searchTerm from history',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                _searchStore.removeFromHistory(searchTerm),
                          ),
                          onTap: () {
                            _searchStore.textEditingController.text =
                                searchTerm;
                            _searchStore.handleQuery(searchTerm);
                            _searchStore.textEditingController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _searchStore
                                        .textEditingController
                                        .text
                                        .length,
                                  ),
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
              return FrostyScrollbar(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.of(context).padding.top +
                      _kSearchBarHeight +
                      kTextTabBarHeight,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: CustomScrollView(
                  controller: widget.scrollController,
                  slivers: [
                    // Add padding for app bar, search bar and tabs
                    const _SearchTopPadding(),
                    ..._resultSlivers(context),
                    // Add padding for bottom navigation bar
                    const SliverBottomPadding(),
                  ],
                ),
              );
            },
          ),
        ),
        // Blurred search bar on top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: BlurredContainer(
            gradientDirection: GradientDirection.up,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: MediaQuery.of(context).padding.left,
              right: MediaQuery.of(context).padding.right,
            ),
            child: Observer(
              builder: (context) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchStore.textEditingController,
                        focusNode: _searchStore.textFieldFocusNode,
                        autocorrect: false,
                        onChanged: _searchStore.onSearchTextChanged,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search channels, categories or videos',
                          suffixIcon:
                              _searchStore.textFieldFocusNode.hasFocus ||
                                  _searchStore.searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: _searchStore.searchText.isEmpty
                                      ? 'Cancel'
                                      : 'Clear',
                                  onPressed: () {
                                    if (_searchStore.searchText.isEmpty) {
                                      _searchStore.textFieldFocusNode.unfocus();
                                    }
                                    _searchStore.textEditingController.clear();
                                    _searchStore.onSearchTextChanged('');
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: _searchStore.handleQuery,
                      ),
                    ),
                    if (_searchStore.searchText.isNotEmpty)
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final tab in _SearchTab.values)
                            Tab(text: tab.label),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _disposeQueryReaction?.call();
    _tabController.dispose();
    _searchStore.dispose();
    super.dispose();
  }
}

/// Room for the search bar and the result tabs above the results.
class _SearchTopPadding extends StatelessWidget {
  const _SearchTopPadding();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height:
            MediaQuery.of(context).padding.top +
            _kSearchBarHeight +
            kTextTabBarHeight,
      ),
    );
  }
}
