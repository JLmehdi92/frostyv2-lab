import 'package:flutter/material.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/uptime.dart';

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

/// "Offline · Hytale", or "Offline" without a last category.
String offlineLine(ChannelQuery channel) =>
    channel.gameName.isEmpty ? 'Offline' : 'Offline · ${channel.gameName}';

/// A channel's picture, ringed in the signal colour while it is live
/// (2 dp of ground, then 1.5 dp of signal, drawn outside
/// the picture so nothing moves).
class SearchAvatar extends StatelessWidget {
  const SearchAvatar({
    super.key,
    required this.login,
    required this.size,
    required this.live,
  });

  final String login;
  final double size;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final picture = ProfilePicture(userLogin: login, radius: size / 2);
    if (!live) return picture;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: context.onsetColors.live, spreadRadius: 3.5),
          BoxShadow(
            color: Theme.of(context).scaffoldBackgroundColor,
            spreadRadius: 2,
          ),
        ],
      ),
      child: picture,
    );
  }
}

/// The exact match of a search: a
/// raised card with the picture, the name, live or offline with the
/// category, and the stream's title.
class FeaturedChannelCard extends StatelessWidget {
  const FeaturedChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onLongPress,
    this.large = false,
  });

  final ChannelQuery channel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// The tablet's card: a bigger picture and name, the title under them.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = getReadableName(channel.displayName, channel.broadcasterLogin);
    final meta = TextStyle(fontSize: large ? 13 : 12, color: colors.secondary);
    final status = channel.isLive
        ? Row(
            spacing: large ? 7 : 6,
            children: [
              const LiveBadge(small: true),
              Uptime(
                startTime: channel.startedAt,
                style: OnsetType.tabular(meta),
              ),
              if (channel.gameName.isNotEmpty) ...[
                Text('·', style: meta),
                Flexible(
                  child: Text(
                    channel.gameName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: meta,
                  ),
                ),
              ],
            ],
          )
        : Text(
            offlineLine(channel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: meta,
          );
    final title = channel.title.isEmpty
        ? null
        : Text(
            channel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: large ? 14 : 13,
              height: large ? 1.45 : 1.4,
              color: colors.body,
            ),
          );
    final head = Row(
      spacing: large ? 14 : 12,
      children: [
        SearchAvatar(
          login: channel.broadcasterLogin,
          size: large ? 64 : 56,
          live: channel.isLive,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: large ? 5 : 4,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: OnsetTokens.displayFamily,
                  fontSize: large ? 20 : 17,
                  fontWeight: large ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: (large ? -0.02 : -0.015) * (large ? 20 : 17),
                  color: colors.text,
                ),
              ),
              status,
              if (!large) ?title,
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: large ? 22 : 20,
          color: colors.secondary,
        ),
      ],
    );
    final radius = BorderRadius.circular(large ? 18 : 16);
    return PressScale(
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.all(large ? 16 : 12),
            child: large && title != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [head, title],
                  )
                : head,
          ),
        ),
      ),
    );
  }
}
