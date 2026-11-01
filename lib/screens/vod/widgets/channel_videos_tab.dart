import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/screens/vod/vod_watch_progress.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/adaptive_sliver_list.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/scroll_to_top_button.dart';
import 'package:onset/widgets/state_views.dart';

/// One list of a channel's videos (past broadcasts, highlights or uploads)
/// with watch progress; a video opens in-app.
class ChannelVideosTab extends StatefulWidget {
  const ChannelVideosTab({
    super.key,
    required this.store,
    required this.emptyMessage,
    this.nested = false,
    this.showChannel = false,
    this.leadingSlivers = const [],
    this.refreshEdgeOffset = 0,
  });

  /// Where the pull-to-refresh spinner starts: under a [NestedScrollView]'s
  /// pinned headers.
  final double refreshEdgeOffset;

  /// Slivers before the list, in every state (loading, empty, error): a
  /// [NestedScrollView]'s overlap injectors, the profile's video types.
  final List<Widget> leadingSlivers;

  /// Cards name each video's channel (a category's videos).
  final bool showChannel;

  final ChannelVideosStore store;
  final String emptyMessage;

  /// Inside a [NestedScrollView] (the channel profile): the lists use its
  /// shared scroll controller, so they go without a scrollbar and a
  /// scroll-to-top button.
  final bool nested;

  @override
  State<ChannelVideosTab> createState() => _ChannelVideosTabState();
}

class _ChannelVideosTabState extends State<ChannelVideosTab>
    with AutomaticKeepAliveClientMixin, VodWatchProgressMixin {
  // Nested lists share one controller: a kept-alive hidden list would
  // scroll along with the shown one.
  @override
  bool get wantKeepAlive => !widget.nested;

  /// The logged-in viewer's own positions only.
  @override
  String? get watchProgressViewer => widget.store.vodService.viewerId?.call();

  @override
  void initState() {
    super.initState();
    // Each tab loads the first time it is shown.
    if (!widget.store.loaded) widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = widget.store;
    return Observer(
      builder: (context) {
        final videos = store.videos;
        final tiles = context.isLargeScreen;
        Widget grid(int count, NullableIndexedWidgetBuilder builder) =>
            AdaptiveSliverList.videos(
              tiles: tiles,
              itemCount: count,
              itemBuilder: builder,
            );

        if (!store.loaded && store.isLoading) {
          return CustomScrollView(
            slivers: [
              ...widget.leadingSlivers,
              grid(
                6,
                (context, _) => tiles
                    ? const VideoTileSkeleton()
                    : const VideoRowSkeleton(),
              ),
            ],
          );
        }
        if (videos.isEmpty) {
          final error = store.error;
          return RefreshIndicator.adaptive(
            edgeOffset: widget.refreshEdgeOffset,
            onRefresh: store.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...widget.leadingSlivers,
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: error == null
                        ? VideoListEmpty(message: widget.emptyMessage)
                        : FeedStatusView.error(
                            message: switch (error) {
                              ChannelVideosProblem.categoryNotFound =>
                                context.l10n.clipsCategoryNotFound,
                              ChannelVideosProblem.channelNotFound =>
                                context.l10n.clipsChannelNotFound,
                              ChannelVideosProblem.failed =>
                                context.l10n.videosListFailed,
                            },
                            onRetry: store.refresh,
                          ),
                  ),
                ),
              ],
            ),
          );
        }
        final list = CustomScrollView(
          controller: widget.nested ? null : store.scrollController,
          slivers: [
            ...widget.leadingSlivers,
            grid(videos.length, (context, index) {
              final vod = videos[index];
              final progress = watchProgress.of(vod);
              return VodCard(
                vod: vod,
                tile: tiles,
                showChannel: widget.showChannel,
                progress: progress.progress,
                watched: progress.watched,
                onTap: () =>
                    unawaited(VodScreen.open(context, vodId: vod.id, vod: vod)),
              );
            }),
            if (store.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    store.gameId != null
                        ? context.l10n.videosShowingMostViewed(
                            count: videos.length,
                          )
                        : context.l10n.videosShowingMostRecent(
                            count: videos.length,
                          ),
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
        if (widget.nested) {
          return RefreshIndicator.adaptive(
            edgeOffset: widget.refreshEdgeOffset,
            onRefresh: store.refresh,
            child: list,
          );
        }
        return Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            RefreshIndicator.adaptive(
              edgeOffset: widget.refreshEdgeOffset,
              onRefresh: store.refresh,
              child: OnsetScrollbar(
                controller: store.scrollController,
                child: list,
              ),
            ),
            ScrollToTopButton(scrollController: store.scrollController),
          ],
        );
      },
    );
  }
}
