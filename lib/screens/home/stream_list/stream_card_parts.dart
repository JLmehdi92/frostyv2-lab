import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/image_size.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/motion/rolling_number.dart';
import 'package:frosty/widgets/motion/signal_ping.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The colours of the home feeds' cards (boards Accueil, TabletteAccueil,
/// Live), dark from the boards and their light counterparts.
@immutable
class FeedColors {
  final Color text;
  final Color body;
  final Color secondary;
  final Color tertiary;
  final Color surface;
  final Color raised;
  final Color hairline;
  final Color pillBorder;

  /// The image placeholder (behind a thumbnail).
  final Color well;

  const FeedColors({
    required this.text,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.pillBorder,
    required this.well,
  });

  static const dark = FeedColors(
    text: FrostyTokens.textPrimaryDark,
    body: FrostyTokens.textBodyDark,
    secondary: FrostyTokens.textSecondaryDark,
    tertiary: FrostyTokens.textTertiaryDark,
    surface: FrostyTokens.surfaceDark,
    raised: FrostyTokens.raisedDark,
    hairline: Color(0x1AFFFFFF),
    pillBorder: FrostyTokens.hairlineRaisedDark,
    well: FrostyTokens.surfaceDark,
  );

  static const light = FeedColors(
    text: Color(0xFF0A0A0A),
    body: Color(0xFF3A3A3A),
    secondary: Color(0xFF6B6B6B),
    tertiary: Color(0xFF6B6B6B),
    surface: FrostyTokens.surfaceLight,
    raised: Color(0xFFF0F0F0),
    hairline: Color(0x14000000),
    pillBorder: Color(0x1F000000),
    well: Color(0xFFEDEDED),
  );

  static FeedColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// What is drawn over a picture is always light on dark, in either theme.
abstract final class OverImage {
  static const text = FrostyTokens.textPrimaryDark;
  static const body = Color(0xFFE5E5E5);
  static const secondary = FrostyTokens.textSecondaryDark;
  static const pill = Color(0xB30A0A0A);
  static const pillStrong = Color(0xBF0A0A0A);
}

/// A viewer count as the cards show it: "2.4k" ([compact]) or "2,445".
String formatViewers(int count, {bool compact = true}) => compact
    ? NumberFormat.compact().format(count).toLowerCase()
    : NumberFormat.decimalPattern().format(count);

/// [stream]'s channel page.
Route<void> streamRoute(StreamTwitch stream) => MaterialPageRoute(
  settings: const RouteSettings(name: VideoChat.routeName),
  builder: (context) => VideoChat(
    userId: stream.userId,
    userName: stream.userName,
    userLogin: stream.userLogin,
  ),
);

/// Opens [stream]'s channel.
Future<void> openStream(BuildContext context, StreamTwitch stream) =>
    Navigator.push(context, streamRoute(stream));

/// Shows [stream]'s preview picture full screen (a long press on it).
void enlargeThumbnail(BuildContext context, StreamTwitch stream) {
  HapticFeedback.lightImpact();
  showDialog<void>(
    context: context,
    builder: (context) => FrostyPhotoViewDialog(
      // The original URL, with its {width}x{height}.
      imageUrl: stream.thumbnailUrl,
      cacheKey: StreamThumbnail.cacheKeyOf(stream, DateTime.now()),
    ),
  );
}

/// The finger is down on [stream]: its token is asked for while the page
/// opens.
void preloadStream(BuildContext context, StreamTwitch stream) =>
    PlaybackPreloader.instance.preload(
      login: stream.userLogin,
      engine: context.read<SettingsStore>().playerEngine,
      authToken: context.read<AuthStore?>()?.twitchWebToken,
    );

/// [stream]'s actions (Profile, Videos, Pin, Block, Follow on Twitch, Copy
/// link, Share, Report), after a medium haptic.
void showStreamActions(
  BuildContext context,
  StreamTwitch stream, {
  bool showPinOption = false,
  bool? isPinned,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheetWithProperFocus(
    context: context,
    builder: (context) => UserActionsModal(
      authStore: context.read<AuthStore>(),
      name: getReadableName(stream.userName, stream.userLogin),
      userLogin: stream.userLogin,
      userId: stream.userId,
      showPinOption: showPinOption,
      isPinned: isPinned,
    ),
  );
}

/// Opens the category of [stream], when it has one.
VoidCallback? openCategoryOf(BuildContext context, StreamTwitch stream) {
  if (stream.gameName.isEmpty || stream.gameId.isEmpty) return null;
  return () => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: CategoryStreams.routeName),
      builder: (context) => CategoryStreams(categoryId: stream.gameId),
    ),
  );
}

/// A stream's preview picture, requested at the size it is drawn (up to
/// 1920x1080) and refreshed every 5 minutes. With [enlarge], a long press
/// opens it full screen.
class StreamThumbnail extends StatelessWidget {
  const StreamThumbnail({
    super.key,
    required this.stream,
    this.enlarge = true,
    this.borderRadius = BorderRadius.zero,
  });

  final StreamTwitch stream;
  final bool enlarge;
  final BorderRadius borderRadius;

  /// One cache entry per 5 minutes, so the picture follows the stream.
  static String cacheKeyOf(StreamTwitch stream, DateTime now) =>
      '${stream.thumbnailUrl}-${now.day}-${now.hour}-${now.minute ~/ 5}';

  @override
  Widget build(BuildContext context) {
    final cacheKey = cacheKeyOf(stream, DateTime.now());
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final name = getReadableName(stream.userName, stream.userLogin);
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final width = imagePixelWidth(constraints.maxWidth, pixelRatio);
        final height = min(width * 9 ~/ 16, 1080);
        return FrostyCachedNetworkImage(
          imageUrl: stream.thumbnailUrl.replaceFirst(
            '-{width}x{height}',
            '-${width}x$height',
          ),
          // One cache entry per size, or a rotation would reuse a smaller
          // image.
          cacheKey: '$cacheKey-$width',
          memCacheWidth: width,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              SkeletonLoader(borderRadius: borderRadius),
          useOldImageOnUrlChange: true,
        );
      },
    );
    return Semantics(
      container: true,
      image: true,
      label: '$name stream preview',
      onLongPressHint: enlarge ? 'enlarge' : null,
      child: enlarge
          ? GestureDetector(
              onLongPress: () => enlargeThumbnail(context, stream),
              child: image,
            )
          : image,
    );
  }
}

/// The signal "LIVE" badge with its pinging dot (boards: 24 high, 11 sp;
/// [large]: 26 high, 12 sp).
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    const onAccent = FrostyTokens.backgroundDark;
    return Container(
      height: large ? 26 : 24,
      padding: EdgeInsets.symmetric(horizontal: large ? 9 : 8),
      decoration: BoxDecoration(
        color: context.frostyColors.live,
        borderRadius: BorderRadius.circular(large ? 7 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const SignalPing(size: 6, color: onAccent),
          Text(
            'LIVE',
            style: FrostyType.badge.copyWith(
              fontSize: large ? 12 : 11,
              letterSpacing: 0.06 * (large ? 12 : 11),
              color: onAccent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dark pill over a picture (viewers, uptime).
class OverlayPill extends StatelessWidget {
  const OverlayPill({
    super.key,
    required this.child,
    this.height = 24,
    this.radius = 6,
    this.padding = 8,
    this.color = OverImage.pill,
  });

  final Widget child;
  final double height;
  final double radius;
  final double padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: OverImage.text, height: 1),
        child: child,
      ),
    );
  }
}

/// The viewer pill of a thumbnail: a signal dot and the rolling count.
class ViewerPill extends StatelessWidget {
  const ViewerPill({
    super.key,
    required this.viewers,
    this.height = 20,
    this.fontSize = 11,
  });

  final int viewers;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${formatViewers(viewers, compact: false)} viewers',
      child: ExcludeSemantics(
        child: OverlayPill(
          height: height,
          radius: height >= 22 ? 6 : 5,
          padding: height >= 22 ? 7 : 6,
          color: OverImage.pillStrong,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: height >= 22 ? 6 : 5,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.frostyColors.live,
                  shape: BoxShape.circle,
                ),
              ),
              RollingNumber(
                formatViewers(viewers),
                style: FrostyType.tabular(
                  TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: OverImage.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Streak N": the viewer's running watch streak in a channel, in the
/// community green (boards Accueil, TabletteAccueil).
class StreakPill extends StatelessWidget {
  const StreakPill({
    super.key,
    required this.value,
    this.height = 24,
    this.overImage = false,
  });

  final int value;
  final double height;

  /// Drawn over a picture: the dark board colours in either theme.
  final bool overImage;

  @override
  Widget build(BuildContext context) {
    final dark = overImage || Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Watch streak $value',
      child: ExcludeSemantics(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FrostyTokens.hype.withValues(alpha: dark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: FrostyTokens.hype.withValues(alpha: 0.6),
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          child: Text(
            'Streak $value',
            maxLines: 1,
            style: FrostyType.tabular(
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
                color: dark
                    ? FrostyTokens.hypeText
                    : FrostyColors.light.subNoticeText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A channel's picture in the live ring (2 px of ground, 2 px of signal).
class RingedAvatar extends StatelessWidget {
  const RingedAvatar({
    super.key,
    required this.login,
    required this.size,
    this.ground = FrostyTokens.backgroundDark,
  });

  final String login;
  final double size;
  final Color ground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.frostyColors.live,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
        child: ProfilePicture(userLogin: login, radius: size / 2),
      ),
    );
  }
}

/// The hairline drawn inside a picture's edge (boards: inset 0.5 px,
/// white 10 %).
class InsetHairline extends StatelessWidget {
  const InsetHairline({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: FeedColors.of(context).hairline,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
    );
  }
}

/// A feed section's title ("Continue watching", "Live now 5"), 19/700.
class FeedSectionTitle extends StatelessWidget {
  const FeedSectionTitle(this.title, {super.key, this.count});

  final String title;

  /// Shown after the title in the tertiary grey, rolling when it changes.
  final int? count;

  static const style = TextStyle(
    fontFamily: FrostyTokens.displayFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 19,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final count = this.count;
    return Semantics(
      header: true,
      label: count == null ? title : '$title, $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: colors.text),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              RollingNumber(
                '$count',
                style: FrostyType.tabular(
                  style.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
