import 'package:flutter/material.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:intl/intl.dart';

/// The top of a channel's profile: banner, avatar (red ring while live),
/// name with the partner check, followers, the live or rerun badge, and
/// Watch (live) or Chat (offline), Share and More.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.login,
    required this.displayName,
    this.profile,
    required this.onOpenChannel,
    required this.onShare,
    this.onMore,
  });

  final String login;
  final String displayName;

  /// Null while loading, or when only the Helix header is known.
  final ChannelProfile? profile;

  /// Watch (live) or Chat (offline): opens the channel screen.
  final VoidCallback onOpenChannel;
  final VoidCallback onShare;
  final VoidCallback? onMore;

  static const _avatarRadius = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final profile = this.profile;
    final live = profile?.live;
    final accent = profile?.accentColor;
    final banner = profile?.bannerUrl;
    final details = [
      if (profile?.followers case final followers?)
        '${NumberFormat.compact().format(followers)} '
            '${followers == 1 ? 'follower' : 'followers'}',
      if (live != null)
        '${NumberFormat.compact().format(live.viewers)} watching',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: AspectRatio(
                aspectRatio: 3,
                child: banner != null
                    ? FrostyCachedNetworkImage(
                        imageUrl: banner,
                        fit: BoxFit.cover,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent != null ? Color(accent) : scheme.primary,
                              scheme.surfaceContainerHighest,
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            PositionedDirectional(
              start: 16,
              bottom: -_avatarRadius,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: live != null ? Colors.red : scheme.surface,
                ),
                child: switch (profile?.profileImageUrl) {
                  final url? => ClipOval(
                    child: FrostyCachedNetworkImage(
                      imageUrl: url,
                      width: _avatarRadius * 2,
                      height: _avatarRadius * 2,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Only the Helix header: its own lookup.
                  null => ProfilePicture(
                    userLogin: login,
                    radius: _avatarRadius,
                  ),
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            16 + _avatarRadius * 2 + 12,
            8,
            16,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: live == null
                ? const SizedBox(height: 24)
                : _LiveBadge(isRerun: live.isRerun),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                spacing: 6,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (profile?.role == BroadcasterRole.partner)
                    Icon(
                      Icons.verified_rounded,
                      size: 20,
                      color: scheme.primary,
                      semanticLabel: 'Verified',
                    ),
                ],
              ),
              if (details.isNotEmpty)
                Text(details, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenChannel,
                    icon: Icon(
                      live != null
                          ? Icons.play_arrow_rounded
                          : Icons.chat_bubble_outline_rounded,
                    ),
                    label: Text(live != null ? 'Watch' : 'Chat'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onShare,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Share'),
                  ),
                  if (onMore != null)
                    IconButton.filledTonal(
                      tooltip: 'More',
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isRerun});

  final bool isRerun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRerun
            ? context.colorScheme.surfaceContainerHighest
            : Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isRerun ? 'RERUN' : 'LIVE',
        style: TextStyle(
          color: isRerun ? context.colorScheme.onSurface : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
