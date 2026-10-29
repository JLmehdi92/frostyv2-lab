import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/clips/widgets/clip_filter_bar.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';
import 'package:frosty/screens/vod/widgets/video_kit.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:mobx/mobx.dart';

/// A channel's clips: period and sort chips above the top 100 (rows of
/// cards on a tablet).
class ChannelClipsTab extends StatefulWidget {
  const ChannelClipsTab({
    super.key,
    required this.store,
    this.nested = false,
    this.showChannel = false,
    this.leadingSlivers = const [],
    this.refreshEdgeOffset = 0,
    this.filtersInList = false,
  });

  /// The period and sort chips scroll with the list, after
  /// [leadingSlivers] (a category's header), instead of staying above it.
  final bool filtersInList;

  /// Where the pull-to-refresh spinner starts: under a [NestedScrollView]'s
  /// pinned headers.
  final double refreshEdgeOffset;

  /// Slivers before the list, in every state: a [NestedScrollView]'s
  /// overlap injectors.
  final List<Widget> leadingSlivers;

  /// Cards name each clip's channel (a category's clips).
  final bool showChannel;

  final ChannelClipsStore store;

  /// Inside a [NestedScrollView] (the channel profile): the lists use its
  /// shared scroll controller, so they go without a scrollbar and a
  /// scroll-to-top button.
  final bool nested;

  @override
  State<ChannelClipsTab> createState() => _ChannelClipsTabState();
}

class _ChannelClipsTabState extends State<ChannelClipsTab>
    with AutomaticKeepAliveClientMixin {
  // Nested lists share one controller: a kept-alive hidden list would
  // scroll along with the shown one.
  @override
  bool get wantKeepAlive => !widget.nested;

  /// Inside the scroll view, to find it.
  final _contentKey = GlobalKey();

  late final ReactionDisposer _onFilter;

  @override
  void initState() {
    super.initState();
    // Loads the first time the tab is shown.
    if (!widget.store.loaded) widget.store.load();
    // Another period or sort starts the list from the top. A refresh is
    // not sent there, though its skeletons, while it loads, are shorter
    // than a long list: a deep position ends up nearer the top.
    _onFilter = reaction(
      (_) => (widget.store.period, widget.store.sort),
      (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _toTop()),
    );
  }

  void _toTop() {
    final context = _contentKey.currentContext;
    if (!mounted || context == null) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null && position.pixels > 0) position.jumpTo(0);
  }

  @override
  void dispose() {
    _onFilter();
    super.dispose();
  }

  /// What the list shows now: skeletons, the message, or the clips (rows,
  /// or tiles on a tablet).
  Widget _content(BuildContext context) {
    final store = widget.store;
    final clips = store.clips;
    final tiles = context.isLargeScreen;
    Widget grid(int count, NullableIndexedWidgetBuilder builder) =>
        AdaptiveSliverList.videos(
          tiles: tiles,
          itemCount: count,
          itemBuilder: builder,
        );

    if (store.isLoading) {
      return grid(
        6,
        (context, _) =>
            tiles ? const VideoTileSkeleton() : const VideoRowSkeleton(),
      );
    }
    if (clips.isEmpty) {
      final error = store.error;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: error == null
              ? const VideoListEmpty(message: 'No clips for this period')
              : FeedStatusView.error(message: error, onRetry: store.refresh),
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        grid(
          clips.length,
          (context, index) => ClipCard(
            clip: clips[index],
            tile: tiles,
            showChannel: widget.showChannel,
          ),
        ),
        if (store.hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Showing the top ${clips.length} clips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: FeedColors.of(context).tertiary,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = widget.store;
    final nested = widget.nested;
    // One scroll view in every state: the chips (nested, they are inside it,
    // after the injectors) and the list keep their place while a period
    // loads.
    final list = RefreshIndicator.adaptive(
      edgeOffset: widget.refreshEdgeOffset,
      onRefresh: store.refresh,
      child: CustomScrollView(
        controller: nested ? null : store.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.leadingSlivers,
          if (nested || widget.filtersInList)
            SliverToBoxAdapter(child: ClipFilterBar(store: store)),
          Observer(key: _contentKey, builder: _content),
        ],
      ),
    );
    if (nested) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.filtersInList) ClipFilterBar(store: store),
        Expanded(
          child: Stack(
            alignment: AlignmentDirectional.bottomCenter,
            children: [
              FrostyScrollbar(controller: store.scrollController, child: list),
              // Only over listed clips, not over the skeletons or a message.
              Observer(
                builder: (context) => !store.isLoading && store.clips.isNotEmpty
                    ? ScrollToTopButton(
                        scrollController: store.scrollController,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
