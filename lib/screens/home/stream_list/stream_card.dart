import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:frosty/screens/home/stream_list/stream_tags.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/home/top/tags/tag_streams.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/image_size.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:frosty/widgets/uptime.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A tappable card widget that displays a stream's thumbnail and details.
class StreamCard extends StatelessWidget {
  final StreamTwitch streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  /// The channel's running hype train, if any (followed list).
  final HtCardStatus? hypeTrain;

  const StreamCard({
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

    // Requested at the size the thumbnail is drawn (a third of the card, so
    // a tablet grid does not fetch screen-wide images), up to 1920x1080, the
    // largest the Twitch API serves.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final thumbnail = AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
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
    );

    final streamerName = getReadableName(
      streamInfo.userName,
      streamInfo.userLogin,
    );

    final streamTitle = streamInfo.title.trim();
    final category = streamInfo.gameName.isNotEmpty
        ? streamInfo.gameName
        : 'No Category';

    const subFontSize = 14.0;

    final fontColor = DefaultTextStyle.of(context).style.color;

    final imageSection = ClipRRect(
      borderRadius: kCardBorderRadius,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          GestureDetector(
            onLongPress: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => FrostyPhotoViewDialog(
                  imageUrl: streamInfo
                      .thumbnailUrl, // Pass original URL with {width}x{height} placeholder
                  cacheKey: cacheKey,
                ),
              );
            },
            child: thumbnail,
          ),
          if (hypeTrain case final status?)
            PositionedDirectional(
              start: 0,
              bottom: 0,
              child: HypeTrainCardPill(status: status),
            ),
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Uptime(
              startTime: streamInfo.startedAt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.frostyColors.overlayOnSurface,
              ),
            ),
          ),
        ],
      ),
    );

    final streamInfoSection = Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            spacing: 4,
            children: [
              ProfilePicture(userLogin: streamInfo.userLogin, radius: 10),
              Flexible(
                child: Tooltip(
                  message: streamerName,
                  preferBelow: false,
                  child: Text(
                    streamerName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fontColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Tooltip(
            message: streamTitle,
            preferBelow: false,
            child: Text(
              streamTitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: subFontSize,
                color: fontColor?.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (showCategory) ...[
            InkWell(
              onTap: streamInfo.gameName.isNotEmpty
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(
                          name: CategoryStreams.routeName,
                        ),
                        builder: (context) =>
                            CategoryStreams(categoryId: streamInfo.gameId),
                      ),
                    )
                  : null,
              child: Tooltip(
                message: category,
                preferBelow: false,
                child: Text(
                  category,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subFontSize,
                    color: fontColor?.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
          Text(
            '${NumberFormat().format(streamInfo.viewerCount)} viewers',
            style: TextStyle(
              fontSize: subFontSize,
              color: fontColor?.withValues(alpha: 0.8),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (streamInfo.tags.isNotEmpty) ...[
            const SizedBox(height: 2),
            StreamTags(
              tags: streamInfo.tags,
              onTap: (tag) => TagStreams.open(context, tag),
            ),
          ],
        ],
      ),
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
          top: 8,
          bottom: 8,
          left: showThumbnail
              ? 16 + MediaQuery.of(context).padding.left
              : 4 + MediaQuery.of(context).padding.left,
          right: showThumbnail
              ? 16 + MediaQuery.of(context).padding.right
              : 4 + MediaQuery.of(context).padding.right,
        ),
        child: Row(
          children: [
            if (showThumbnail) Flexible(child: imageSection),
            Flexible(flex: 2, child: streamInfoSection),
          ],
        ),
      ),
    );
  }
}
