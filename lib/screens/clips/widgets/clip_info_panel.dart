import 'package:flutter/material.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:intl/intl.dart';

/// Title, channel, clipper and actions of a clip under (or beside) the
/// player.
class ClipInfoPanel extends StatelessWidget {
  const ClipInfoPanel({
    super.key,
    required this.clip,
    required this.onCopyLink,
    required this.onShare,
    this.onWatchFullVideo,
  });

  final Clip clip;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  /// Opens the VOD at the clip; null when the VOD is gone.
  final VoidCallback? onWatchFullVideo;

  void _openChannel(BuildContext context) {
    if (clip.broadcasterId.isEmpty || clip.broadcasterLogin.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) => VideoChat(
          userId: clip.broadcasterId,
          userName: clip.broadcasterDisplayName,
          userLogin: clip.broadcasterLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    final details = [
      '${NumberFormat().format(clip.viewCount)} '
          '${clip.viewCount == 1 ? 'view' : 'views'}',
      formatTimeAgo(clip.createdAt),
    ].join(' · ');
    final gameId = clip.gameId;
    final gameName = clip.gameName;
    final curator = clip.curatorDisplayName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            clip.title.trim().isEmpty ? 'Untitled clip' : clip.title.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(details, style: TextStyle(color: muted, fontSize: 13)),
              if (gameId != null && gameName != null)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: CategoryStreams.routeName,
                      ),
                      builder: (context) => CategoryStreams(categoryId: gameId),
                    ),
                  ),
                  child: Text(
                    gameName,
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (clip.broadcasterLogin.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openChannel(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  spacing: 8,
                  children: [
                    ProfilePicture(
                      userLogin: clip.broadcasterLogin,
                      radius: 14,
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clip.broadcasterDisplayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (curator != null)
                            Text(
                              'Clipped by $curator',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onWatchFullVideo != null)
                FilledButton.tonalIcon(
                  onPressed: onWatchFullVideo,
                  icon: const Icon(Icons.video_library_outlined, size: 18),
                  label: const Text('Watch full video'),
                ),
              FilledButton.tonalIcon(
                onPressed: onCopyLink,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Copy link'),
              ),
              FilledButton.tonalIcon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
