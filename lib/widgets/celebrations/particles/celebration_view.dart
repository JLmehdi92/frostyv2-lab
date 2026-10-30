import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/celebrations/particles/celebration_particles.dart';
import 'package:onset/widgets/celebrations/particles/celebration_sprites.dart';

/// Draws a celebration [preset] at [progress], filling the space it is given.
///
/// One [CustomPainter] repainting on [progress] — no widget per particle, no
/// ticker of its own: whoever owns [progress] owns the timing. Behind a
/// [RepaintBoundary] so a frame of particles repaints only itself, never the
/// player or the chat under it.
class CelebrationParticles extends StatefulWidget {
  final CelebrationPreset preset;
  final Animation<double> progress;
  final Duration duration;
  final int seed;

  /// A short still flash instead of moving particles.
  final bool reduceMotion;

  const CelebrationParticles({
    super.key,
    required this.preset,
    required this.progress,
    required this.duration,
    required this.seed,
    this.reduceMotion = false,
  });

  @override
  State<CelebrationParticles> createState() => _CelebrationParticlesState();
}

class _CelebrationParticlesState extends State<CelebrationParticles> {
  late CelebrationSimulation _simulation = _simulate();

  CelebrationSimulation _simulate() => CelebrationSimulation(
    preset: widget.preset,
    duration: widget.duration,
    seed: widget.seed,
    reduceMotion: widget.reduceMotion,
  );

  @override
  void initState() {
    super.initState();
    if (CelebrationSprites.images == null) {
      unawaited(
        CelebrationSprites.load().then((_) {
          // A paused or very short celebration would otherwise keep its
          // stand-in sparks until its next frame.
          if (mounted && CelebrationSprites.images != null) setState(() {});
        }),
      );
    }
  }

  @override
  void didUpdateWidget(CelebrationParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset != widget.preset ||
        oldWidget.duration != widget.duration ||
        oldWidget.seed != widget.seed ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _simulation = _simulate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: CelebrationPainter(
          simulation: _simulation,
          progress: widget.progress,
          sprites: CelebrationSprites.images,
        ),
      ),
    );
  }
}

/// Paints a [CelebrationSimulation] at the [progress] it is told.
class CelebrationPainter extends CustomPainter {
  final CelebrationSimulation simulation;
  final Animation<double> progress;
  final Map<CelebrationSprite, ui.Image>? sprites;

  CelebrationPainter({
    required this.simulation,
    required this.progress,
    required this.sprites,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final frames = simulation.frameAt(progress.value);
    if (frames.isEmpty) return;

    final unit = size.shortestSide;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // One batch per image, keyed by the image itself.
    final atlas = <ui.Image, _AtlasBatch>{};
    _AtlasBatch batch(ui.Image image) => atlas[image] ??= _AtlasBatch(image);
    final glow = CelebrationSprites.glow;
    final paint = Paint()..isAntiAlias = true;

    for (final f in frames) {
      final center = Offset(f.x * size.width, f.y * size.height);
      final extent = f.size * unit;
      if (extent <= 0) continue;

      switch (f.shape) {
        case ParticleShape.sprite:
          final image = sprites?[f.sprite];
          if (image == null) {
            _vectorSpark(canvas, paint, f, center, extent);
          } else {
            batch(image).add(f, center, extent);
          }
        case ParticleShape.rect:
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(f.rotation);
          // A confetto turning over: never quite edge-on, so it flickers
          // rather than vanishing.
          canvas.scale(1, math.max(f.flip.abs(), 0.12));
          paint
            ..style = PaintingStyle.fill
            ..shader = null
            ..color = f.color.withValues(alpha: f.opacity);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: extent,
                height: extent * f.aspect,
              ),
              Radius.circular(extent * 0.25),
            ),
            paint,
          );
          canvas.restore();
        case ParticleShape.glow:
          // The image's radius is half its width: a glow of radius [extent].
          batch(glow).add(f, center, extent * 2);
        case ParticleShape.dot:
          // An ember: a coloured halo around a hotter, paler core.
          batch(glow).add(f, center, extent * 2);
          batch(glow).add(
            ParticleFrame(
              shape: ParticleShape.glow,
              color: Color.lerp(f.color, CelebrationPalette.white, 0.6)!,
              x: f.x,
              y: f.y,
              size: f.size,
              opacity: f.opacity,
            ),
            center,
            extent * 0.7,
          );
        case ParticleShape.ring:
          paint
            ..style = PaintingStyle.stroke
            ..shader = null
            ..strokeWidth = math.max(f.stroke * unit, 0.5)
            ..color = f.color.withValues(alpha: f.opacity);
          canvas.drawCircle(center, extent, paint);
        case ParticleShape.arc:
          paint
            ..style = PaintingStyle.stroke
            ..shader = null
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(f.stroke * unit, 0.5)
            ..color = f.color.withValues(alpha: f.opacity);
          final oval = Rect.fromCircle(center: center, radius: extent);
          canvas.drawArc(oval, f.arcStart, f.arcSweep, false, paint);
          canvas.drawArc(oval, f.arcStart + math.pi, f.arcSweep, false, paint);
          paint.strokeCap = StrokeCap.butt;
        case ParticleShape.glyph:
          final glyph = _Glyphs.of(f.color, f.opacity);
          final scale = extent / _Glyphs.fontSize;
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(f.rotation);
          canvas.scale(scale);
          glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
          canvas.restore();
      }
    }

    // Sparks last, one draw call per image.
    final spritePaint = Paint()..filterQuality = FilterQuality.low;
    for (final sparks in atlas.values) {
      sparks.draw(canvas, spritePaint);
    }
    canvas.restore();
  }

  /// A four-point spark in the sprite's colour, for when the images are not
  /// decoded (yet).
  static void _vectorSpark(
    Canvas canvas,
    Paint paint,
    ParticleFrame f,
    Offset center,
    double extent,
  ) {
    final sprite = f.sprite ?? CelebrationSprite.white;
    final base =
        sprite == CelebrationSprite.white && f.color != CelebrationPalette.white
        ? f.color
        : sprite.fallback;
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = base.withValues(alpha: f.opacity);
    if (sprite == CelebrationSprite.dot) {
      canvas.drawCircle(center, extent / 2, paint);
      return;
    }
    final r = extent / 2;
    final w = r * 0.28;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(f.rotation);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(w * 0.4, -w * 0.4, r, 0)
        ..quadraticBezierTo(w * 0.4, w * 0.4, 0, r)
        ..quadraticBezierTo(-w * 0.4, w * 0.4, -r, 0)
        ..quadraticBezierTo(-w * 0.4, -w * 0.4, 0, -r)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) =>
      oldDelegate.simulation != simulation ||
      oldDelegate.progress != progress ||
      oldDelegate.sprites != sprites;
}

/// The sparks of one image, drawn in a single [Canvas.drawAtlas].
class _AtlasBatch {
  final ui.Image image;
  final transforms = <RSTransform>[];
  final rects = <Rect>[];
  final colors = <Color>[];

  _AtlasBatch(this.image);

  void add(ParticleFrame f, Offset center, double extent) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    transforms.add(
      RSTransform.fromComponents(
        rotation: f.rotation,
        scale: extent / w,
        anchorX: w / 2,
        anchorY: h / 2,
        translateX: center.dx,
        translateY: center.dy,
      ),
    );
    rects.add(Rect.fromLTWH(0, 0, w, h));
    // Multiplied into the image: white keeps its colours, another colour
    // tints it, and the alpha fades it.
    colors.add(f.color.withValues(alpha: f.opacity));
  }

  void draw(Canvas canvas, Paint paint) => canvas.drawAtlas(
    image,
    transforms,
    rects,
    colors,
    BlendMode.modulate,
    null,
    paint,
  );
}

/// The "?" of the question marks, laid out once per colour and fade step.
abstract final class _Glyphs {
  static const fontSize = 64.0;

  /// Fades are drawn in 16 steps: enough to look smooth on a particle this
  /// brief, and it keeps the cache to a few dozen laid-out glyphs.
  static const _steps = 16;
  static final _cache = <int, TextPainter>{};

  static TextPainter of(Color color, double opacity) {
    final step = (opacity.clamp(0.0, 1.0) * _steps).round();
    final key = (color.toARGB32() & 0xFFFFFF) | (step << 24);
    return _cache[key] ??= TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1,
          color: color.withValues(alpha: step / _steps),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
