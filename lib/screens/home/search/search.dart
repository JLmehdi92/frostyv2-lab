import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/screens/home/search/search_results_categories.dart';
import 'package:onset/screens/home/search/search_results_channels.dart';
import 'package:onset/screens/home/search/search_results_videos.dart';
import 'package:onset/screens/home/search/search_store.dart';
import 'package:onset/screens/home/search/search_videos_store.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/settled_blur.dart';
import 'package:provider/provider.dart';

/// What search keeps between opens of [SearchScreen], as the Search tab
/// did before the shell: the query, its results, the result tab, the
/// videos found.
class SearchSession {
  SearchSession({required AuthStore authStore, required TwitchApi twitchApi})
    : store = SearchStore(authStore: authStore, twitchApi: twitchApi);

  final SearchStore store;

  /// Made the first time videos are searched (the Videos tab, the tablet's
  /// Top column).
  SearchVideosStore? videos;

  /// The result tab last open.
  var tab = 0;

  /// Where the results were scrolled when search last closed (a page's own
  /// scroll is not kept from one push to the next).
  var scrollOffset = 0.0;

  void dispose() => store.dispose();
}

/// The scroll of a search page opened on a [SearchSession]: its first list
/// opens where the session's last one was, and every list it lets go of
/// tells the session where it was. A list made later on the same page (a
/// new query, another tab) starts at the top, as before.
class _SessionScrollController extends ScrollController {
  _SessionScrollController(this.session);

  final SearchSession session;
  var _restored = false;

  @override
  double get initialScrollOffset => _restored ? 0 : session.scrollOffset;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    final position = super.createScrollPosition(physics, context, oldPosition);
    _restored = true;
    return position;
  }

  @override
  void detach(ScrollPosition position) {
    if (position.hasPixels) session.scrollOffset = position.pixels;
    super.detach(position);
  }
}

/// Search, opened from the shell (the header's search button, Browse's
/// search field, the tablet's top bar).
class SearchScreen extends StatefulWidget {
  static const routeName = '/search';

  /// The search kept between opens (the shell's), or null for a new one.
  final SearchSession? session;

  const SearchScreen({super.key, this.session});

  static Future<void> open(BuildContext context, {SearchSession? session}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => SearchScreen(session: session),
        ),
      );

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// Kept between opens through the session, when there is one.
  late final _scrollController = switch (widget.session) {
    final session? => _SessionScrollController(session),
    null => ScrollController(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No app bar to set the system bars: the theme's, as on every page.
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        body: Search(
          scrollController: _scrollController,
          session: widget.session,
          // A search kept from before shows its results, not the keyboard.
          autofocus: widget.session?.store.searchText.isEmpty ?? true,
          onBack: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

/// Search (boards Recherche and RechercheTablette): the field, the past
/// searches, then the results under Top, Channels, Categories and Videos.
class Search extends StatefulWidget {
  // The scroll controller for handling scroll to top functionality.
  final ScrollController scrollController;

  /// Opens the keyboard at once (search was asked for).
  final bool autofocus;

  /// A back button before the field, when search is its own page.
  final VoidCallback? onBack;

  /// What the search keeps between opens; null: its own, let go with it.
  final SearchSession? session;

  const Search({
    super.key,
    required this.scrollController,
    this.autofocus = false,
    this.onBack,
    this.session,
  });

  @override
  State<Search> createState() => _SearchState();
}

/// The result tabs, like the official app's search.
enum _SearchTab {
  top('Top'),
  channels('Channels'),
  categories('Categories'),
  videos('Videos');

  const _SearchTab(this.label);

  final String label;
}

/// The header's rows (boards: the field row, then the result tabs).
abstract final class _Metrics {
  static double fieldRow(bool large) => large ? 68 : 64;
  static double tabsRow(bool large) => large ? 46 : 44;
}

class _SearchState extends State<Search> {
  /// Given (kept between opens), or this search's own.
  late final _session =
      widget.session ??
      SearchSession(
        authStore: context.read<AuthStore>(),
        twitchApi: context.read<TwitchApi>(),
      );

  SearchStore get _searchStore => _session.store;

  /// Made the first time videos are searched.
  SearchVideosStore get _videosStore => _session.videos ??= SearchVideosStore(
    vodService: context.read<TwitchVodService>(),
  );

  /// The videos for the tablet's Top column: none without the video
  /// service (the column is left out).
  SearchVideosStore? get _topVideos =>
      _session.videos ??
      (context.read<TwitchVodService?>() == null ? null : _videosStore);

  /// The videos of the open tab, if it shows some.
  SearchVideosStore? get _shownVideos => switch (_tab) {
    _SearchTab.videos => _videosStore,
    _SearchTab.top when _videosOnTop => _topVideos,
    _ => null,
  };

  late var _tab = _SearchTab.values[_session.tab];

  /// The tablet's Top has a Videos column (an approved addition): videos
  /// are searched there too.
  var _videosOnTop = false;

  ReactionDisposer? _disposeQueryReaction;

  @override
  void initState() {
    super.initState();
    // Videos follow each new query while a tab shows them.
    _disposeQueryReaction = reaction((_) => _searchStore.lastQuery, (
      String query,
    ) {
      _shownVideos?.search(query);
    });
  }

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final large = context.isLargeScreen;
    final changed = large != _videosOnTop;
    _videosOnTop = large;
    // A kept search reopening on a tab with videos (or a window grown into
    // a tablet's): a query may have landed while they were not shown (the
    // debounce lives in the session, the reaction above in the page), so
    // the videos catch up with it.
    if (!_started || changed) {
      _started = true;
      final videos = _shownVideos;
      if (videos != null) unawaited(videos.search(_searchStore.lastQuery));
    }
  }

  void _selectTab(_SearchTab tab) {
    if (tab == _tab) {
      _toTop(animate: true);
      return;
    }
    _session.tab = tab.index;
    setState(() => _tab = tab);
    _toTop();
    _shownVideos?.search(_searchStore.lastQuery);
  }

  void _toTop({bool animate = false}) {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    if (animate && !reduceMotionOf(context)) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: OnsetMotion.standard,
      );
    } else {
      controller.jumpTo(0);
    }
  }

  void _useHistory(String searchTerm) {
    final controller = _searchStore.textEditingController;
    controller.text = searchTerm;
    _searchStore.handleQuery(searchTerm);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _clearField() {
    if (_searchStore.searchText.isEmpty) {
      _searchStore.textFieldFocusNode.unfocus();
    }
    _searchStore.textEditingController.clear();
    _searchStore.onSearchTextChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final large = context.isLargeScreen;
    final padding = MediaQuery.paddingOf(context);
    return Observer(
      builder: (context) {
        final hasQuery = _searchStore.searchText.isNotEmpty;
        final headerHeight =
            padding.top +
            _Metrics.fieldRow(large) +
            (hasQuery ? _Metrics.tabsRow(large) : 0);
        return Stack(
          children: [
            Positioned.fill(
              child: _body(
                context,
                large: large,
                hasQuery: hasQuery,
                top: headerHeight,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _header(context, large: large, hasQuery: hasQuery),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Header.

  Widget _header(
    BuildContext context, {
    required bool large,
    required bool hasQuery,
  }) {
    final colors = FeedColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final gutter = large ? OnsetSpacing.gutterTablet : 16.0;
    final onBack = widget.onBack;
    final tabs = ShellTabs(
      labels: [for (final tab in _SearchTab.values) tab.label],
      index: _tab.index,
      onSelect: (i) => _selectTab(_SearchTab.values[i]),
      height: _Metrics.tabsRow(large),
      fontSize: large ? 16 : 15,
      gap: large ? 28 : 22,
      bottomPadding: large ? 13 : 12,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      activeColor: colors.text,
      idleColor: colors.tertiary,
      indicatorColor: context.onsetColors.live,
    );
    return ClipRect(
      // The phone's glass, once the page is in place (search opens over
      // the Live feed's preview too); the tablet's bar is opaque.
      child: SettledBlur(
        enabled: !large,
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: large ? ground : ground.withValues(alpha: 0.74),
            border: Border(
              bottom: BorderSide(
                color: !large || hasQuery ? colors.hairline : ground,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: padding.top,
              left: padding.left,
              right: padding.right,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _Metrics.fieldRow(large),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: onBack == null ? gutter : (large ? 20 : 4),
                      right: gutter,
                    ),
                    child: Row(
                      spacing: large ? 8 : 4,
                      children: [
                        if (onBack != null)
                          IconButton(
                            tooltip: 'Back',
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              size: 26,
                              color: colors.text,
                            ),
                            onPressed: onBack,
                          ),
                        Expanded(
                          child: _SearchField(
                            store: _searchStore,
                            autofocus: widget.autofocus,
                            large: large,
                            onClear: _clearField,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 260),
                  ),
                  curve: OnsetMotion.standard,
                  alignment: Alignment.topCenter,
                  child: hasQuery ? tabs : const SizedBox(width: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Body.

  Widget _body(
    BuildContext context, {
    required bool large,
    required bool hasQuery,
    required double top,
  }) {
    final padding = MediaQuery.paddingOf(context);
    final List<Widget> slivers;
    final String phase;
    if (!hasQuery) {
      phase = 'history';
      slivers = _historySlivers(context, large: large);
    } else {
      phase = 'results-${_searchStore.lastQuery}-${_tab.name}';
      slivers = large ? _tabletResults(context) : _phoneResults(context);
    }
    return OnsetScrollbar(
      controller: widget.scrollController,
      padding: EdgeInsets.only(top: top, bottom: padding.bottom),
      child: StaggerScope(
        key: ValueKey(phase),
        child: CustomScrollView(
          controller: widget.scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: top)),
            ...slivers,
            SliverToBoxAdapter(
              child: SizedBox(height: padding.bottom + (large ? 40 : 24)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _historySlivers(BuildContext context, {required bool large}) {
    final history = _searchStore.searchHistory;
    if (history.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _NoHistory(large: large),
        ),
      ];
    }
    final list = _HistoryList(
      history: history.toList(),
      onUse: _useHistory,
      onRemove: _searchStore.removeFromHistory,
      onClear: _searchStore.searchHistory.clear,
    );
    if (!large) {
      return [
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverToBoxAdapter(child: list),
        ),
      ];
    }
    final colors = FeedColors.of(context);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          OnsetSpacing.gutterTablet + MediaQuery.paddingOf(context).left,
          28,
          OnsetSpacing.gutterTablet + MediaQuery.paddingOf(context).right,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.hairline,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  // The card is inset already: its rows are not again.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: true,
                    removeRight: true,
                    child: list,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// "Channels" or "Categories" over a part of Top, with "See all".
  Widget _sectionTitle(
    String title,
    _SearchTab tab, {
    required double gutter,
    double top = 16,
  }) {
    // A phone's titles keep clear of the window's side insets; a tablet's
    // column is inset already.
    final window = gutter == 0
        ? EdgeInsets.zero
        : MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter + window.left,
        top,
        math.max(0, gutter - 4) + window.right,
        8,
      ),
      child: _SectionTitle(title: title, onSeeAll: () => _selectTab(tab)),
    );
  }

  List<Widget> _phoneResults(BuildContext context) {
    final query = _searchStore.searchText;
    Widget channels({int? limit}) => SearchResultsChannels(
      searchStore: _searchStore,
      query: query,
      limit: limit,
    );
    Widget categories({int? limit}) =>
        SearchResultsCategories(searchStore: _searchStore, limit: limit);
    return switch (_tab) {
      _SearchTab.top => [
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Channels',
            _SearchTab.channels,
            gutter: OnsetSpacing.gutterPhone,
          ),
        ),
        SliverToBoxAdapter(child: channels(limit: 5)),
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Categories',
            _SearchTab.categories,
            gutter: OnsetSpacing.gutterPhone,
            top: 20,
          ),
        ),
        SliverToBoxAdapter(child: categories(limit: 4)),
      ],
      _SearchTab.channels => [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: channels()),
      ],
      _SearchTab.categories => [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: categories()),
      ],
      _SearchTab.videos => [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SearchResultsVideos(store: _videosStore),
      ],
    };
  }

  List<Widget> _tabletResults(BuildContext context) {
    const gutter = OnsetSpacing.gutterTablet;
    final query = _searchStore.searchText;
    final media = MediaQuery.of(context);
    final width = media.size.width - media.padding.horizontal - 2 * gutter;
    // The page's gutter and the window's side insets around the results,
    // which then pad themselves with none.
    Widget padded(Widget child, {double top = 20}) => SliverPadding(
      padding: EdgeInsets.fromLTRB(
        gutter + media.padding.left,
        top,
        gutter + media.padding.right,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeRight: true,
          child: child,
        ),
      ),
    );
    switch (_tab) {
      case _SearchTab.top:
        final channels = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Channels', _SearchTab.channels, gutter: 0, top: 0),
            SearchResultsChannels(
              searchStore: _searchStore,
              query: query,
              limit: 5,
              large: true,
              gutter: 0,
            ),
          ],
        );
        final categories = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(
              'Categories',
              _SearchTab.categories,
              gutter: 0,
              top: 0,
            ),
            SearchResultsCategories(
              searchStore: _searchStore,
              limit: 4,
              columns: 2,
            ),
          ],
        );
        final topVideos = _topVideos;
        final videos = topVideos == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Videos', _SearchTab.videos, gutter: 0, top: 0),
                  SearchVideosColumn(store: topVideos),
                ],
              );
        // Three columns where they fit (landscape, board); otherwise the
        // channels and categories side by side, the videos under them.
        final Widget top = width >= 400 + 340 + 2 * 36 + 300
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 400, child: channels),
                  const SizedBox(width: 36),
                  SizedBox(width: 340, child: categories),
                  const SizedBox(width: 36),
                  Expanded(child: videos),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 28,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 28,
                    children: [
                      Expanded(flex: 10, child: channels),
                      Expanded(flex: 9, child: categories),
                    ],
                  ),
                  videos,
                ],
              );
        return [padded(top)];
      case _SearchTab.channels:
        return [
          padded(
            SearchResultsChannels(
              searchStore: _searchStore,
              query: query,
              large: true,
              gutter: 0,
              columns: math.max(1, math.min(3, (width + 24) ~/ (320 + 24))),
              goTo: GoToStyle.pill,
            ),
          ),
        ];
      case _SearchTab.categories:
        return [
          padded(
            SearchResultsCategories(
              searchStore: _searchStore,
              columns: math.max(3, math.min(8, (width + 18) ~/ (170 + 18))),
              gap: 18,
              rowGap: 22,
            ),
          ),
        ];
      case _SearchTab.videos:
        return [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SearchResultsVideos(store: _videosStore),
        ];
    }
  }

  @override
  void dispose() {
    _disposeQueryReaction?.call();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }
}

/// The search field (boards: a pill on the surface, ringed in the signal
/// colour while typing; "Clear" once something is typed, "Cancel" to put
/// the keyboard away).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.store,
    required this.autofocus,
    required this.large,
    required this.onClear,
  });

  final SearchStore store;
  final bool autofocus;
  final bool large;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final accent = context.onsetColors.live;
    final focus = store.textFieldFocusNode;
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) {
        final focused = focus.hasFocus;
        final hasText = store.searchText.isNotEmpty;
        final label = hasText ? 'Clear' : 'Cancel';
        final Widget? clear = !(focused || hasText)
            ? null
            : large
            ? Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: Semantics(
                  button: true,
                  label: label,
                  onTap: onClear,
                  excludeSemantics: true,
                  child: PressScale(
                    child: Material(
                      color: colors.raised,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onClear,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: colors.body,
                              ),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : IconButton(
                tooltip: label,
                onPressed: onClear,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(backgroundColor: colors.raised),
                icon: Icon(Icons.close_rounded, size: 16, color: colors.body),
              );
        return AnimatedContainer(
          duration: motionDuration(context, const Duration(milliseconds: 200)),
          curve: OnsetMotion.standard,
          height: large ? 52 : 44,
          padding: EdgeInsets.only(left: large ? 18 : 14, right: large ? 6 : 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
            border: Border.all(
              color: focused ? accent : colors.pillBorder,
              width: focused ? 1 : OnsetTokens.hairlineWidth,
            ),
          ),
          child: Row(
            spacing: large ? 10 : 8,
            children: [
              Icon(
                Icons.search_rounded,
                size: large ? 20 : 18,
                color: colors.secondary,
              ),
              Expanded(
                child: TextField(
                  controller: store.textEditingController,
                  focusNode: focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofocus: autofocus,
                  textInputAction: TextInputAction.search,
                  onChanged: store.onSearchTextChanged,
                  onSubmitted: store.handleQuery,
                  cursorColor: accent,
                  style: TextStyle(
                    fontSize: large ? 17 : 15,
                    color: colors.text,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Search channels, categories or videos',
                    hintMaxLines: 1,
                    hintStyle: TextStyle(
                      fontSize: large ? 17 : 15,
                      color: colors.tertiary,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              ?clear,
            ],
          ),
        );
      },
    );
  }
}

/// "Channels" and "See all", over a part of Top.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: OnsetTokens.displayFamily,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.015 * 17,
                color: colors.text,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 32),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: colors.secondary,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Semantics(
            label: 'See all $title',
            excludeSemantics: true,
            child: const Text('See all'),
          ),
        ),
      ],
    );
  }
}

/// The past searches (8 at most): one tap searches again, the cross forgets
/// one, "Clear" forgets them all.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.onUse,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onUse;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 16 + padding.left,
            right: 4 + padding.right,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'History',
                    style: TextStyle(
                      fontFamily: OnsetTokens.displayFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.015 * 17,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: colors.secondary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        for (var i = 0; i < history.length; i++)
          StaggeredEntrance(
            key: ValueKey(history[i]),
            index: i,
            offset: 6,
            child: Padding(
              padding: EdgeInsets.only(right: 4 + padding.right),
              child: Row(
                children: [
                  Expanded(
                    child: PressScale(
                      child: InkWell(
                        onTap: () => onUse(history[i]),
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16 + padding.left),
                            child: Row(
                              spacing: 14,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                  color: colors.tertiary,
                                ),
                                Expanded(
                                  child: Text(
                                    history[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${history[i]} from history',
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.tertiary,
                    ),
                    onPressed: () => onRemove(history[i]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// No past search yet.
class _NoHistory extends StatelessWidget {
  const _NoHistory({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(
              Icons.history_rounded,
              size: large ? 30 : 28,
              color: colors.tertiary,
            ),
            Text(
              'No recent searches',
              style: TextStyle(
                fontSize: large ? 15 : 14,
                color: colors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
