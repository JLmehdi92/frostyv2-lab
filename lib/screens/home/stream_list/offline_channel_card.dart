import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/followed_channel.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

/// A tappable card widget that displays an offline followed channel's details.
class OfflineChannelCard extends StatelessWidget {
  final FollowedChannel channelInfo;
  final bool showPinOption;
  final bool? isPinned;
  final bool showOfflineStatus;

  const OfflineChannelCard({
    super.key,
    required this.channelInfo,
    required this.showPinOption,
    this.isPinned,
    this.showOfflineStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final channelName = getReadableName(
      channelInfo.broadcasterName,
      channelInfo.broadcasterLogin,
    );

    final colors = FeedColors.of(context);
    final followedDuration = DateTime.now().difference(channelInfo.followedAt);

    final l = context.l10n;
    final days = followedDuration.inDays;
    final followedText = switch (days) {
      >= 365 => l.streamFollowingForYears(count: days ~/ 365),
      >= 30 => l.streamFollowingForMonths(count: days ~/ 30),
      > 0 => l.streamFollowingForDays(count: days),
      _ when followedDuration.inHours > 0 => l.streamFollowingForHours(
        count: followedDuration.inHours,
      ),
      _ => l.streamFollowingForMinutes(count: followedDuration.inMinutes),
    };

    // The card sinks as soon as the finger is down (design system press).
    return PressScale(
      child: InkWell(
        // Offline: the profile, like Twitch (its Chat button opens the chat).
        onTap: () => ChannelProfileScreen.open(
          context,
          login: channelInfo.broadcasterLogin,
          userId: channelInfo.broadcasterId,
          displayName: channelName,
        ),
        onLongPress: () {
          HapticFeedback.mediumImpact();

          showModalBottomSheetWithProperFocus(
            context: context,
            builder: (context) => UserActionsModal(
              authStore: context.read<AuthStore>(),
              name: channelName,
              userLogin: channelInfo.broadcasterLogin,
              userId: channelInfo.broadcasterId,
              showPinOption: showPinOption,
              isPinned: isPinned,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            OnsetSpacing.gutterPhone + MediaQuery.paddingOf(context).left,
            8,
            OnsetSpacing.gutterPhone + MediaQuery.paddingOf(context).right,
            8,
          ),
          child: Row(
            spacing: 12,
            children: [
              // Profile picture
              ProfilePicture(userLogin: channelInfo.broadcasterLogin),
              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel name
                    Text(
                      channelName,
                      style: TextStyle(
                        fontFamily: OnsetTokens.displayFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.01 * 15,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Status and follow duration
                    Text(
                      showOfflineStatus ? l.streamOffline : followedText,
                      // followedText porte une duree ("Following for 3 years"),
                      // donc chasse fixe comme tous les autres nombres.
                      style: OnsetType.tabular(
                        TextStyle(fontSize: 13, color: colors.secondary),
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
