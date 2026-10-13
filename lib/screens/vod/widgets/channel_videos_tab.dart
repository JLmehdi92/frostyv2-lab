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
  });

  final ChannelVideosStore store;
  final String emptyMessage;

  @override
  State<ChannelVideosTab> createState() => _ChannelVideosTabState();
}

class _ChannelVideosTabState extends State<ChannelVideosTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
        return Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            RefreshIndicator.adaptive(
              onRefresh: store.refresh,
              child: FrostyScrollbar(
                controller: store.scrollController,
                child: CustomScrollView(
                  controller: store.scrollController,
                  slivers: [
                    AdaptiveSliverList(
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final vod = videos[index];
                        final saved = _resume[vod.id];
                        return VodCard(
                          vod: vod,
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
                            'Showing the ${videos.length} most recent videos',
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
                ),
              ),
            ),
            ScrollToTopButton(scrollController: store.scrollController),
          ],
        );
      },
    );
  }
}
