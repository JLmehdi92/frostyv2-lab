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
  const ChannelClipsTab({super.key, required this.store});

  final ChannelClipsStore store;

  @override
  State<ChannelClipsTab> createState() => _ChannelClipsTabState();
}

class _ChannelClipsTabState extends State<ChannelClipsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipFilterBar(store: store),
        Expanded(
          child: Observer(
            builder: (context) {
              final clips = store.clips;
              if (store.isLoading) {
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
              if (clips.isEmpty) {
                final error = store.error;
                return RefreshIndicator.adaptive(
                  onRefresh: store.refresh,
                  child: ListView(
                    children: [
                      const SizedBox(height: 120),
                      AlertMessage(
                        message: error ?? 'No clips for this period',
                        vertical: error == null,
                        trailingIcon: error == null
                            ? null
                            : Icons.refresh_rounded,
                        onTrailingIconPressed: error == null
                            ? null
                            : store.refresh,
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
                            itemCount: clips.length,
                            itemBuilder: (context, index) =>
                                ClipCard(clip: clips[index]),
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
                      ),
                    ),
                  ),
                  ScrollToTopButton(scrollController: store.scrollController),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
