import 'package:flutter/material.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/widgets/live_indicator.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/uptime.dart';

/// The result whose login or name is exactly [query] (case and spaces
/// aside), shown first and larger like Twitch's top result; null when none.
ChannelQuery? featuredChannel(Iterable<ChannelQuery> results, String query) {
  final wanted = query.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final channel in results) {
    if (channel.broadcasterLogin.toLowerCase() == wanted ||
        channel.displayName.toLowerCase() == wanted) {
      return channel;
    }
  }
  return null;
}

/// The exact match of a search: a bigger card with the stream's title and
/// category.
class FeaturedChannelCard extends StatelessWidget {
  const FeaturedChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onLongPress,
  });

  final ChannelQuery channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    final name = getReadableName(channel.displayName, channel.broadcasterLogin);

    return Padding(
      padding: EdgeInsets.fromLTRB(16 + padding.left, 0, 16 + padding.right, 8),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: kCardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 12,
              children: [
                ProfilePicture(userLogin: channel.broadcasterLogin, radius: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (channel.isLive)
                        Row(
                          spacing: 6,
                          children: [
                            const LiveIndicator(),
                            Uptime(startTime: channel.startedAt),
                            if (channel.gameName.isNotEmpty)
                              Flexible(
                                child: Text(
                                  channel.gameName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          channel.gameName.isEmpty
                              ? 'Offline'
                              : 'Offline · ${channel.gameName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (channel.title.isNotEmpty)
                        Text(
                          channel.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
