import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
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
  });

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
    with AutomaticKeepAliveClientMixin {
  // Nested lists share one controller: a kept-alive hidden list would
  // scroll along with the shown one.
  @override
  bool get wantKeepAlive => !widget.nested;

  final _resumeRepository = VodResumeRepository.shared;

  /// Saved watch positions, refreshed when coming back from a video.
  var _resume = const <String, VodResumeEntry>{};

  @override
  void initState() {
    super.initState();
    // Each tab loads the first time it is shown.
    if (!widget.store.loaded) widget.store.load();
    unawaited(_loadResume());
    // Refreshed when a save lands (the closing save of a player screen
    // finishes after its route has popped).
    VodResumeRepository.changes.addListener(_onResumeChanged);
  }

  void _onResumeChanged() => unawaited(_loadResume());

  Future<void> _loadResume() async {
    final resume = await _resumeRepository.snapshot();
    if (mounted) setState(() => _resume = resume);
  }

  @override
  void dispose() {
    VodResumeRepository.changes.removeListener(_onResumeChanged);
    super.dispose();
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
            onRefresh: store.refresh,
            child: ListView(
              children: [
                const SizedBox(height: 120),
                AlertMessage(
                  message: error ?? widget.emptyMessage,
                  vertical: error == null,
                  trailingIcon: error == null ? null : Icons.refresh_rounded,
                  onTrailingIconPressed: error == null ? null : store.refresh,
                ),
              ],
            ),
          );
        }
        final list = CustomScrollView(
          controller: widget.nested ? null : store.scrollController,
          slivers: [
            AdaptiveSliverList(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final vod = videos[index];
                final saved = _resume[vod.id];
                return VodCard(
                  vod: vod,
                  showChannel: widget.showChannel,
                  progress: saved == null || saved.finished
                      ? null
                      : saved.progress,
                  watched: saved?.finished ?? false,
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
            onRefresh: store.refresh,
            child: list,
          );
        }
        return Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            RefreshIndicator.adaptive(
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
