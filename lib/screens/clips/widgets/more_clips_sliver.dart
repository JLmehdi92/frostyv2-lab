import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/section_header.dart';

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
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (others.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: SectionHeader(
                'More clips from ${current.broadcasterDisplayName}',
                isFirst: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
