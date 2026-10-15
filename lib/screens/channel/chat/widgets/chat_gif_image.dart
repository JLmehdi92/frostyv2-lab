import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frosty/cache_manager.dart';
import 'package:frosty/models/chat_gif.dart';
import 'package:frosty/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:frosty/widgets/first_frame_image.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// A GIF sent in chat, drawn like the Twitch app draws it: a fixed height,
/// the width of its own aspect ratio (never wider than the line), an empty
/// square while it loads, and its [title] read out by screen readers.
///
/// When it cannot be loaded, its [title] is shown instead (Twitch leaves a
/// blank square).
class ChatGifImage extends StatelessWidget {
  const ChatGifImage({
    super.key,
    required this.gif,
    required this.title,
    this.animate = true,
    this.height,
    this.textStyle,
    this.onTap,
  });

  /// The height Twitch gives a chat GIF, in logical pixels.
  static const defaultHeight = 128.0;

  /// The height in landscape and in the chat drawn over the video.
  static const compactHeight = 72.0;

  final ChatGif gif;

  /// The text the GIF stands for in the message.
  final String title;

  /// False draws only the first frame.
  final bool animate;

  /// Overrides the chat height (the details sheet draws it smaller).
  final double? height;

  /// The style of [title] when it is drawn instead of the GIF.
  final TextStyle? textStyle;

  final VoidCallback? onTap;

  /// The height of a chat GIF where [context] is.
  static double heightFor(BuildContext context) =>
      OverlayChatScope.of(context) ||
          MediaQuery.orientationOf(context) == Orientation.landscape
      ? compactHeight
      : defaultHeight;

  @override
  Widget build(BuildContext context) {
    final height = this.height ?? heightFor(context);
    // Decoded at the drawn height: a big GIF is not kept at full size.
    final cacheHeight = (height * MediaQuery.devicePixelRatioOf(context))
        .round();
    final placeholder = SizedBox.square(dimension: height);
    final fallback = Text(title, style: textStyle);

    final Widget image;
    if (animate) {
      image = FrostyCachedNetworkImage(
        imageUrl: gif.url,
        height: height,
        fit: BoxFit.contain,
        memCacheHeight: cacheHeight,
        useFade: false,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => fallback,
        semanticLabel: title,
      );
    } else {
      image = Image(
        image: FirstFrameImage(
          ResizeImage(
            CachedNetworkImageProvider(
              gif.url,
              cacheManager: CustomCacheManager.instance,
            ),
            height: cacheHeight,
          ),
        ),
        height: height,
        fit: BoxFit.contain,
        semanticLabel: title,
        frameBuilder: (_, child, frame, _) =>
            frame == null ? placeholder : child,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final onTap = this.onTap;
    if (onTap == null) return image;
    return InkWell(onTap: onTap, child: image);
  }
}
