import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/services/cache_manager.dart';

/// A wrapper around [CachedNetworkImage] that adds custom defaults for ONSET.
class OnsetCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget Function(BuildContext, String)? placeholder;

  /// Drawn instead of the image when it cannot be loaded or decoded.
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final bool useOldImageOnUrlChange;
  final bool useFade;
  final BoxFit? fit;

  /// Decodes the image at this many pixels wide instead of its full size.
  final int? memCacheWidth;

  /// Decodes the image at this many pixels tall instead of its full size.
  /// Alone, the width follows the image's aspect ratio.
  final int? memCacheHeight;

  /// What a screen reader says for the image; it stays silent when null.
  final String? semanticLabel;

  const OnsetCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.placeholder,
    this.errorWidget,
    this.useFade = true,
    this.useOldImageOnUrlChange = false,
    this.fit,
    this.memCacheWidth,
    this.memCacheHeight,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      placeholder: placeholder,
      errorWidget: errorWidget,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      fadeOutDuration: useFade
          ? const Duration(milliseconds: 500)
          : Duration.zero,
      fadeInDuration: useFade
          ? const Duration(milliseconds: 500)
          : Duration.zero,
      fadeInCurve: Curves.easeOut,
      fadeOutCurve: Curves.easeIn,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      cacheManager: CustomCacheManager.instance,
    );
    final label = semanticLabel;
    if (label == null) return image;
    return Semantics(label: label, image: true, child: image);
  }
}
