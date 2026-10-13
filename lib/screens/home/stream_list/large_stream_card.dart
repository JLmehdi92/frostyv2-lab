import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:frosty/screens/channel/video/stream_info_bar.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
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

  const LargeStreamCard({
    super.key,
    required this.streamInfo,
    required this.showThumbnail,
    this.showCategory = true,
    this.showPinOption = false,
    this.isPinned,
    this.hypeTrain,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a unique cache key for the thumbnail URL that updates every 5 minutes.
    // This ensures the image is refreshed periodically to reflect the latest content.
    final time = DateTime.now();
    final cacheKey =
        '${streamInfo.thumbnailUrl}-${time.day}-${time.hour}-${time.minute ~/ 5}';

    // Calculate the width and height of the thumbnail based on the device width and the stream card size setting.
    // Constraint the resolution to 1920x1080 since that's the max resolution of the Twitch API.
    final size = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final thumbnailWidth = min((size.width * pixelRatio) ~/ 1, 1920);
    final thumbnailHeight = min((thumbnailWidth * (9 / 16)).toInt(), 1080);

    final thumbnail = SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: kCardBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FrostyCachedNetworkImage(
                imageUrl: streamInfo.thumbnailUrl.replaceFirst(
                  '-{width}x{height}',
                  '-${thumbnailWidth}x$thumbnailHeight',
                ),
                cacheKey: cacheKey,
                placeholder: (context, url) =>
                    const SkeletonLoader(borderRadius: kCardBorderRadius),
                useOldImageOnUrlChange: true,
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

    return InkWell(
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
          ],
        ),
      ),
    );
  }
}
