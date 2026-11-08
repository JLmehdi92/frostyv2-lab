import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/video_collection.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/adaptive_sliver_list.dart';

String profileCollectionDetails(
  VideoCollection collection,
  AppLocalizations l,
) {
  final updatedAt = collection.updatedAt;
  return [
    l.profileCollectionVideos(count: collection.itemCount),
    if (updatedAt != null) formatTimeAgo(updatedAt, l),
  ].join(' · ');
}

class ProfileCollectionsTab extends StatelessWidget {
  const ProfileCollectionsTab({
    super.key,
    required this.collections,
    required this.onOpen,
    required this.onRefresh,
    this.leadingSlivers = const [],
    this.refreshEdgeOffset = 0,
  });

  final List<VideoCollection> collections;
  final ValueChanged<VideoCollection> onOpen;
  final Future<void> Function() onRefresh;
  final List<Widget> leadingSlivers;
  final double refreshEdgeOffset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tiles = context.isLargeScreen;
    return RefreshIndicator.adaptive(
      edgeOffset: refreshEdgeOffset,
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('collections-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...leadingSlivers,
          const SliverPadding(padding: EdgeInsets.only(top: 12)),
          AdaptiveSliverList.videos(
            tiles: tiles,
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              final title = collection.title.trim();
              return VideoCardLayout(
                thumbnailUrl: collection.thumbnailUrl,
                fallback: (glyph: VideoGlyphKind.camera, label: null),
                lengthLabel: formatVodTime(
                  Duration(seconds: collection.lengthSeconds),
                ),
                tile: tiles,
                title: title.isEmpty ? l.videoUntitled : title,
                details: profileCollectionDetails(collection, l),
                onTap: () => onOpen(collection),
              );
            },
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
          ),
        ],
      ),
    );
  }
}
