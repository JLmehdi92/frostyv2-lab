import 'dart:math';

import 'package:flutter/material.dart';

/// Our own speedlines and four-point sparkles for shared trains (drawn,
/// not Twitch's image): horizontal streaks trailing towards the start
/// edge, at fixed pseudo-random spots so they never jump between frames.
class HtSpeedlinesPainter extends CustomPainter {
  const HtSpeedlinesPainter({required this.color, required this.rtl});

  final Color color;

  /// Streaks trail to the right instead.
  final bool rtl;

  static const _lines = 9;
  static const _sparkles = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = Random(7);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < _lines; i++) {
      final y = size.height * (0.1 + 0.8 * random.nextDouble());
      final length = size.width * (0.08 + 0.18 * random.nextDouble());
      final start = size.width * random.nextDouble();
      paint
        ..strokeWidth = 1 + random.nextDouble() * 1.5
        ..color = color.withValues(alpha: 0.25 + 0.5 * random.nextDouble());
      final from = rtl ? size.width - start : start;
      final to = rtl ? from + length : from - length;
      canvas.drawLine(Offset(from, y), Offset(to, y), paint);
    }
    paint.color = color;
    for (var i = 0; i < _sparkles; i++) {
      final x = size.width * (0.15 + 0.7 * random.nextDouble());
      final y = size.height * (0.2 + 0.6 * random.nextDouble());
      _sparkle(canvas, Offset(rtl ? size.width - x : x, y), 3, paint);
    }
  }

  /// A four-point star of radius [r].
  static void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final inner = r * 0.3;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + inner, c.dy - inner)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + inner, c.dy + inner)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - inner, c.dy + inner)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - inner, c.dy - inner)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HtSpeedlinesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.rtl != rtl;
}
