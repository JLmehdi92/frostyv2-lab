import 'package:flutter/widgets.dart';

/// ONSET's own celebration art (drawn for the app, never Twitch's): the gift
/// box closed and open, and the sparks of its burst.
abstract final class CelebrationArt {
  static const giftClosed = 'assets/celebrations/gift_closed.png';
  static const giftOpen = 'assets/celebrations/gift_open.png';
  static const sparkLime = 'assets/celebrations/spark_lime.png';
  static const sparkMint = 'assets/celebrations/spark_mint.png';
  static const sparkWhite = 'assets/celebrations/spark_white.png';
  static const sparkDot = 'assets/celebrations/spark_dot.png';

  /// [asset] decoded at the [size] dp it is drawn at on this screen: the
  /// files are 512 px (boxes) and 128 px (sparks), far more than a 28 dp
  /// slot needs, and a full decode would sit in the image cache for nothing.
  static ImageProvider sized(BuildContext context, String asset, double size) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return ResizeImage.resizeIfNeeded(
      (size * ratio).ceil(),
      null,
      AssetImage(asset),
    );
  }
}
