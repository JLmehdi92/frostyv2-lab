import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_app_bar.dart';
import 'package:frosty/widgets/frosty_page_view.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// A channel's past broadcasts, highlights and uploads, each played in-app.
class ChannelVideosScreen extends StatefulWidget {
  static const routeName = 'ChannelVideos';

  const ChannelVideosScreen({
    super.key,
    required this.userLogin,
    required this.displayName,
    this.initialTab = VodType.archive,
  });

  final String userLogin;
  final String displayName;
  final VodType initialTab;

  static Future<void> open(
    BuildContext context, {
    required String userLogin,
    required String displayName,
    VodType initialTab = VodType.archive,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ChannelVideosScreen(
        userLogin: userLogin,
        displayName: displayName,
        initialTab: initialTab,
      ),
    ),
  );

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen> {
  static const _tabs = [
    (VodType.archive, 'Past broadcasts', 'No past broadcasts'),
    (VodType.highlight, 'Highlights', 'No highlights'),
    (VodType.upload, 'Uploads', 'No uploads'),
  ];

  final _resumeRepository = VodResumeRepository.shared;

  /// Saved watch positions, refreshed when coming back from a video.
  var _resume = const <String, VodResumeEntry>{};

  @override
  void initState() {
    super.initState();
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

  Future<void> _openVod(Vod vod) =>
      VodScreen.open(context, vodId: vod.id, vod: vod);

  late final _stores = {
    for (final (type, _, _) in _tabs)
      type: ChannelVideosStore(
        login: widget.userLogin,
        type: type,
        vodService: context.twitchVodService,
      ),
  };

  @override
  void dispose() {
    VodResumeRepository.changes.removeListener(_onResumeChanged);
    for (final store in _stores.values) {
      store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostyAppBar(title: Text('${widget.displayName} · Videos')),
      body: SafeArea(
        bottom: false,
        child: FrostyPageView(
          initialIndex: _tabs.indexWhere((t) => t.$1 == widget.initialTab),
          headers: [for (final (_, header, _) in _tabs) header],
          children: [
            for (final (type, _, empty) in _tabs)
              _VideosTab(
                store: _stores[type]!,
                emptyMessage: empty,
                resume: _resume,
                onOpen: _openVod,
              ),
          ],
        ),
      ),
    );
  }
}

class _VideosTab extends StatefulWidget {
  const _VideosTab({
    required this.store,
    required this.emptyMessage,
    required this.resume,
    required this.onOpen,
  });

  final ChannelVideosStore store;
  final String emptyMessage;
  final Map<String, VodResumeEntry> resume;
  final Future<void> Function(Vod vod) onOpen;

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
                        final saved = widget.resume[vod.id];
                        return VodCard(
                          vod: vod,
                          progress: saved == null || saved.finished
                              ? null
                              : saved.progress,
                          watched: saved?.finished ?? false,
                          onTap: () => unawaited(widget.onOpen(vod)),
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
