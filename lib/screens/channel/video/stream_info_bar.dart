import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/live_indicator.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/uptime.dart';

class StreamInfoBar extends StatelessWidget {
  final StreamTwitch? streamInfo;
  final Channel? offlineChannelInfo;
  final bool showCategory;
  final bool tappableCategory;
  final bool showUptime;
  final bool showViewerCount;
  final bool showOfflineIndicator;
  final EdgeInsets padding;
  final TooltipTriggerMode tooltipTriggerMode;
  final Color? textColor;
  final bool isCompact;
  final bool isInSharedChatMode;
  final bool isOffline;
  final bool showTextShadows;

  /// Opens the channel's profile from the avatar; null keeps it inert.
  final VoidCallback? onTapChannel;

  final String? displayName;

  const StreamInfoBar({
    super.key,
    this.streamInfo,
    this.offlineChannelInfo,
    this.showCategory = true,
    this.tappableCategory = true,
    this.showUptime = true,
    this.showViewerCount = true,
    this.showOfflineIndicator = true,
    this.padding = EdgeInsets.zero,
    this.tooltipTriggerMode = TooltipTriggerMode.tap,
    this.textColor,
    this.isCompact = false,
    this.isInSharedChatMode = false,
    this.isOffline = false,
    this.showTextShadows = true,
    this.displayName,
    this.onTapChannel,
  });

  Widget _tappable(BuildContext context, Widget avatar) {
    final onTap = onTapChannel;
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: context.l10n.channelProfile,
      child: Tooltip(
        message: context.l10n.channelProfile,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatar,
        ),
      ),
    );
  }

  TextStyle _getBaseTextStyle(
    BuildContext context,
    double fontSize,
    FontWeight fontWeight,
  ) {
    return context.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          shadows: showTextShadows ? kOverlayShadow : null,
        ) ??
        const TextStyle();
  }

  /// The category, in the wide-tracked uppercase label shared with the stream
  /// cards, so a category reads the same wherever it appears.
  TextStyle _getCategoryTextStyle(BuildContext context) {
    return context.onsetText.label.copyWith(
      color: textColor ?? context.onsetColors.metadata,
      shadows: showTextShadows ? kOverlayShadow : null,
    );
  }

  /// Numbers the user reads — uptime and viewer count — in the monospace
  /// metadata face, so the digits stop shifting as the values tick.
  TextStyle _getMetricTextStyle(BuildContext context, double fontSize) {
    return context.onsetText.metadata.copyWith(
      fontSize: fontSize,
      color: textColor ?? context.onsetColors.metadata,
      shadows: showTextShadows ? kOverlayShadow : null,
    );
  }

  TextStyle _getSecondaryTextStyle(BuildContext context, double fontSize) {
    return context.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color:
              textColor?.withValues(alpha: 0.7) ?? context.onsetColors.metadata,
          shadows: showTextShadows ? kOverlayShadow : null,
        ) ??
        const TextStyle();
  }

  @override
  Widget build(BuildContext context) {
    final streamTitle = isOffline
        ? (offlineChannelInfo?.title.trim() ?? '')
        : (streamInfo?.title.trim() ?? '');
    final streamerName = isOffline
        ? getReadableName(
            offlineChannelInfo?.broadcasterName.isNotEmpty == true
                ? offlineChannelInfo?.broadcasterName ?? ''
                : displayName ?? '',
            offlineChannelInfo?.broadcasterLogin ?? '',
          )
        : getReadableName(
            streamInfo?.userName ?? '',
            streamInfo?.userLogin ?? '',
          );
    final secondLineSize = isCompact ? 13.0 : 14.0;

    return Padding(
      padding: padding,
      child: Row(
        spacing: 8,
        children: [
          _tappable(
            context,
            Container(
              decoration: isInSharedChatMode
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.onsetColors.live,
                        width: 1.5,
                      ),
                    )
                  : null,
              child: Padding(
                padding: isInSharedChatMode
                    ? const EdgeInsets.all(1.5)
                    : EdgeInsets.zero,
                child: ProfilePicture(
                  userLogin: isOffline
                      ? (offlineChannelInfo?.broadcasterLogin.isNotEmpty == true
                            ? offlineChannelInfo?.broadcasterLogin ?? ''
                            : displayName ?? '')
                      : (streamInfo?.userLogin ?? ''),
                  radius: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Streamer name + stream title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 4,
                  children: [
                    Tooltip(
                      message: streamerName,
                      triggerMode: tooltipTriggerMode,
                      child: Text(
                        streamerName,
                        style: _getBaseTextStyle(context, 14, FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (streamTitle.isNotEmpty) ...[
                      Flexible(
                        child: Tooltip(
                          message: streamTitle,
                          triggerMode: tooltipTriggerMode,
                          child: Text(
                            streamTitle,
                            style: _getSecondaryTextStyle(context, 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Bottom row: Live indicator, uptime, viewer count, game name or Offline text
                if (isOffline ||
                    (!isOffline && showUptime) ||
                    (!isOffline && showViewerCount) ||
                    (showCategory &&
                        (isOffline
                            ? (offlineChannelInfo?.gameName.isNotEmpty ?? false)
                            : (streamInfo?.gameName.isNotEmpty ?? false)))) ...[
                  Row(
                    children: [
                      if (isOffline && showOfflineIndicator) ...[
                        Text(
                          context.l10n.streamOffline,
                          style: _getSecondaryTextStyle(
                            context,
                            secondLineSize,
                          ),
                        ),
                      ],
                      if (isOffline &&
                          showCategory &&
                          (offlineChannelInfo?.gameName.isNotEmpty ??
                              false)) ...[
                        if (showOfflineIndicator) const SizedBox(width: 8),
                        Icon(
                          Icons.gamepad,
                          size: secondLineSize,
                          color:
                              textColor?.withValues(alpha: 0.7) ??
                              context.onsetColors.metadata,
                          shadows: showTextShadows ? kOverlayShadow : null,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Tooltip(
                            message: offlineChannelInfo?.gameName ?? '',
                            triggerMode: tooltipTriggerMode,
                            child: tappableCategory
                                ? _CategoryLink(
                                    categoryId: offlineChannelInfo?.gameId,
                                    child: Text(
                                      offlineChannelInfo?.gameName ?? '',
                                      style: _getSecondaryTextStyle(
                                        context,
                                        secondLineSize,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : Text(
                                    offlineChannelInfo?.gameName ?? '',
                                    style: _getSecondaryTextStyle(
                                      context,
                                      secondLineSize,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                      ] else ...[
                        if (!isOffline && (showUptime || showViewerCount)) ...[
                          const LiveIndicator(),
                          const SizedBox(width: 6),
                        ],
                        if (!isOffline && showUptime) ...[
                          Uptime(
                            startTime:
                                streamInfo?.startedAt ??
                                DateTime.now().toIso8601String(),
                            style: _getMetricTextStyle(context, secondLineSize),
                          ),
                          if (!isOffline && showViewerCount)
                            const SizedBox(width: 8),
                        ],
                        if (!isOffline && showViewerCount) ...[
                          Icon(
                            Icons.visibility,
                            size: secondLineSize,
                            color: textColor ?? context.onsetColors.metadata,
                            shadows: showTextShadows ? kOverlayShadow : null,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormat().format(streamInfo?.viewerCount ?? 0),
                            style: _getMetricTextStyle(context, secondLineSize),
                          ),
                        ],
                        if (!isOffline &&
                            showCategory &&
                            (streamInfo?.gameName.isNotEmpty ?? false) &&
                            (showUptime || showViewerCount)) ...[
                          const SizedBox(width: 8),
                        ],
                        if (!isOffline &&
                            showCategory &&
                            (streamInfo?.gameName.isNotEmpty ?? false)) ...[
                          Icon(
                            Icons.gamepad,
                            size: secondLineSize,
                            color: textColor ?? context.onsetColors.metadata,
                            shadows: showTextShadows ? kOverlayShadow : null,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Tooltip(
                              message: streamInfo?.gameName ?? '',
                              triggerMode: tooltipTriggerMode,
                              child: tappableCategory
                                  ? _CategoryLink(
                                      categoryId: streamInfo?.gameId,
                                      child: Text(
                                        (streamInfo?.gameName ?? '')
                                            .toUpperCase(),
                                        style: _getCategoryTextStyle(context),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Text(
                                      (streamInfo?.gameName ?? '')
                                          .toUpperCase(),
                                      style: _getCategoryTextStyle(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The category name: a double tap opens its streams (a single tap shows
/// the full name), and a screen reader opens it as a link.
class _CategoryLink extends StatelessWidget {
  const _CategoryLink({required this.categoryId, required this.child});

  final String? categoryId;
  final Widget child;

  void _open(BuildContext context) {
    final id = categoryId;
    if (id == null || id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: CategoryStreams.routeName),
        builder: (context) => CategoryStreams(categoryId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      onTap: () => _open(context),
      child: GestureDetector(onDoubleTap: () => _open(context), child: child),
    );
  }
}
