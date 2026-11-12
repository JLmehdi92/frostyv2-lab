import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/services/cache_manager.dart';

class PaintedName extends StatefulWidget {
  static const paintImageHeight = 64;
  static const _measureCapacity = 500;
  static final _measured = <(String, TextStyle, double), Size>{};

  final String text;
  final NamePaint paint;
  final TextStyle style;
  final ImageProvider Function(String url)? imageProviderFor;

  const PaintedName({
    super.key,
    required this.text,
    required this.paint,
    required this.style,
    this.imageProviderFor,
  });

  static Size measure(String text, TextStyle style, TextScaler scaler) {
    final key = (text, style, scaler.scale(1));
    final known = _measured.remove(key);
    if (known != null) return _measured[key] = known;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    while (_measured.length >= _measureCapacity) {
      _measured.remove(_measured.keys.first);
    }
    return _measured[key] = size;
  }

  static ImageProvider boundedPaintImage(ImageProvider image) => ResizeImage(
    image,
    height: paintImageHeight,
    policy: ResizeImagePolicy.fit,
  );

  @visibleForTesting
  static int get measuredCount => _measured.length;

  @visibleForTesting
  static void clearMeasurements() => _measured.clear();

  @override
  State<PaintedName> createState() => _PaintedNameState();
}

class _PaintedNameState extends State<PaintedName> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  ImageInfo? _info;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(PaintedName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paint.imageUrl != widget.paint.imageUrl) {
      _stopListening();
      _releaseImage();
      _resolveImage();
    }
  }

  void _resolveImage() {
    final url = widget.paint.imageUrl;
    if (widget.paint.kind != NamePaintKind.image || url == null) return;
    final provider = PaintedName.boundedPaintImage(
      widget.imageProviderFor?.call(url) ??
          CachedNetworkImageProvider(
            url,
            cacheManager: CustomCacheManager.instance,
          ),
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          _info?.dispose();
          _info = info;
          _image = info.image;
        });
      },
      onError: (error, stackTrace) =>
          debugPrint('7TV paint image unavailable: $error'),
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _releaseImage() {
    _info?.dispose();
    _info = null;
    _image = null;
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _releaseImage();
    super.dispose();
  }

  Shader? _shader(Size size) {
    final bounds = Offset.zero & size;
    if (widget.paint.kind != NamePaintKind.image) {
      return widget.paint.gradientShader(bounds);
    }
    final image = _image;
    if (image == null || bounds.isEmpty) return null;
    final scale = bounds.height / image.height;
    return ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      (Matrix4.identity()..scaleByDouble(scale, scale, 1, 1)).storage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paint = widget.paint;
    final size = PaintedName.measure(
      widget.text,
      widget.style,
      MediaQuery.textScalerOf(context),
    );
    final shader = _shader(size);
    final shadows = paint.shadows.isEmpty ? null : paint.shadows;
    return Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      style: shader == null
          ? widget.style.copyWith(
              color: paint.fallbackColor ?? widget.style.color,
              shadows: shadows,
            )
          : _withoutColor(
              widget.style,
            ).copyWith(foreground: Paint()..shader = shader, shadows: shadows),
    );
  }

  static TextStyle _withoutColor(TextStyle style) => TextStyle(
    inherit: false,
    fontFamily: style.fontFamily,
    fontFamilyFallback: style.fontFamilyFallback,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    height: style.height,
    leadingDistribution: style.leadingDistribution,
    textBaseline: style.textBaseline,
    locale: style.locale,
    fontFeatures: style.fontFeatures,
    fontVariations: style.fontVariations,
    decoration: style.decoration,
  );
}
