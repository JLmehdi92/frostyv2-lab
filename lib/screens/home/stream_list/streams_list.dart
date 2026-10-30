import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/apis/twitch_followed_categories_service.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/continue_watching/continue_watching.dart';
import 'package:onset/screens/home/continue_watching/stores/continue_watching_store.dart';
import 'package:onset/screens/home/followed_videos/followed_videos_screen.dart';
import 'package:onset/screens/home/stream_list/expandable_section_header.dart';
import 'package:onset/screens/home/stream_list/followed_categories_section.dart';
import 'package:onset/screens/home/stream_list/large_stream_card.dart';
import 'package:onset/screens/home/stream_list/offline_channel_card.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_sort_button.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/scroll_to_top_button.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:onset/widgets/state_views.dart';
import 'package:provider/provider.dart';

/// A widget that displays a list of followed or top streams based on the
/// provided [listType]. For a widget that displays the top streams under a
/// category, refer to [CategoryStreams].
///
/// Following (boards Accueil and TabletteAccueil) leads with "Continue
/// watching" and the hero live card, then "Live now" with its order, the
/// pinned channels, the others, the followed videos, the followed
/// categories and the offline channels. On a tablet the hero shares its row
/// with the shelf and the categories, and the live channels are a grid.
class StreamsList extends StatefulWidget {
  /// The type of list to display.
  final ListType listType;

  final String? categoryId;

  /// The tag of a [ListType.tag] list.
  final String? tag;

  /// The order of a category or tag list.
  final StreamSort sort;

  /// The scroll controller to use for scroll to top functionality.
  final ScrollController? scrollController;

  final bool showJumpButton;

  /// Room above the list for a fixed header drawn over it (the tag page's).
  final double topInset;

  /// Slivers before the list, in every state (loading, empty, error): a
  /// header that scrolls with it (the category page's, a section title).
  final List<Widget> leadingSlivers;

  /// The sides of a tablet grid (top, category and tag lists), and the
  /// narrowest a tile may get (more columns fit a narrower one).
  final double gridGutter;
  final double tileMinWidth;

  const StreamsList({
    super.key,
    required this.listType,
    this.categoryId,
    this.tag,
    this.sort = StreamSort.viewersHigh,
    this.scrollController,
    this.showJumpButton = false,
    this.topInset = 0,
    this.leadingSlivers = const [],
    this.gridGutter = OnsetSpacing.gutterTablet,
    this.tileMinWidth = 240,
  });

  @override
  State<StreamsList> createState() => _StreamsListState();
}

class _StreamsListState extends State<StreamsList>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final ListStore _listStore;
  ScrollController? _scrollController;

  /// Following's "Continue watching" (null elsewhere, or without the VOD
  /// service).
  ContinueWatchingStore? _continueWatching;

  bool get _following => widget.listType == ListType.followed;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.scrollController == null && widget.showJumpButton) {
      _scrollController = ScrollController();
    }

    _listStore = ListStore(
      authStore: context.read<AuthStore>(),
      settingsStore: context.read<SettingsStore>(),
      twitchApi: context.read<TwitchApi>(),
      listType: widget.listType,
      categoryId: widget.categoryId,
      tag: widget.tag,
      sort: widget.sort,
      directoryService:
          widget.listType == ListType.category ||
              widget.listType == ListType.tag
          ? context.read<TwitchDirectoryService>()
          : null,
      scrollController: widget.scrollController ?? _scrollController,
      hypeTrainService: _following
          ? context.read<TwitchHypeTrainService>()
          : null,
      followedCategoriesService: _following
          ? context.read<TwitchFollowedCategoriesService?>()
          : null,
      watchStreakService: _following
          ? context.read<TwitchWatchStreakService?>()
          : null,
    );

    if (_following) {
      final vods = context.read<TwitchVodService?>();
      if (vods != null) {
        _continueWatching = ContinueWatchingStore(vodService: vods);
        unawaited(_continueWatching!.load());
      }
    }
  }

  @override
  void didUpdateWidget(StreamsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sort != oldWidget.sort) _listStore.sort = widget.sort;
  }

  @override
  void dispose() {
    _listStore.dispose();
    _continueWatching?.dispose();
    _scrollController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _checkRefresh();
    }
  }

  /// Refreshes the list (and the shelf) when it is 5 minutes old.
  void _checkRefresh() {
    final stale =
        DateTime.now().difference(_listStore.lastTimeRefreshed).inMinutes >= 5;
    _listStore.checkLastTimeRefreshedAndUpdate();
    if (stale) unawaited(_continueWatching?.load());
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _listStore.refreshStreams(),
      if (_continueWatching case final shelf?) shelf.load(),
    ]);
    if (!mounted) return;
    final error = _listStore.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AlertMessage(message: error, centered: false)),
      );
    }
  }

  /// "Try again" (approved addition): the same as pulling to refresh.
  void _retry() => unawaited(_refresh());

  double get _extraTopPadding => widget.topInset;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _checkRefresh();

    final topPadding = MediaQuery.paddingOf(context).top + _extraTopPadding;

    return RefreshIndicator.adaptive(
      edgeOffset: topPadding,
      onRefresh: _refresh,
      child: Observer(builder: _body),
    );
  }

  Widget _body(BuildContext context) {
    final settingsStore = context.watch<SettingsStore>();
    final streams = _listStore.streams;
    final error = _listStore.error;

    if (streams.isEmpty && _listStore.isLoading && error == null) {
      return _staggered(
        'loading',
        CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverTopPadding(extraTopPadding: _extraTopPadding),
            ...widget.leadingSlivers,
            ..._skeleton(context, settingsStore),
            const SliverBottomPadding(),
          ],
        ),
      );
    }

    Widget? status;
    if (error != null) {
      status = FeedStatusView.error(message: error, onRetry: _retry);
    } else if (streams.isEmpty) {
      status = _listStore.hiddenByLabels > 0
          ? FeedStatusView(
              message: 'Every stream here has a label you hide',
              icon: Icons.visibility_off_outlined,
              action: 'Show them',
              onAction: _listStore.showLabeledStreams,
            )
          : FeedStatusView.empty(
              message: switch (widget.listType) {
                ListType.followed => 'No followed streams',
                ListType.top => 'No top streams',
                ListType.category || ListType.tag => 'No live streams',
              },
            );
    }

    if (status != null) {
      return _staggered(
        'status',
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverTopPadding(extraTopPadding: _extraTopPadding),
            ...widget.leadingSlivers,
            // Past videos, videos to resume and the followed categories are
            // worth a look most when nobody is live, and they load on their
            // own: they stay when the live list failed.
            if (_following) ...[
              const SliverToBoxAdapter(
                child: StaggeredEntrance(index: 0, child: FollowedVideosTile()),
              ),
              if (_continueWatching case final shelf?)
                SliverToBoxAdapter(
                  child: StaggeredEntrance(
                    index: 1,
                    child: ContinueWatchingShelf(store: shelf),
                  ),
                ),
              SliverToBoxAdapter(
                child: StaggeredEntrance(
                  index: 2,
                  child: FollowedCategoriesSection(
                    categories: _listStore.followedCategories,
                  ),
                ),
              ),
            ],
            SliverFillRemaining(
              hasScrollBody: false,
              child: StaggeredEntrance(index: 3, child: status),
            ),
            const SliverBottomPadding(),
          ],
        ),
      );
    }

    final large = context.isLargeScreen;
    final slivers = _following
        ? (large
              ? _followingTablet(context, settingsStore)
              : _followingPhone(context, settingsStore))
        : _streamsSlivers(context, settingsStore);

    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        OnsetScrollbar(
          controller: _listStore.scrollController,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + _extraTopPadding,
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: _staggered(
            'content',
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _listStore.scrollController,
              slivers: [
                SliverTopPadding(extraTopPadding: _extraTopPadding),
                ...widget.leadingSlivers,
                ...slivers,
                // Room for the bottom navigation bar.
                const SliverBottomPadding(),
              ],
            ),
          ),
        ),
        if (widget.showJumpButton)
          Observer(
            builder: (context) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _listStore.showJumpButton
                  ? ScrollToTopButton(
                      scrollController: _listStore.scrollController!,
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// Each phase (skeleton, message, content) cascades in on its first
  /// appearance only, after the launch intro when it covers the screen.
  Widget _staggered(String phase, Widget child) =>
      StaggerScope(key: ValueKey(phase), child: child);

  // ---------------------------------------------------------------------
  // Cards.

  int? _streak(StreamTwitch stream) =>
      _following ? _listStore.watchStreaks[stream.userId] : null;

  Widget _card(
    StreamTwitch stream, {
    required SettingsStore settings,
    required bool pinned,
    bool hero = false,
    bool tile = false,
    bool largeHero = false,
    EdgeInsetsGeometry? padding,
  }) {
    final showCategory = widget.categoryId == null;
    final hypeTrain = _following ? _listStore.hypeTrains[stream.userId] : null;
    if (hero) {
      return LargeStreamCard(
        key: ValueKey(stream.userId),
        streamInfo: stream,
        showThumbnail: settings.showThumbnails,
        showCategory: showCategory,
        showPinOption: _following,
        isPinned: pinned,
        hypeTrain: hypeTrain,
        watchStreak: _streak(stream),
        large: largeHero,
        padding: padding,
      );
    }
    return StreamCard(
      key: ValueKey(stream.userId),
      streamInfo: stream,
      showThumbnail: settings.showThumbnails,
      showCategory: showCategory,
      showPinOption: _following,
      isPinned: pinned,
      hypeTrain: hypeTrain,
      watchStreak: _streak(stream),
      tile: tile,
      activeTag: widget.listType == ListType.tag ? widget.tag : null,
    );
  }

  /// Asks for the next page when [index] of [length] nears the end.
  void _pageNear(int index, int length) {
    if (index > length - 10 && _listStore.hasMore) _listStore.getStreams();
  }

  // ---------------------------------------------------------------------
  // Following, phone (board Accueil).

  List<Widget> _followingPhone(BuildContext context, SettingsStore settings) {
    final pinned = [
      for (final stream in _listStore.allPinnedChannels) stream as StreamTwitch,
    ];
    final unpinned = _unpinned(settings);
    final heroAll = settings.largeStreamCard;
    final heroFirst = settings.showThumbnails;
    var entrance = 0;
    Widget enter(Widget child) =>
        StaggeredEntrance(index: entrance++, child: child);

    Widget section(List<StreamTwitch> streams, {required bool isPinned}) {
      final first = isPinned || pinned.isEmpty;
      return SliverList.builder(
        itemCount: streams.length,
        itemBuilder: (context, index) {
          if (!isPinned) _pageNear(index, streams.length);
          return StaggeredEntrance(
            index: 2 + index,
            child: Observer(
              builder: (context) => _card(
                streams[index],
                settings: settings,
                pinned: isPinned,
                hero: heroAll || (heroFirst && first && index == 0),
              ),
            ),
          );
        },
      );
    }

    return [
      if (_continueWatching case final shelf?)
        SliverToBoxAdapter(child: enter(ContinueWatchingShelf(store: shelf))),
      SliverToBoxAdapter(
        child: enter(
          _LiveNowHeader(
            count: pinned.length + unpinned.length,
            settingsStore: settings,
          ),
        ),
      ),
      if (pinned.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _Eyebrow('Pinned')),
        section(pinned, isPinned: true),
        const SliverToBoxAdapter(child: _Eyebrow('All')),
      ],
      section(unpinned, isPinned: false),
      ..._followingTail(context, settings, chipsShown: false),
    ];
  }

  List<StreamTwitch> _unpinned(SettingsStore settings) => [
    for (final stream in _listStore.streams)
      if (!settings.pinnedChannelIds.contains(stream.userId)) stream,
  ];

  /// What follows the live channels: the followed videos, the followed
  /// categories (unless the tablet's hero row shows them) and the offline
  /// channels.
  List<Widget> _followingTail(
    BuildContext context,
    SettingsStore settings, {
    required bool chipsShown,
  }) {
    final large = context.isLargeScreen;
    return [
      const SliverToBoxAdapter(child: FollowedVideosTile()),
      if (!chipsShown)
        SliverToBoxAdapter(
          child: Observer(
            builder: (context) => FollowedCategoriesSection(
              categories: _listStore.followedCategories,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Observer(
          builder: (context) => ExpandableSectionHeader(
            'Offline',
            isFirst: true,
            padding: EdgeInsets.fromLTRB(
              (large ? OnsetSpacing.gutterTablet : OnsetSpacing.gutterPhone) +
                  MediaQuery.paddingOf(context).left,
              16,
              (large ? OnsetSpacing.gutterTablet : OnsetSpacing.gutterPhone) +
                  MediaQuery.paddingOf(context).right,
              8,
            ),
            isExpanded: _listStore.isOfflineChannelsExpanded,
            onToggle: () => _listStore.isOfflineChannelsExpanded =
                !_listStore.isOfflineChannelsExpanded,
          ),
        ),
      ),
      if (_listStore.isOfflineChannelsExpanded)
        RowGridSliver(
          itemCount: _listStore.offlineChannels.length,
          columns: large ? _columns(context, minWidth: 360) : 1,
          gutter: large ? OnsetSpacing.gutterTablet - 16 : 0,
          gap: 0,
          rowGap: 0,
          itemBuilder: (context, index) {
            // Load more offline channels when nearing the end.
            if (index > _listStore.offlineChannels.length - 5 &&
                _listStore.hasMoreOfflineChannels) {
              _listStore.getOfflineChannels();
            }
            return Observer(
              builder: (context) => OfflineChannelCard(
                key: ValueKey(_listStore.offlineChannels[index].broadcasterId),
                channelInfo: _listStore.offlineChannels[index],
                showPinOption: false,
                isPinned: false,
              ),
            );
          },
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // Following, tablet (board TabletteAccueil).

  /// Grid columns in this page's width, each at least [minWidth] wide.
  int _columns(
    BuildContext context, {
    required double minWidth,
    double gutter = OnsetSpacing.gutterTablet,
  }) {
    final padding = MediaQuery.paddingOf(context);
    final width =
        MediaQuery.sizeOf(context).width - padding.horizontal - 2 * gutter;
    return math.max(1, ((width + 20) / (minWidth + 20)).floor());
  }

  List<Widget> _followingTablet(BuildContext context, SettingsStore settings) {
    final pinned = [
      for (final stream in _listStore.allPinnedChannels) stream as StreamTwitch,
    ];
    final unpinned = _unpinned(settings);
    final all = [...pinned, ...unpinned];
    final heroStream = settings.showThumbnails && all.isNotEmpty
        ? all.first
        : null;
    final shelf = _continueWatching;
    final categories = _listStore.followedCategories;
    final padding = MediaQuery.paddingOf(context);
    final gutter = EdgeInsets.only(
      left: OnsetSpacing.gutterTablet + padding.left,
      right: OnsetSpacing.gutterTablet + padding.right,
    );
    final heroAll = settings.largeStreamCard;
    final columns = !settings.showThumbnails
        ? _columns(context, minWidth: 360)
        : heroAll
        ? _columns(context, minWidth: 380)
        : _columns(context, minWidth: 240);

    Widget grid(List<StreamTwitch> streams, {required bool isPinned}) =>
        RowGridSliver(
          itemCount: streams.length,
          columns: columns,
          itemBuilder: (context, index) {
            if (!isPinned) _pageNear(index, streams.length);
            return StaggeredEntrance(
              index: 3 + index,
              child: Observer(
                builder: (context) => _card(
                  streams[index],
                  settings: settings,
                  pinned: isPinned,
                  hero: heroAll,
                  tile: !heroAll,
                  padding: EdgeInsets.zero,
                ),
              ),
            );
          },
        );

    final restPinned = [
      for (final stream in pinned)
        if (stream != heroStream) stream,
    ];
    final restUnpinned = [
      for (final stream in unpinned)
        if (stream != heroStream) stream,
    ];

    return [
      if (heroStream != null)
        SliverPadding(
          padding: gutter.copyWith(top: 22),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroWidth = math.min(640.0, constraints.maxWidth * 0.55);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    SizedBox(
                      width: heroWidth,
                      child: StaggeredEntrance(
                        index: 0,
                        child: Observer(
                          builder: (context) => _card(
                            heroStream,
                            settings: settings,
                            pinned: pinned.contains(heroStream),
                            hero: true,
                            largeHero: true,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: StaggeredEntrance(
                        index: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            if (shelf != null)
                              ContinueWatchingColumn(store: shelf),
                            FollowedCategoryChips(categories: categories),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        )
      else if (shelf != null)
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 0,
              child: ContinueWatchingShelf(store: shelf),
            ),
          ),
        ),
      SliverPadding(
        padding: gutter.copyWith(top: heroStream != null ? 26 : 8),
        sliver: SliverToBoxAdapter(
          child: StaggeredEntrance(
            index: 2,
            child: _LiveNowHeader(
              count: all.length,
              settingsStore: settings,
              horizontalPadding: 0,
            ),
          ),
        ),
      ),
      if (restPinned.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _Eyebrow('Pinned')),
        grid(restPinned, isPinned: true),
      ],
      if (restPinned.isNotEmpty ||
          (pinned.isNotEmpty && restUnpinned.isNotEmpty))
        const SliverToBoxAdapter(child: _Eyebrow('All')),
      grid(restUnpinned, isPinned: false),
      ..._followingTail(
        context,
        settings,
        chipsShown: heroStream != null && categories.isNotEmpty,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Top, category and tag lists.

  List<Widget> _streamsSlivers(BuildContext context, SettingsStore settings) {
    final streams = _listStore.streams;
    final large = context.isLargeScreen;
    final heroAll = settings.largeStreamCard && settings.showThumbnails;
    final gutter = widget.gridGutter;
    final columns = !large
        ? 1
        : !settings.showThumbnails
        ? _columns(context, minWidth: 360, gutter: gutter)
        : heroAll
        ? _columns(context, minWidth: 380, gutter: gutter)
        : _columns(context, minWidth: widget.tileMinWidth, gutter: gutter);
    return [
      SliverToBoxAdapter(
        child: Observer(
          builder: (context) => HiddenStreamsBanner(
            hidden: _listStore.hiddenByLabels,
            onShow: _listStore.showLabeledStreams,
          ),
        ),
      ),
      if (large) const SliverToBoxAdapter(child: SizedBox(height: 12)),
      RowGridSliver(
        itemCount: streams.length,
        columns: columns,
        gutter: large ? gutter : 0,
        gap: large ? 20 : 0,
        rowGap: large ? 22 : 0,
        itemBuilder: (context, index) {
          _pageNear(index, streams.length);
          return StaggeredEntrance(
            index: index,
            child: Observer(
              builder: (context) => _card(
                streams[index],
                settings: settings,
                pinned: false,
                hero: heroAll,
                tile: large && !heroAll,
                padding: large ? EdgeInsets.zero : null,
              ),
            ),
          );
        },
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Loading (board Etats / EtatsTablette, "Chargement").

  List<Widget> _skeleton(BuildContext context, SettingsStore settings) {
    final large = context.isLargeScreen;
    final thumbnails = settings.showThumbnails;
    // A category's rows name their viewers where the others name the
    // category (with thumbnails): the same height either way.
    final showCategory = widget.listType != ListType.category || thumbnails;
    final heroAll = settings.largeStreamCard && thumbnails;
    if (_following && !large) {
      return [
        if (_continueWatching case final shelf?)
          SliverToBoxAdapter(
            child: Observer(
              builder: (context) => shelf.loading
                  ? const ContinueWatchingSkeleton()
                  : ContinueWatchingShelf(store: shelf),
            ),
          ),
        const SliverToBoxAdapter(child: _LiveNowHeaderSkeleton()),
        SliverList.builder(
          itemCount: 5,
          itemBuilder: (context, index) => StaggeredEntrance(
            index: index,
            child: (heroAll || (thumbnails && index == 0))
                ? const HeroCardSkeleton()
                : FeedRowSkeleton(
                    showThumbnail: thumbnails,
                    showCategory: showCategory,
                  ),
          ),
        ),
      ];
    }
    if (!large) {
      return [
        SliverList.builder(
          itemCount: 8,
          itemBuilder: (context, index) => StaggeredEntrance(
            index: index,
            child: heroAll
                ? const HeroCardSkeleton()
                : FeedRowSkeleton(
                    showThumbnail: thumbnails,
                    showCategory: showCategory,
                  ),
          ),
        ),
      ];
    }
    final padding = MediaQuery.paddingOf(context);
    final gutter = _following ? OnsetSpacing.gutterTablet : widget.gridGutter;
    final columns = !thumbnails
        ? _columns(context, minWidth: 360, gutter: gutter)
        : heroAll
        ? _columns(context, minWidth: 380, gutter: gutter)
        : _columns(
            context,
            minWidth: _following ? 240 : widget.tileMinWidth,
            gutter: gutter,
          );
    return [
      if (_following && thumbnails)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            OnsetSpacing.gutterTablet + padding.left,
            22,
            OnsetSpacing.gutterTablet + padding.right,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  SizedBox(
                    width: math.min(640.0, constraints.maxWidth * 0.55),
                    child: const AspectRatio(
                      aspectRatio: 640 / 330,
                      child: SkeletonLoader(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                  ),
                  const Expanded(child: _ShelfColumnSkeleton()),
                ],
              ),
            ),
          ),
        ),
      if (_following)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            OnsetSpacing.gutterTablet + padding.left,
            26,
            OnsetSpacing.gutterTablet + padding.right,
            0,
          ),
          sliver: const SliverToBoxAdapter(
            child: _LiveNowHeaderSkeleton(horizontalPadding: 0),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      RowGridSliver(
        itemCount: columns * 2,
        gutter: gutter,
        columns: columns,
        itemBuilder: (context, index) => StaggeredEntrance(
          index: index,
          child: heroAll
              ? const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SkeletonLoader(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                )
              : thumbnails
              ? const FeedTileSkeleton()
              : FeedRowSkeleton(
                  showThumbnail: false,
                  showCategory: showCategory,
                ),
        ),
      ),
    ];
  }
}

/// Cards in [columns] (one: a plain list), [gap] apart, in the page's
/// [gutter]; a row's cards top-aligned.
class RowGridSliver extends StatelessWidget {
  const RowGridSliver({
    super.key,
    required this.itemCount,
    required this.columns,
    required this.itemBuilder,
    this.gutter = OnsetSpacing.gutterTablet,
    this.gap = 20,
    this.rowGap = 22,
    this.padding,
  });

  final int itemCount;
  final int columns;
  final IndexedWidgetBuilder itemBuilder;
  final double gutter;
  final double gap;
  final double rowGap;

  /// The grid's sides, instead of [gutter] and the window's insets.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return SliverList.builder(itemCount: itemCount, itemBuilder: itemBuilder);
    }
    final window = MediaQuery.paddingOf(context);
    return SliverPadding(
      padding:
          padding ??
          EdgeInsets.only(
            left: gutter + window.left,
            right: gutter + window.right,
          ),
      sliver: SliverList.builder(
        itemCount: (itemCount / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: EdgeInsets.only(bottom: rowGap),
          // The cards pad themselves with the window's insets: the grid
          // already did.
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: row * columns + column < itemCount
                        ? itemBuilder(context, row * columns + column)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Live now N" and the order (boards Accueil and TabletteAccueil).
class _LiveNowHeader extends StatelessWidget {
  const _LiveNowHeader({
    required this.count,
    required this.settingsStore,
    this.horizontalPadding = OnsetSpacing.gutterPhone,
  });

  final int count;
  final SettingsStore settingsStore;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding + (horizontalPadding > 0 ? padding.left : 0),
        6,
        horizontalPadding + (horizontalPadding > 0 ? padding.right : 0),
        8,
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FeedSectionTitle('Live now', count: count),
            ),
          ),
          Flexible(child: FollowedSortButton(settingsStore: settingsStore)),
        ],
      ),
    );
  }
}

/// A small group label ("Pinned", "All").
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final gutter = context.isLargeScreen
        ? OnsetSpacing.gutterTablet
        : OnsetSpacing.gutterPhone;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter + padding.left,
        8,
        gutter + padding.right,
        8,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: OnsetType.label.copyWith(
            color: FeedColors.of(context).tertiary,
          ),
        ),
      ),
    );
  }
}

/// Helper widget for consistent top padding in sliver lists
class SliverTopPadding extends StatelessWidget {
  final double extraTopPadding;

  const SliverTopPadding({super.key, this.extraTopPadding = 0.0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).padding.top + extraTopPadding,
      ),
    );
  }
}

/// Helper widget for consistent bottom padding in sliver lists
class SliverBottomPadding extends StatelessWidget {
  const SliverBottomPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.of(context).padding.bottom),
    );
  }
}

/// Says how many streams the viewer's content preferences left out of a
/// list, with a way to show them (nothing when none are hidden).
class HiddenStreamsBanner extends StatelessWidget {
  const HiddenStreamsBanner({
    super.key,
    required this.hidden,
    required this.onShow,
  });

  final int hidden;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    if (hidden == 0) return const SizedBox.shrink();
    final colors = FeedColors.of(context);
    final gutter = context.isLargeScreen
        ? OnsetSpacing.gutterTablet
        : OnsetSpacing.gutterPhone;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter + MediaQuery.paddingOf(context).left,
        4,
        8 + MediaQuery.paddingOf(context).right,
        4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: colors.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hidden == 1
                  ? '1 stream hidden by your content preferences'
                  : '$hidden streams hidden by your content preferences',
              style: TextStyle(fontSize: 13, color: colors.secondary),
            ),
          ),
          TextButton(onPressed: onShow, child: const Text('Show')),
        ],
      ),
    );
  }
}

/// Opens the newest videos of the followed channels (board Etats: a 60 dp
/// card, 420 wide on a tablet).
class FollowedVideosTile extends StatelessWidget {
  const FollowedVideosTile({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = FeedColors.of(context);
    final large = context.isLargeScreen;
    final gutter = large ? OnsetSpacing.gutterTablet : OnsetSpacing.gutterPhone;
    const radius = BorderRadius.all(Radius.circular(16));
    final card = PressScale(
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            final id = context.read<AuthStore>().user.details?.id;
            if (id == null) return;
            unawaited(FollowedVideosScreen.open(context, userId: id));
          },
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, end: 12),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.video_library_outlined,
                      size: 20,
                      color: colors.body,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Followed videos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.tertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter + padding.left,
        16,
        gutter + padding.right,
        8,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: large ? 420 : double.infinity),
          child: card,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Skeletons in the cards' exact shapes (one sheen crosses them all).

/// "Live now" and the order pill, loading.
class _LiveNowHeaderSkeleton extends StatelessWidget {
  const _LiveNowHeaderSkeleton({
    this.horizontalPadding = OnsetSpacing.gutterPhone,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding + (horizontalPadding > 0 ? padding.left : 0),
        6,
        horizontalPadding + (horizontalPadding > 0 ? padding.right : 0),
        12,
      ),
      child: const Row(
        children: [
          SkeletonLoader(width: 104, height: 16),
          Spacer(),
          SkeletonLoader(
            width: 84,
            height: 32,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      ),
    );
  }
}

/// The tablet's shelf column, loading.
class _ShelfColumnSkeleton extends StatelessWidget {
  const _ShelfColumnSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row(double width) => Row(
      spacing: 14,
      children: [
        const SkeletonLoader(
          width: 210,
          height: 118,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 9,
            children: [
              SkeletonText(height: 13, minWidth: width, maxWidth: width),
              const SkeletonLoader(width: 140, height: 11),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        const SkeletonLoader(width: 170, height: 16),
        row(200),
        row(170),
        const Row(
          spacing: 10,
          children: [
            SkeletonLoader(
              width: 96,
              height: 32,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            SkeletonLoader(
              width: 150,
              height: 32,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The hero card, loading (radius 18, 16:9).
class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OnsetSpacing.gutterPhone + padding.left,
        6,
        OnsetSpacing.gutterPhone + padding.right,
        8,
      ),
      child: const AspectRatio(
        aspectRatio: 16 / 9,
        child: SkeletonLoader(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );
  }
}

/// A [StreamCard] row, loading (150 x 84 thumbnail, avatar and three lines).
class FeedRowSkeleton extends StatelessWidget {
  const FeedRowSkeleton({
    super.key,
    this.showThumbnail = true,
    this.showCategory = true,
  });

  final bool showThumbnail;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OnsetSpacing.gutterPhone + padding.left,
        8,
        OnsetSpacing.gutterPhone + padding.right,
        8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = StreamCard.rowThumbnailWidth(constraints.maxWidth);
          return Row(
            spacing: 12,
            children: [
              if (showThumbnail)
                SkeletonLoader(
                  width: width,
                  height: width * 9 / 16,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                )
              else
                const SkeletonLoader(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 9,
                  children: [
                    const Row(
                      spacing: 6,
                      children: [
                        SkeletonLoader(
                          width: 18,
                          height: 18,
                          borderRadius: BorderRadius.all(Radius.circular(9)),
                        ),
                        SkeletonLoader(width: 80, height: 12),
                      ],
                    ),
                    SkeletonText(height: 11, minWidth: 110, maxWidth: 180),
                    if (showCategory)
                      SkeletonText(height: 10, minWidth: 70, maxWidth: 110),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A [StreamCard] tile, loading (board EtatsTablette).
class FeedTileSkeleton extends StatelessWidget {
  const FeedTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonLoader(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            SkeletonLoader(
              width: 34,
              height: 34,
              borderRadius: BorderRadius.all(Radius.circular(17)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SkeletonLoader(width: 120, height: 13),
                  SkeletonText(height: 11, minWidth: 140, maxWidth: 190),
                  SkeletonLoader(width: 110, height: 10),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
