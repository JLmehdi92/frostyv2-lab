import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/channel_clips_tab.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/stream_sort_button.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/widgets/channel_videos_tab.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

/// A widget that displays a list of streams under the provided [categoryId].
class CategoryStreams extends StatefulWidget {
  static const routeName = 'CategoryStreams';

  /// The category id, used for fetching the relevant streams in the [ListStore].
  final String categoryId;

  const CategoryStreams({super.key, required this.categoryId});

  @override
  State<CategoryStreams> createState() => _CategoryStreamsState();
}

/// What a category page lists.
enum CategorySection {
  live('Live'),
  videos('Videos'),
  clips('Clips');

  const CategorySection(this.label);

  final String label;
}

class _CategoryStreamsState extends State<CategoryStreams> {
  var _section = CategorySection.live;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: _body(
        // Single blurred background spanning app bar and category card
        BlurredContainer(
          gradientDirection: GradientDirection.up,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: MediaQuery.of(context).padding.left,
            right: MediaQuery.of(context).padding.right,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App bar section
              SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: Icon(Icons.adaptive.arrow_back_rounded),
                      onPressed: Navigator.of(context).pop,
                    ),
                  ],
                ),
              ),
              // Category card section
              Observer(
                builder: (_) {
                  if (_listStore.categoryDetails != null) {
                    return _TransparentCategoryCard(
                      category: _listStore.categoryDetails!,
                    );
                  } else {
                    // Skeleton loader for category card
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 16,
                        left: 16,
                        right: 16,
                      ),
                      child: Row(
                        spacing: 12,
                        children: [
                          const SizedBox(
                            width: 80,
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: SkeletonLoader(
                                borderRadius: kCardBorderRadius,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                SkeletonLoader(
                                  height: 20,
                                  width: double.infinity,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                SkeletonLoader(
                                  height: 16,
                                  width: 120,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              _SectionChips(
                selected: _section,
                onSelected: (section) => setState(() => _section = section),
                sort: _section == CategorySection.live ? _sort : null,
                onSort: (sort) => setState(() => _sort = sort),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Live streams scroll under the blurred [header]; videos and clips sit
  /// below it. The live list stays built (hidden) on the other sections, so
  /// coming back keeps its streams and scroll position.
  Widget _body(Widget header) {
    final live = _section == CategorySection.live;
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
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Column(
            children: [
              header,
              if (!live)
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: _section == CategorySection.videos
                        ? _videosTab()
                        : _clipsTab(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videosTab() {
    _videosMade = true;
    return ChannelVideosTab(
      store: _videos,
      emptyMessage: 'No videos in this category',
      showChannel: true,
    );
  }

  Widget _clipsTab() {
    _clipsMade = true;
    return ChannelClipsTab(store: _clips, showChannel: true);
  }

  @override
  void dispose() {
    _listStore.dispose();
    if (_videosMade) _videos.dispose();
    if (_clipsMade) _clips.dispose();
    super.dispose();
  }
}

/// A transparent version of CategoryCard for use in blurred overlays
class _TransparentCategoryCard extends StatelessWidget {
  final dynamic category;

  const _TransparentCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    // The box art is drawn 80 dp wide.
    final artWidth = (80 * MediaQuery.devicePixelRatioOf(context)).ceil();
    final artHeight = (artWidth * (4 / 3)).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: kCardBorderRadius,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: FrostyCachedNetworkImage(
                  imageUrl: category.boxArtUrl.replaceRange(
                    category.boxArtUrl.lastIndexOf('-') + 1,
                    null,
                    '${artWidth}x$artHeight.jpg',
                  ),
                  placeholder: (context, url) =>
                      const SkeletonLoader(borderRadius: kCardBorderRadius),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live, Videos and Clips of a category, and the order of its live streams.
class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.selected,
    required this.onSelected,
    required this.sort,
    required this.onSort,
  });

  final CategorySection selected;
  final ValueChanged<CategorySection> onSelected;

  /// Null hides the sort button.
  final StreamSort? sort;
  final ValueChanged<StreamSort> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kCategorySectionsHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final section in CategorySection.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(section.label),
                selected: section == selected,
                onSelected: (_) => onSelected(section),
              ),
            ),
          if (sort case final sort?)
            StreamSortButton(sort: sort, onSort: onSort),
        ],
      ),
    );
  }
}
