import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/screens/clips/clip_screen.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/vod/stores/channel_videos_store.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/section_header.dart';

/// How many videos and clips the Home tab previews.
const kProfileHomePreviewCount = 4;

/// A channel's profile Home: the live stream (or the offline image with
/// the last broadcast), then recent broadcasts and the week's top clips,
/// each with "View all".
class ProfileHomeContent extends StatefulWidget {
  const ProfileHomeContent({
    super.key,
    required this.login,
    required this.profile,
    required this.videos,
    required this.clips,
    required this.onOpenChannel,
    required this.onViewAllVideos,
    required this.onViewAllClips,
  });

  final String login;
  final ChannelProfile? profile;
  final ChannelVideosStore videos;
  final ChannelClipsStore clips;
  final VoidCallback onOpenChannel;
  final VoidCallback onViewAllVideos;
  final VoidCallback onViewAllClips;

  @override
  State<ProfileHomeContent> createState() => _ProfileHomeContentState();
}

class _ProfileHomeContentState extends State<ProfileHomeContent> {
  @override
  void initState() {
    super.initState();
    if (!widget.videos.loaded) unawaited(widget.videos.load());
    if (!widget.clips.loaded) unawaited(widget.clips.load());
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile != null)
          _StreamCard(
            login: widget.login,
            profile: profile,
            onTap: widget.onOpenChannel,
          ),
        Observer(
          builder: (context) {
            final videos = widget.videos.videos
                .take(kProfileHomePreviewCount)
                .toList();
            if (videos.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(
                  title: 'Recent broadcasts',
                  onViewAll: widget.onViewAllVideos,
                ),
                for (final vod in videos)
                  VodCard(
                    vod: vod,
                    onTap: () => unawaited(
                      VodScreen.open(context, vodId: vod.id, vod: vod),
                    ),
                  ),
              ],
            );
          },
        ),
        Observer(
          builder: (context) {
            final clips = widget.clips.clips
                .take(kProfileHomePreviewCount)
                .toList();
            if (clips.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(
                  title: 'Popular clips',
                  onViewAll: widget.onViewAllClips,
                ),
                for (final clip in clips)
                  ClipCard(
                    clip: clip,
                    onTap: () => unawaited(
                      ClipScreen.open(context, slug: clip.slug, clip: clip),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: SectionHeader(title)),
          TextButton(onPressed: onViewAll, child: const Text('View all')),
        ],
      ),
    );
  }
}

/// The live stream, or the offline image with the last broadcast.
class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.login,
    required this.profile,
    required this.onTap,
  });

  final String login;
  final ChannelProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final live = profile.live;
    final last = profile.lastBroadcast;
    final now = DateTime.now();
    // A fresh preview every five minutes, like the stream cards.
    final image = live != null
        ? 'https://static-cdn.jtvnw.net/previews-ttv/live_user_'
              '${profile.login.toLowerCase()}-640x360.jpg'
        : profile.offlineImageUrl;
    final title = last?.title?.trim();
    final started = last?.startedAt;
    final details = [
      if (live != null)
        live.isRerun ? 'Rerun' : 'Live now'
      else if (started != null)
        'Last live ${formatTimeAgo(started, now: now).toLowerCase()}',
      ?last?.gameName,
    ].join(' · ');
    if (image == null && (title == null || title.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card.filled(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FrostyCachedNetworkImage(
                    imageUrl: image,
                    cacheKey: live == null
                        ? null
                        : '$image-${now.day}-${now.hour}-${now.minute ~/ 5}',
                    fit: BoxFit.cover,
                    memCacheWidth: 1280,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (title != null && title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: TextStyle(
                          color: live != null && !live.isRerun
                              ? Colors.red
                              : scheme.onSurfaceVariant,
                          fontWeight: live != null ? FontWeight.w600 : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
