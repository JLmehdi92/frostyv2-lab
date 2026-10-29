import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/search/search_videos_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

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
        if (store.loading) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (error != null) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: AlertMessage(
                message: error,
                trailingIcon: Icons.refresh_rounded,
                trailingTooltip: 'Try again',
                onTrailingIconPressed: store.retry,
              ),
            ),
          );
        }
        if (videos.isEmpty) {
          if (store.query.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: AlertMessage(
                message: 'No search results found',
                vertical: true,
              ),
            ),
          );
        }
        final loadingMore = store.loadingMore;
        final hasMore = store.hasMore;
        return SliverMainAxisGroup(
          slivers: [
            // Rows of cards on a tablet, a list on a phone.
            AdaptiveSliverList(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                if (hasMore && index >= videos.length - _prefetchDistance) {
                  // After the frame: never change the store while building.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => store.loadMore(),
                  );
                }
                return VodCard(vod: videos[index], showChannel: true);
              },
            ),
            if (loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
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
          return SizedBox(
            height: 100,
            child: AlertMessage(
              message: error,
              trailingIcon: Icons.refresh_rounded,
              trailingTooltip: 'Try again',
              onTrailingIconPressed: store.retry,
            ),
          );
        }
        final videos = store.videos;
        if (videos.isEmpty) {
          if (store.query.isEmpty) return const SizedBox.shrink();
          return const SizedBox(
            height: 100,
            child: AlertMessage(
              message: 'No search results found',
              vertical: true,
            ),
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
