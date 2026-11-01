import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/clip_card.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/widgets/adaptive_sliver_list.dart';

/// The channel's other top clips of the week, under a clip.
class MoreClipsSliver extends StatelessWidget {
  const MoreClipsSliver({
    super.key,
    required this.store,
    required this.current,
    required this.onOpen,
  });

  final ChannelClipsStore store;
  final Clip current;

  /// Opens another clip (the clip screen replaces itself, so clips never
  /// pile up on the back stack).
  final ValueChanged<Clip> onOpen;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final others = [
          for (final clip in store.clips)
            if (clip.slug != current.slug) clip,
        ];
        if (store.isLoading) {
          return SliverList.builder(
            itemCount: 3,
            itemBuilder: (context, _) => const VideoRowSkeleton(),
          );
        }
        if (others.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: VideoSectionLabel(
                context.l10n.clipsMoreFrom(
                  channel: current.broadcasterDisplayName,
                ),
                padding: EdgeInsets.fromLTRB(
                  16 + MediaQuery.paddingOf(context).left,
                  16,
                  16 + MediaQuery.paddingOf(context).right,
                  4,
                ),
              ),
            ),
            AdaptiveSliverList(
              itemCount: others.length,
              itemBuilder: (context, index) {
                final clip = others[index];
                return ClipCard(clip: clip, onTap: () => onOpen(clip));
              },
            ),
          ],
        );
      },
    );
  }
}
