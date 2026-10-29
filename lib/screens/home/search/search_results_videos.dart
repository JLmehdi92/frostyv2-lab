import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/search/search_videos_store.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:frosty/widgets/state_views.dart';

/// The Videos tab of search: the matching videos (with their channel),
/// the next page loading as the end comes into view.
class SearchResultsVideos extends StatelessWidget {
  const SearchResultsVideos({super.key, required this.store});

  final SearchVideosStore store;

  /// How close to the end the next page is asked for.
  static const _prefetchDistance = 5;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final videos = store.videos;
        final error = store.error;
        final tiles = context.isLargeScreen;
        Widget grid(int count, NullableIndexedWidgetBuilder builder) =>
            AdaptiveSliverList.videos(
              tiles: tiles,
              itemCount: count,
              itemBuilder: builder,
            );

        if (store.loading) {
          return grid(
            tiles ? 8 : 4,
            (context, _) =>
                tiles ? const VideoTileSkeleton() : const VideoRowSkeleton(),
          );
        }
        if (error != null) {
          return SliverToBoxAdapter(
            child: _SectionStatus(
              InlineStatus.error(message: error, onRetry: store.retry),
            ),
          );
        }
        if (videos.isEmpty) {
          if (store.query.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return const SliverToBoxAdapter(
            child: _SectionStatus(
              InlineStatus(message: 'No search results found', glyph: null),
            ),
          );
        }
        final loadingMore = store.loadingMore;
        final hasMore = store.hasMore;
        return SliverMainAxisGroup(
          slivers: [
            // Tiles on a tablet, a list on a phone.
            grid(videos.length, (context, index) {
              if (hasMore && index >= videos.length - _prefetchDistance) {
                // After the frame: never change the store while building.
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => store.loadMore(),
                );
              }
              return VodCard(
                vod: videos[index],
                showChannel: true,
                tile: tiles,
              );
            }),
            if (loadingMore)
              grid(
                tiles ? 4 : 1,
                (context, _) => tiles
                    ? const VideoTileSkeleton()
                    : const VideoRowSkeleton(),
              ),
          ],
        );
      },
    );
  }
}

/// The first videos found, in the tablet's Top column (board
/// RechercheTablette, an approved addition): at most [limit], "See all"
/// being the Videos tab.
class SearchVideosColumn extends StatelessWidget {
  const SearchVideosColumn({super.key, required this.store, this.limit = 5});

  final SearchVideosStore store;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final error = store.error;
        if (store.loading) {
          return Column(
            children: [
              for (var i = 0; i < 2; i++)
                const StreamCardSkeletonLoader(showCategory: false),
            ],
          );
        }
        if (error != null) {
          return _SectionStatus(
            InlineStatus.error(message: error, onRetry: store.retry),
          );
        }
        final videos = store.videos;
        if (videos.isEmpty) {
          if (store.query.isEmpty) return const SizedBox.shrink();
          return const _SectionStatus(
            InlineStatus(message: 'No search results found', glyph: null),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final video in videos.take(limit))
              VodCard(vod: video, showChannel: true, sidePadding: 0),
          ],
        );
      },
    );
  }
}

/// A search section's status, in the room its results would start in.
class _SectionStatus extends StatelessWidget {
  const _SectionStatus(this.status);

  final Widget status;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 100),
    child: Center(child: status),
  );
}
