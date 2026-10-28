import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
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

    final fontColor = DefaultTextStyle.of(context).style.color;
    final followedDuration = DateTime.now().difference(channelInfo.followedAt);

    String followedText;
    if (followedDuration.inDays >= 365) {
      final years = followedDuration.inDays ~/ 365;
      followedText = 'Following for $years ${years == 1 ? 'year' : 'years'}';
    } else if (followedDuration.inDays >= 30) {
      final months = followedDuration.inDays ~/ 30;
      followedText =
          'Following for $months ${months == 1 ? 'month' : 'months'}';
    } else if (followedDuration.inDays > 0) {
      followedText =
          'Following for ${followedDuration.inDays} ${followedDuration.inDays == 1 ? 'day' : 'days'}';
    } else if (followedDuration.inHours > 0) {
      followedText =
          'Following for ${followedDuration.inHours} ${followedDuration.inHours == 1 ? 'hour' : 'hours'}';
    } else {
      followedText =
          'Following for ${followedDuration.inMinutes} ${followedDuration.inMinutes == 1 ? 'minute' : 'minutes'}';
    }

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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 + MediaQuery.of(context).padding.left,
            8,
            16 + MediaQuery.of(context).padding.right,
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
                        fontFamily: FrostyTokens.displayFamily,
                        fontWeight: FrostyTokens.displayWeight(600),
                        fontSize: 16,
                        letterSpacing: -0.011,
                        color: fontColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Status and follow duration
                    Text(
                      showOfflineStatus ? 'Offline' : followedText,
                      // followedText porte une duree ("Following for 3 years"),
                      // donc chasse fixe comme tous les autres nombres.
                      style: context.frostyText.metadata,
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
