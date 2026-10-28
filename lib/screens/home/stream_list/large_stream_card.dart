import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:frosty/screens/channel/video/stream_info_bar.dart';
import 'package:frosty/screens/home/stream_list/watch_streak_tag.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/image_size.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

class LargeStreamCard extends StatelessWidget {
  final StreamTwitch streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  /// The channel's running hype train, if any (followed list).
  final HtCardStatus? hypeTrain;

  /// The viewer's running watch streak here, if any (followed list).
  final int? watchStreak;

  const LargeStreamCard({
    super.key,
    required this.streamInfo,
    required this.showThumbnail,
    this.showCategory = true,
    this.showPinOption = false,
    this.isPinned,
    this.hypeTrain,
    this.watchStreak,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a unique cache key for the thumbnail URL that updates every 5 minutes.
    // This ensures the image is refreshed periodically to reflect the latest content.
    final time = DateTime.now();
    final cacheKey =
        '${streamInfo.thumbnailUrl}-${time.day}-${time.hour}-${time.minute ~/ 5}';

    // Requested at the size the card is drawn (a tablet grid tile is far
    // narrower than the screen), up to 1920x1080, the largest Twitch serves.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    final thumbnail = SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: kCardBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final thumbnailWidth = imagePixelWidth(
                    constraints.maxWidth,
                    pixelRatio,
                  );
                  final thumbnailHeight = min(thumbnailWidth * 9 ~/ 16, 1080);
                  return FrostyCachedNetworkImage(
                    imageUrl: streamInfo.thumbnailUrl.replaceFirst(
                      '-{width}x{height}',
                      '-${thumbnailWidth}x$thumbnailHeight',
                    ),
                    // One cache entry per size, or a rotation would reuse a
                    // smaller image.
                    cacheKey: '$cacheKey-$thumbnailWidth',
                    memCacheWidth: thumbnailWidth,
                    placeholder: (context, url) =>
                        const SkeletonLoader(borderRadius: kCardBorderRadius),
                    useOldImageOnUrlChange: true,
                  );
                },
              ),
              if (hypeTrain case final status?)
                PositionedDirectional(
                  start: 0,
                  bottom: 0,
                  child: HypeTrainCardPill(status: status),
                ),
            ],
          ),
        ),
      ),
    );

    final streamerName = getReadableName(
      streamInfo.userName,
      streamInfo.userLogin,
    );

    // The card sinks as soon as the finger is down (design system press).
    return PressScale(
      child: InkWell(
        // The finger is down: get the stream's token while the page opens.
        onTapDown: (_) => PlaybackPreloader.instance.preload(
          login: streamInfo.userLogin,
          engine: context.read<SettingsStore>().playerEngine,
          authToken: context.read<AuthStore?>()?.twitchWebToken,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: VideoChat.routeName),
            builder: (context) => VideoChat(
              userId: streamInfo.userId,
              userName: streamInfo.userName,
              userLogin: streamInfo.userLogin,
            ),
          ),
        ),
        onLongPress: () {
          HapticFeedback.mediumImpact();

          showModalBottomSheetWithProperFocus(
            context: context,
            builder: (context) => UserActionsModal(
              authStore: context.read<AuthStore>(),
              name: streamerName,
              userLogin: streamInfo.userLogin,
              userId: streamInfo.userId,
              showPinOption: showPinOption,
              isPinned: isPinned,
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.only(
            top: showThumbnail ? 12 : 4,
            bottom: showThumbnail ? 12 : 4,
            left: 16 + MediaQuery.of(context).padding.left,
            right: 16 + MediaQuery.of(context).padding.right,
          ),
          child: Column(
            children: [
              if (showThumbnail) thumbnail,
              StreamInfoBar(
                streamInfo: streamInfo,
                showCategory: showCategory,
                padding: const EdgeInsets.symmetric(vertical: 12),
                tooltipTriggerMode: TooltipTriggerMode.longPress,
              ),
              if (watchStreak case final streak?)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: WatchStreakTag(value: streak),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
