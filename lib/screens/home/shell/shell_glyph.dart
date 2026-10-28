import 'package:flutter/widgets.dart';

/// The navigation shell's icons, drawn from the boards' own 24 × 24 paths
/// (Accueil, TabletteAccueil): an outline when idle, filled when active.
enum ShellGlyphKind { home, browse, activity, search, whispers }

class ShellGlyph extends StatelessWidget {
  final ShellGlyphKind kind;
  final Color color;
  final double size;

  /// The active item's glyph is filled (the bell keeps its stroked clapper).
  final bool filled;

  /// 1.9 on the phone bar, 2 on the tablet pill, 1.8 in the header.
  final double strokeWidth;

  const ShellGlyph(
    this.kind, {
    super.key,
    required this.color,
    this.size = 22,
    this.filled = false,
    this.strokeWidth = 1.9,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _GlyphPainter(
            kind: kind,
            color: color,
            filled: filled,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final ShellGlyphKind kind;
  final Color color;
  final bool filled;
  final double strokeWidth;

  const _GlyphPainter({
    required this.kind,
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (kind) {
      case ShellGlyphKind.home:
        // M4 11l8-6 8 6v8h-5v-5H9v5H4z
        final path = Path()
          ..moveTo(4, 11)
          ..lineTo(12, 5)
          ..lineTo(20, 11)
          ..lineTo(20, 19)
          ..lineTo(15, 19)
          ..lineTo(15, 14)
          ..lineTo(9, 14)
          ..lineTo(9, 19)
          ..lineTo(4, 19)
          ..close();
        canvas.drawPath(path, filled ? fill : stroke);
      case ShellGlyphKind.browse:
        for (final origin in const [
          Offset(4, 4),
          Offset(13, 4),
          Offset(4, 13),
          Offset(13, 13),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              origin & const Size(7, 7),
              const Radius.circular(2),
            ),
            filled ? fill : stroke,
          );
        }
      case ShellGlyphKind.activity:
        // M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z, then the clapper.
        final bell = Path()
          ..moveTo(6, 16)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 16)
          ..lineTo(19.5, 18)
          ..lineTo(4.5, 18)
          ..close();
        if (filled) canvas.drawPath(bell, fill);
        canvas.drawPath(bell, stroke);
        final clapper = Path()
          ..moveTo(10, 20)
          ..arcToPoint(
            const Offset(14, 20),
            radius: const Radius.circular(2),
            clockwise: false,
          );
        canvas.drawPath(clapper, stroke);
      case ShellGlyphKind.search:
        canvas
          ..drawCircle(const Offset(11, 11), 7, stroke)
          ..drawLine(const Offset(20, 20), const Offset(16.5, 16.5), stroke);
      case ShellGlyphKind.whispers:
        // M4 5h16v11H9l-5 4z
        final path = Path()
          ..moveTo(4, 5)
          ..lineTo(20, 5)
          ..lineTo(20, 16)
          ..lineTo(9, 16)
          ..lineTo(4, 20)
          ..close();
        canvas.drawPath(path, filled ? fill : stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind ||
      old.color != color ||
      old.filled != filled ||
      old.strokeWidth != strokeWidth;
}
