import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/team.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class ProfileTrailerCard extends StatelessWidget {
  const ProfileTrailerCard({
    super.key,
    required this.trailer,
    required this.onOpen,
  });

  final ChannelTrailer trailer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final l = context.l10n;
    final length = trailer.length;
    final thumbnail = trailer.thumbnailUrl;
    return Semantics(
      button: true,
      label: l.profileTrailerOpen(title: trailer.title),
      onTap: onOpen,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          key: const ValueKey('profile-trailer'),
          onTap: onOpen,
          child: ProfileCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              spacing: 12,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 128,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnail != null)
                          OnsetCachedNetworkImage(
                            imageUrl: thumbnail,
                            fit: BoxFit.cover,
                          )
                        else
                          ColoredBox(color: colors.raised),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      ProfileEyebrow(l.profileTrailer),
                      Text(
                        trailer.title.isEmpty
                            ? l.profileTrailer
                            : trailer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      if (length != null)
                        Text(
                          formatVodTime(length),
                          style: OnsetType.tabular(
                            TextStyle(fontSize: 12, color: colors.secondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileTeams extends StatelessWidget {
  const ProfileTeams({super.key, required this.teams, required this.onOpen});

  final List<Team> teams;
  final ValueChanged<Team> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ProfileSectionTitle(title: context.l10n.profileTeams),
        for (final team in teams)
          PressScale(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('profile-team-${team.name}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpen(team),
                child: ProfileCard(
                  child: Row(
                    spacing: 12,
                    children: [
                      TeamLogo(team: team),
                      Expanded(
                        child: Text(
                          team.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TeamLogo extends StatelessWidget {
  const TeamLogo({super.key, required this.team, this.size = 40});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = team.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? InitialAvatar(name: team.displayName, size: size)
            : OnsetCachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
      ),
    );
  }
}
