import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/services/cache_manager.dart';

class PaintedName extends StatefulWidget {
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

  @override
  State<PaintedName> createState() => _PaintedNameState();
}

class _PaintedNameState extends State<PaintedName> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

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
      _image = null;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final url = widget.paint.imageUrl;
    if (widget.paint.kind != NamePaintKind.image || url == null) return;
    final provider =
        widget.imageProviderFor?.call(url) ??
        CachedNetworkImageProvider(
          url,
          cacheManager: CustomCacheManager.instance,
        );
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _image = info.image);
      },
      onError: (error, stackTrace) =>
          debugPrint('7TV paint image unavailable: $error'),
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
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
    super.dispose();
  }

  Shader? _shader(Rect bounds) {
    final image = _image;
    if (widget.paint.kind == NamePaintKind.image) {
      if (image == null || bounds.isEmpty) return null;
      final scale = bounds.height / image.height;
      return ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(scale, scale, 1, 1)).storage,
      );
    }
    return widget.paint.gradientShader(bounds);
  }

  @override
  Widget build(BuildContext context) {
    final paint = widget.paint;
    final waitingForImage = paint.kind == NamePaintKind.image && _image == null;
    final fill = Text(
      widget.text,
      style: widget.style.copyWith(
        color: waitingForImage
            ? paint.fallbackColor ?? widget.style.color
            : Colors.white,
      ),
    );
    final painted = waitingForImage
        ? fill
        : ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) =>
                _shader(bounds) ??
                LinearGradient(
                  colors: [
                    widget.style.color ?? Colors.white,
                    widget.style.color ?? Colors.white,
                  ],
                ).createShader(bounds),
            child: fill,
          );
    if (paint.shadows.isEmpty) return painted;
    return Stack(
      children: [
        ExcludeSemantics(
          child: Text(
            widget.text,
            style: widget.style.copyWith(
              color: Colors.transparent,
              shadows: paint.shadows,
            ),
          ),
        ),
        painted,
      ],
    );
  }
}
