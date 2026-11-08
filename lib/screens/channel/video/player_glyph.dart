import 'package:flutter/widgets.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';

/// The live player's icons, drawn from ONSET's own 24 × 24 paths: stroked,
/// round caps and joins, like the rest of ONSET's chrome.
enum PlayerGlyphKind {
  back,
  clip,
  videos,
  settings,
  chatBubble,
  sidebar,
  fillScreen,
  play,
  pause,
  volume,
  muted,
  pip,
  refresh,
  rotate,
  fullscreen,
  more,
  emote,
  send,
  headphones,
  eye,
  eyeOff,
  close,
  share,
}

class PlayerGlyph extends StatelessWidget {
  final PlayerGlyphKind kind;
  final Color color;
  final double size;
  final double strokeWidth;

  /// [kPlayerChromeShadow], so a glyph reads over a bright picture where
  /// the scrim is thin.
  final bool shadow;

  const PlayerGlyph(
    this.kind, {
    super.key,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.8,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlayerGlyphPainter(
            kind: kind,
            color: color,
            strokeWidth: strokeWidth,
            shadow: shadow,
          ),
        ),
      ),
    );
  }
}

class _PlayerGlyphPainter extends CustomPainter {
  final PlayerGlyphKind kind;
  final Color color;
  final double strokeWidth;
  final bool shadow;

  const _PlayerGlyphPainter({
    required this.kind,
    required this.color,
    required this.strokeWidth,
    required this.shadow,
  });

  static final _shadowColor = kPlayerChromeShadow.first.color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    if (shadow) {
      // 1 px down, 2 px of blur.
      canvas
        ..save()
        ..translate(0, 1)
        ..scale(scale);
      _draw(
        canvas,
        _shadowColor,
        blur: const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      canvas.restore();
    }
    canvas
      ..save()
      ..scale(scale);
    _draw(canvas, color);
    canvas.restore();
  }

  void _draw(Canvas canvas, Color color, {MaskFilter? blur}) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..maskFilter = blur
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = blur
      ..isAntiAlias = true;

    RRect box(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    switch (kind) {
      case PlayerGlyphKind.back:
        // M6 9l6 6 6-6
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..lineTo(12, 15)
            ..lineTo(18, 9),
          stroke,
        );
      case PlayerGlyphKind.clip:
        canvas
          ..drawRRect(box(3, 6, 13, 12, 2), stroke)
          ..drawPath(
            Path()
              ..moveTo(16, 10)
              ..lineTo(21, 7)
              ..lineTo(21, 17)
              ..lineTo(16, 14)
              ..close(),
            stroke,
          );
      case PlayerGlyphKind.videos:
        canvas
          ..drawRRect(box(3.5, 7, 17, 12, 2), stroke)
          ..drawLine(const Offset(7, 4), const Offset(17, 4), stroke)
          ..drawPath(
            Path()
              ..moveTo(10.5, 10.5)
              ..lineTo(14.5, 13)
              ..lineTo(10.5, 15.5)
              ..close(),
            stroke,
          );
      case PlayerGlyphKind.settings:
        canvas
          ..drawLine(const Offset(4, 7), const Offset(14, 7), stroke)
          ..drawLine(const Offset(18, 7), const Offset(20, 7), stroke)
          ..drawLine(const Offset(4, 17), const Offset(8, 17), stroke)
          ..drawLine(const Offset(12, 17), const Offset(20, 17), stroke)
          ..drawCircle(const Offset(16, 7), 2, stroke)
          ..drawCircle(const Offset(10, 17), 2, stroke);
      case PlayerGlyphKind.chatBubble:
        // M4 5h16v11H9l-5 4z
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(20, 5)
            ..lineTo(20, 16)
            ..lineTo(9, 16)
            ..lineTo(4, 20)
            ..close(),
          stroke,
        );
      case PlayerGlyphKind.sidebar:
        canvas
          ..drawRRect(box(3, 5, 18, 14, 2), stroke)
          ..drawLine(const Offset(15, 5), const Offset(15, 19), stroke);
      case PlayerGlyphKind.fillScreen:
        // The four rounded corners of the "Fill screen".
        final corners = Path()
          ..moveTo(8, 3)
          ..lineTo(5, 3)
          ..arcToPoint(
            const Offset(3, 5),
            radius: const Radius.circular(2),
            clockwise: false,
          )
          ..lineTo(3, 8)
          ..moveTo(21, 8)
          ..lineTo(21, 5)
          ..arcToPoint(
            const Offset(19, 3),
            radius: const Radius.circular(2),
            clockwise: false,
          )
          ..lineTo(16, 3)
          ..moveTo(3, 16)
          ..lineTo(3, 19)
          ..arcToPoint(
            const Offset(5, 21),
            radius: const Radius.circular(2),
            clockwise: false,
          )
          ..lineTo(8, 21)
          ..moveTo(16, 21)
          ..lineTo(19, 21)
          ..arcToPoint(
            const Offset(21, 19),
            radius: const Radius.circular(2),
            clockwise: false,
          )
          ..lineTo(21, 16);
        canvas.drawPath(corners, stroke);
      case PlayerGlyphKind.play:
        final triangle = Path()
          ..moveTo(8, 5.5)
          ..lineTo(18.5, 12)
          ..lineTo(8, 18.5)
          ..close();
        canvas
          ..drawPath(triangle, fill)
          ..drawPath(triangle, stroke);
      case PlayerGlyphKind.pause:
        canvas
          ..drawLine(const Offset(8, 5), const Offset(8, 19), stroke)
          ..drawLine(const Offset(16, 5), const Offset(16, 19), stroke);
      case PlayerGlyphKind.volume:
        canvas
          ..drawPath(_speaker, stroke)
          // M17 9a4 4 0 0 1 0 6
          ..drawPath(
            Path()
              ..moveTo(17, 9)
              ..arcToPoint(
                const Offset(17, 15),
                radius: const Radius.circular(4),
              ),
            stroke,
          );
      case PlayerGlyphKind.muted:
        canvas
          ..drawPath(_speaker, stroke)
          ..drawLine(const Offset(17, 9.5), const Offset(21, 14.5), stroke)
          ..drawLine(const Offset(21, 9.5), const Offset(17, 14.5), stroke);
      case PlayerGlyphKind.pip:
        canvas
          ..drawRRect(box(3, 5, 18, 14, 2), stroke)
          ..drawRRect(box(12, 11, 7, 6, 1), stroke);
      case PlayerGlyphKind.refresh:
        // M20 11a8 8 0 1 0-2.3 5.7 + the arrow head M20 5v6h-6
        final arc = Path()
          ..moveTo(20, 11)
          ..arcToPoint(
            const Offset(17.7, 16.7),
            radius: const Radius.circular(8),
            largeArc: true,
            clockwise: false,
          );
        canvas
          ..drawPath(arc, stroke)
          ..drawPath(
            Path()
              ..moveTo(20, 5)
              ..lineTo(20, 11)
              ..lineTo(14, 11),
            stroke,
          );
      case PlayerGlyphKind.rotate:
        canvas
          ..drawRRect(box(8.5, 6.5, 7, 11, 1.5), stroke)
          ..drawPath(
            Path()
              ..moveTo(3.5, 10)
              ..arcToPoint(
                const Offset(9.5, 3.8),
                radius: const Radius.circular(8.8),
              )
              ..moveTo(20.5, 14)
              ..arcToPoint(
                const Offset(14.5, 20.2),
                radius: const Radius.circular(8.8),
              )
              ..moveTo(7, 3.4)
              ..lineTo(9.5, 3.8)
              ..lineTo(8.9, 6.2)
              ..moveTo(17, 20.6)
              ..lineTo(14.5, 20.2)
              ..lineTo(15.1, 17.8),
            stroke,
          );
      case PlayerGlyphKind.fullscreen:
        canvas.drawPath(
          Path()
            ..moveTo(4, 9)
            ..lineTo(4, 4)
            ..lineTo(9, 4)
            ..moveTo(20, 9)
            ..lineTo(20, 4)
            ..lineTo(15, 4)
            ..moveTo(4, 15)
            ..lineTo(4, 20)
            ..lineTo(9, 20)
            ..moveTo(20, 15)
            ..lineTo(20, 20)
            ..lineTo(15, 20),
          stroke,
        );
      case PlayerGlyphKind.more:
        for (final x in const [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(x, 12), 1.4, fill);
        }
      case PlayerGlyphKind.emote:
        canvas
          ..drawCircle(const Offset(12, 12), 8, stroke)
          ..drawPath(
            Path()
              ..moveTo(9, 14.5)
              ..cubicTo(10.6, 15.9, 13.4, 15.9, 15, 14.5),
            stroke,
          )
          ..drawCircle(const Offset(9.5, 10), strokeWidth / 2 + 0.1, fill)
          ..drawCircle(const Offset(14.5, 10), strokeWidth / 2 + 0.1, fill);
      case PlayerGlyphKind.send:
        canvas
          ..drawPath(
            Path()
              ..moveTo(5, 12)
              ..lineTo(19, 5)
              ..lineTo(14, 19)
              ..lineTo(11.5, 13.5)
              ..close(),
            stroke,
          )
          ..drawLine(const Offset(11.5, 13.5), const Offset(19, 5), stroke);
      case PlayerGlyphKind.headphones:
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 15)
              ..lineTo(4, 12)
              ..arcToPoint(
                const Offset(20, 12),
                radius: const Radius.circular(8),
              )
              ..lineTo(20, 15),
            stroke,
          )
          ..drawRRect(box(3.5, 14, 4, 6, 1.5), stroke)
          ..drawRRect(box(16.5, 14, 4, 6, 1.5), stroke);
      case PlayerGlyphKind.eye:
        canvas
          ..drawPath(
            Path()
              ..moveTo(2.5, 12)
              ..quadraticBezierTo(12, 1, 21.5, 12)
              ..quadraticBezierTo(12, 23, 2.5, 12)
              ..close(),
            stroke,
          )
          ..drawCircle(const Offset(12, 12), 2.6, stroke);
      case PlayerGlyphKind.eyeOff:
        canvas
          ..drawLine(const Offset(4, 4), const Offset(20, 20), stroke)
          ..drawPath(
            Path()
              ..moveTo(10.6, 6.1)
              ..quadraticBezierTo(11.3, 6, 12, 6)
              ..cubicTo(18, 6, 21.5, 12, 21.5, 12)
              ..quadraticBezierTo(20.3, 13.9, 18.8, 15.3)
              ..moveTo(6.4, 7.6)
              ..cubicTo(3.9, 9.3, 2.5, 12, 2.5, 12)
              ..cubicTo(2.5, 12, 6, 18, 12, 18)
              ..quadraticBezierTo(14.2, 18, 16.1, 17),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(9.9, 10)
              ..arcToPoint(
                const Offset(13.7, 13.6),
                radius: const Radius.circular(2.6),
                clockwise: false,
              ),
            stroke,
          );
      case PlayerGlyphKind.share:
        canvas
          ..drawLine(const Offset(12, 4), const Offset(12, 15), stroke)
          ..drawPath(
            Path()
              ..moveTo(7, 9)
              ..lineTo(12, 4)
              ..lineTo(17, 9),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(5, 14)
              ..lineTo(5, 19)
              ..lineTo(19, 19)
              ..lineTo(19, 14),
            stroke,
          );
      case PlayerGlyphKind.close:
        canvas
          ..drawLine(const Offset(6, 6), const Offset(18, 18), stroke)
          ..drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
    }
  }

  /// M4 9h4l5-4v14l-5-4H4z
  static final Path _speaker = Path()
    ..moveTo(4, 9)
    ..lineTo(8, 9)
    ..lineTo(13, 5)
    ..lineTo(13, 19)
    ..lineTo(8, 15)
    ..lineTo(4, 15)
    ..close();

  @override
  bool shouldRepaint(_PlayerGlyphPainter old) =>
      old.kind != kind ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.shadow != shadow;
}
