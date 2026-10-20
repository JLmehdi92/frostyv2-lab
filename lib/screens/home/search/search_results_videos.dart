import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/search/search_videos_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/widgets/alert_message.dart';

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
        return SliverList.builder(
          itemCount: videos.length + (loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= videos.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (hasMore && index >= videos.length - _prefetchDistance) {
              // After the frame: never change the store while building.
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => store.loadMore(),
              );
            }
            return VodCard(vod: videos[index], showChannel: true);
          },
        );
      },
    );
  }
}
