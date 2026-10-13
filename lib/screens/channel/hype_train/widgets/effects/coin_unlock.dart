import 'dart:math';

import 'package:flutter/material.dart';

/// The treasure discount unlocking: a gold coin flips (settling by 70%),
/// sparkles burst around it and the padlock opens.
class CoinUnlock extends StatefulWidget {
  const CoinUnlock({
    super.key,
    required this.duration,
    this.discount,
    this.reduceMotion = false,
  });

  final Duration duration;
  final int? discount;
  final bool reduceMotion;

  @override
  State<CoinUnlock> createState() => CoinUnlockState();
}

class CoinUnlockState extends State<CoinUnlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 0 → 1 over the effect.
  @visibleForTesting
  double get progress => _controller.value;

  static const _sparkles = 8;
  static const _settle = 0.7;
  static const _unlock = 0.75;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final flip = min(t / _settle, 1.0);
        final scaleX = cos(flip * 4 * pi).abs().clamp(0.08, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(scaleX, 1, 1),
                    // Painted once; the flip only transforms it.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('coin'),
                        size: const Size.square(30),
                        painter: _CoinPainter(widget.discount),
                      ),
                    ),
                  ),
                  if (t >= _settle)
                    for (var i = 0; i < _sparkles; i++)
                      _sparkle(i, (t - _settle) / (1 - _settle)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              t >= _unlock ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18,
              color: iconColor,
            ),
          ],
        );
      },
    );
  }

  Widget _sparkle(int i, double local) {
    final angle = i / _sparkles * 2 * pi;
    final distance = 14 + 10 * local;
    return Transform.translate(
      key: ValueKey('sparkle-$i'),
      offset: Offset(cos(angle) * distance, sin(angle) * distance),
      child: Opacity(
        opacity: (1 - local).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.5 + local,
          child: const Icon(
            Icons.star_rounded,
            size: 8,
            color: Color(0xFFFFE082),
          ),
        ),
      ),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter(this.discount);

  final int? discount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFB27C00)],
            stops: [0.0, 0.7, 1.0],
          ).createShader(rect),
      )
      ..drawCircle(
        center,
        radius * 0.78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFF3C4),
      );
    final text = TextPainter(
      text: TextSpan(
        text: discount == null ? '%' : '$discount%',
        style: TextStyle(
          fontSize: radius * (discount == null ? 0.9 : 0.62),
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6D4C00),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) =>
      oldDelegate.discount != discount;
}
