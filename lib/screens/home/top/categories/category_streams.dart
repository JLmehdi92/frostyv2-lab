import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/stream_sort_button.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/categories/category_card.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/widgets/channel_videos_tab.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/image_size.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/onset_chip.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

/// A category's page: its header, then its live streams,
/// videos or clips. On a tablet the same content also sits beside Browse's
/// categories ([CategoryView] with `embedded`).
class CategoryStreams extends StatelessWidget {
  static const routeName = 'CategoryStreams';

  /// The category id, used for fetching the relevant streams in the [ListStore].
  final String categoryId;

  final CategorySection initialSection;

  const CategoryStreams({
    super.key,
    required this.categoryId,
    this.initialSection = CategorySection.live,
  });

  /// The id of the category a twitch.tv [link] names, found among the
  /// categories Twitch's search gives for it; null when none matches.
  static Future<String?> idOf(TwitchApi api, CategoryLink link) async {
    final slug = link.slug;
    final name = link.name?.toLowerCase();
    final found = await api.searchCategories(
      query: slug?.replaceAll('-', ' ') ?? link.name!,
    );
    for (final category in found.data) {
      // twitch.tv writes "&" either way ("…-and-…" or dropped).
      final matches = slug != null
          ? twitchCategorySlug(category.name) == slug ||
                twitchCategorySlug(category.name.replaceAll('&', ' and ')) ==
                    slug
          : category.name.toLowerCase() == name;
      if (matches) return category.id;
    }
    return null;
  }

  /// Opens the streams of the category [categoryId] (nothing for an empty
  /// id: a stream without a category).
  static Future<void> open(BuildContext context, String categoryId) async {
    if (categoryId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (context) => CategoryStreams(categoryId: categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    // No app bar to set the system bars: the theme's, as on every page.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // The header scrolls with the list and starts under the status
            // bar, so the lists are laid out without its inset.
            Positioned.fill(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: CategoryView(
                  categoryId: categoryId,
                  statusBar: padding.top,
                  initialSection: initialSection,
                ),
              ),
            ),
            // What scrolls under the status bar stays out of its icons.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: padding.top,
              child: IgnorePointer(
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.86),
                ),
              ),
            ),
            Positioned(
              top: padding.top + 6,
              left: 8 + padding.left,
              child: const _BackButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page's round back button, on the header's picture (44 dp,
/// black at 45 %).
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: context.l10n.commonBack,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 26,
            color: OverImage.text,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

/// What a category page lists.
enum CategorySection {
  live,
  videos,
  clips;

  /// The section's tab.
  String label(AppLocalizations l) => switch (this) {
    live => l.categorySectionLive,
    videos => l.categorySectionVideos,
    clips => l.categorySectionClips,
  };
}

/// A category's header and its Live / Videos / Clips: the page's content,
/// and the pane beside Browse's categories on a tablet ([embedded]).
class CategoryView extends StatefulWidget {
  const CategoryView({
    super.key,
    required this.categoryId,
    this.embedded = false,
    this.statusBar = 0,
    this.initialSection = CategorySection.live,
  });

  final CategorySection initialSection;

  final String categoryId;

  /// In the tablet's pane: no back button, the
  /// header and grid measures of the pane.
  final bool embedded;

  /// The status bar's height over the page (the header starts under it).
  final double statusBar;

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  late var _section = widget.initialSection;
  var _sort = StreamSort.viewersHigh;

  // Made the first time their section shows.
  late final _videos = ChannelVideosStore(
    login: '',
    type: VodType.archive,
    gameId: widget.categoryId,
    vodService: context.twitchVodService,
  );
  late final _clips = ChannelClipsStore(
    login: '',
    gameId: widget.categoryId,
    clipService: context.twitchClipService,
    clipsBetween: (start, end) => context.twitchApi.getClipsBetween(
      gameId: widget.categoryId,
      start: start,
      end: end,
    ),
  );
  var _videosMade = false;
  var _clipsMade = false;

  late final _listStore = ListStore(
    listType: ListType.category,
    categoryId: widget.categoryId,
    authStore: context.read<AuthStore>(),
    twitchApi: context.read<TwitchApi>(),
    settingsStore: context.read<SettingsStore>(),
    // Only the header: the list has its own store.
    loadStreams: false,
  );

  bool? _followsCategory;

  @override
  void initState() {
    super.initState();
    unawaited(_readFollow());
  }

  Future<void> _readFollow() async {
    final actions = FollowFlow.actionsOf(context);
    if (actions == null) return;
    final follows = await actions.followsCategory(widget.categoryId);
    if (mounted) setState(() => _followsCategory = follows);
  }

  Future<void> _follow(String name) async {
    await FollowFlow.toggle(
      context,
      target: FollowTarget.category,
      id: widget.categoryId,
      name: name,
      following: _followsCategory,
      onChanged: (now) {
        if (mounted) setState(() => _followsCategory = now);
      },
    );
  }

  /// The header that leads every section's list (it scrolls with it).
  Widget _header({required bool large}) {
    return SliverToBoxAdapter(
      child: _CategoryHeader(
        store: _listStore,
        large: large,
        embedded: widget.embedded,
        topInset: widget.statusBar,
        section: _section,
        onSection: (section) => setState(() => _section = section),
        sort: _sort,
        onSort: (sort) => setState(() => _sort = sort),
        authStore: context.read<AuthStore>(),
        onFollow: _follow,
        following: _followsCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final large = widget.embedded || context.isLargeScreen;
    final live = _section == CategorySection.live;
    // The live list stays built (hidden) on the other sections, so coming
    // back keeps its streams, order and scroll position.
    return Stack(
      children: [
        Positioned.fill(
          child: Offstage(
            offstage: !live,
            child: TickerMode(
              enabled: live,
              child: StreamsList(
                listType: ListType.category,
                categoryId: widget.categoryId,
                sort: _sort,
                showJumpButton: true,
                leadingSlivers: [
                  _header(large: large),
                  if (!large)
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                ],
                gridGutter: widget.embedded ? 24 : OnsetSpacing.gutterTablet,
                tileMinWidth: widget.embedded ? 200 : 240,
              ),
            ),
          ),
        ),
        if (!live)
          Positioned.fill(
            child: _section == CategorySection.videos
                ? _videosTab(large)
                : _clipsTab(large),
          ),
      ],
    );
  }

  Widget _videosTab(bool large) {
    _videosMade = true;
    return ChannelVideosTab(
      key: const ValueKey('category-videos'),
      store: _videos,
      emptyMessage: context.l10n.categoryNoVideos,
      showChannel: true,
      leadingSlivers: [
        _header(large: large),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  Widget _clipsTab(bool large) {
    _clipsMade = true;
    return ChannelClipsTab(
      key: const ValueKey('category-clips'),
      store: _clips,
      showChannel: true,
      filtersInList: true,
      leadingSlivers: [_header(large: large)],
    );
  }

  @override
  void dispose() {
    _listStore.dispose();
    if (_videosMade) _videos.dispose();
    if (_clipsMade) _clips.dispose();
    super.dispose();
  }
}

/// The category's picture, eyebrow, name and "Follow on Twitch", then the
/// sections and, for the live streams, their order.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.store,
    required this.large,
    required this.embedded,
    required this.topInset,
    required this.section,
    required this.onSection,
    required this.sort,
    required this.onSort,
    required this.authStore,
    required this.onFollow,
    required this.following,
  });

  final ListStore store;
  final bool large;
  final bool embedded;

  /// Room left for the status bar above the header.
  final double topInset;
  final CategorySection section;
  final ValueChanged<CategorySection> onSection;
  final StreamSort sort;
  final ValueChanged<StreamSort> onSort;

  /// Its login decides whether "Follow on Twitch" shows (following is
  /// twitch.tv's own button, behind a login); it is followed live.
  final AuthStore authStore;
  final ValueChanged<String> onFollow;
  final bool? following;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final side = embedded ? 24.0 : (large ? OnsetSpacing.gutterTablet : 16.0);
    final live = section == CategorySection.live;
    final chips = Row(
      spacing: 8,
      children: [
        for (final s in CategorySection.values)
          OnsetChip(
            label: s.label(context.l10n),
            selected: s == section,
            onSelected: () => onSection(s),
          ),
      ],
    );
    final sortButton = StreamSortButton(sort: sort, onSort: onSort);

    return Observer(
      builder: (context) {
        final category = store.categoryDetails;
        final loggedIn = authStore.isLoggedIn;
        return Stack(
          children: [
            if (category != null)
              Positioned.fill(
                child: _HeroWash(category: category, embedded: embedded),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: topInset + (embedded ? 24 : (large ? 72 : 60)),
                left: padding.left,
                right: padding.right,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: category == null
                        ? _TitleSkeleton(large: large)
                        : _Title(
                            category: category,
                            large: large,
                            onFollow: loggedIn ? onFollow : null,
                            following: following,
                          ),
                  ),
                  if (large)
                    Padding(
                      padding: EdgeInsets.fromLTRB(side, 14, side - 8, 0),
                      child: Row(
                        children: [
                          chips,
                          if (live)
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: sortButton,
                              ),
                            ),
                        ],
                      ),
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                      child: chips,
                    ),
                    if (live)
                      Padding(
                        padding: EdgeInsets.fromLTRB(side, 4, 8, 0),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: sortButton,
                        ),
                      ),
                  ],
                  if (large) const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The box art, faint behind the header and fading into the page
/// (24 %; on a tablet, into the pane).
class _HeroWash extends StatelessWidget {
  const _HeroWash({required this.category, required this.embedded});

  final CategoryTwitch category;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ground = embedded
        ? FeedColors.of(context).surface
        : Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = imagePixelWidth(
                    constraints.maxWidth,
                    MediaQuery.devicePixelRatioOf(context),
                  );
                  return Opacity(
                    opacity: embedded ? 0.18 : 0.24,
                    child: OnsetCachedNetworkImage(
                      imageUrl: categoryArtUrl(category.boxArtUrl, width),
                      memCacheWidth: width,
                      fit: BoxFit.cover,
                      useFade: false,
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                  );
                },
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55, 1],
                    colors: [
                      ground.withValues(alpha: 0.3),
                      ground.withValues(alpha: 0.7),
                      ground,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The art, "CATEGORY", the name and "Follow on Twitch".
class _Title extends StatelessWidget {
  const _Title({
    required this.category,
    required this.large,
    required this.onFollow,
    required this.following,
  });

  final CategoryTwitch category;
  final bool large;
  final ValueChanged<String>? onFollow;
  final bool? following;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final artWidth = large ? 96.0 : 84.0;
    final art = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 32,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: SizedBox(
        width: artWidth,
        child: CategoryArt(category: category, width: artWidth),
      ),
    );
    final name = Text(
      category.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: OnsetTokens.displayFamily,
        fontSize: large ? 30 : 26,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03 * (large ? 30 : 26),
        color: colors.text,
      ),
    );
    final eyebrow = Text(
      context.l10n.categoryEyebrow,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.14 * 11,
        color: colors.secondary,
      ),
    );
    final follow = onFollow == null
        ? null
        : FollowPendingGate(
            id: category.id,
            child: _FollowButton(
              large: large,
              following: following,
              onPressed: () => onFollow!(category.name),
            ),
          );
    // The heading is the eyebrow and the name; the button is its own node.
    final heading = MergeSemantics(
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [eyebrow, name],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: large ? 20 : 14,
      children: [
        art,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [heading, if (!large) ?follow],
          ),
        ),
        if (large) ?follow,
      ],
    );
  }
}

/// "Follow on Twitch ↗": twitch.tv's own button, opened in-app (the follow
/// mutation is integrity-gated).
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.large,
    required this.following,
    required this.onPressed,
  });

  final bool large;
  final bool? following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final l = context.l10n;
    final label = switch (following) {
      null => l.categoryFollowOnTwitch,
      true => l.channelFollowing,
      false => l.channelFollow,
    };
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: PressScale(
          child: Material(
            color: colors.raised,
            shape: StadiumBorder(
              side: BorderSide(
                color: colors.pillBorder,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: large ? 18 : 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Icon(
                      following == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: following == true
                          ? context.onsetColors.live
                          : colors.text,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: large ? 14 : 13,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                    if (following == null)
                      Icon(
                        Icons.north_east_rounded,
                        size: 12,
                        color: colors.tertiary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's picture and name, loading.
class _TitleSkeleton extends StatelessWidget {
  const _TitleSkeleton({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final artWidth = large ? 96.0 : 84.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: large ? 20 : 14,
      children: [
        SizedBox(
          width: artWidth,
          child: const AspectRatio(
            aspectRatio: 3 / 4,
            child: SkeletonLoader(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              SkeletonLoader(
                height: 11,
                width: 72,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SkeletonLoader(
                height: 24,
                width: 180,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
