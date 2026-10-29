import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/clips/widgets/clip_filter_bar.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

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
  });

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

  @override
  void initState() {
    super.initState();
    // Loads the first time the tab is shown.
    if (!widget.store.loaded) widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = widget.store;
    final nested = widget.nested;
    // Nested, the chips go inside the list, after the injectors (a sliver
    // pinned there would sit under the profile's own pinned headers).
    final leading = [
      ...widget.leadingSlivers,
      if (nested) SliverToBoxAdapter(child: ClipFilterBar(store: store)),
    ];
    final lists = Observer(
      builder: (context) {
        final clips = store.clips;
        if (store.isLoading) {
          return CustomScrollView(
            slivers: [
              ...leading,
              AdaptiveSliverList(
                itemCount: 6,
                itemBuilder: (context, _) =>
                    const StreamCardSkeletonLoader(showCategory: false),
              ),
            ],
          );
        }
        if (clips.isEmpty) {
          final error = store.error;
          return RefreshIndicator.adaptive(
            edgeOffset: widget.refreshEdgeOffset,
            onRefresh: store.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...leading,
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: AlertMessage(
                      message: error ?? 'No clips for this period',
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
          controller: nested ? null : store.scrollController,
          slivers: [
            ...leading,
            AdaptiveSliverList(
              itemCount: clips.length,
              itemBuilder: (context, index) =>
                  ClipCard(clip: clips[index], showChannel: widget.showChannel),
            ),
            if (store.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Showing the top ${clips.length} clips',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
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
        if (nested) {
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
    if (nested) return lists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipFilterBar(store: store),
        Expanded(child: lists),
      ],
    );
  }
}
