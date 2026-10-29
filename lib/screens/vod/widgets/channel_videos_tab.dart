import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/vod_watch_progress.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

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
        if (!store.loaded && store.isLoading) {
          return CustomScrollView(
            slivers: [
              ...widget.leadingSlivers,
              AdaptiveSliverList(
                itemCount: 6,
                itemBuilder: (context, _) =>
                    const StreamCardSkeletonLoader(showCategory: false),
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
                    padding: const EdgeInsets.only(top: 120),
                    child: AlertMessage(
                      message: error ?? widget.emptyMessage,
                      vertical: error == null,
                      trailingIcon: error == null
                          ? null
                          : Icons.refresh_rounded,
                      onTrailingIconPressed: error == null
                          ? null
                          : store.refresh,
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
            AdaptiveSliverList(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final vod = videos[index];
                final progress = watchProgress.of(vod);
                return VodCard(
                  vod: vod,
                  showChannel: widget.showChannel,
                  progress: progress.progress,
                  watched: progress.watched,
                  onTap: () => unawaited(
                    VodScreen.open(context, vodId: vod.id, vod: vod),
                  ),
                );
              },
            ),
            if (store.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    store.gameId != null
                        ? 'Showing the ${videos.length} most viewed videos'
                        : 'Showing the ${videos.length} most recent videos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
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
              child: FrostyScrollbar(
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
