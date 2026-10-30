import 'package:flutter/widgets.dart';
import 'package:onset/widgets/sheet/svg_path.dart';

/// The icons of the shared states, Activity and Whispers, read from
/// ONSET's own 24 × 24 elements: round caps and joins, stroked.
enum StateGlyphKind {
  /// No connection.
  offline,

  /// "Try again".
  retry,

  /// Something failed.
  alert,

  /// Logged out.
  account,

  /// Activity's empty state.
  bell,

  /// A go-live notification.
  live,

  /// A chat mention.
  mention,

  /// A schedule reminder.
  calendar,

  /// "Mark all as read".
  checkAll,

  /// "Remove notification".
  trash,

  /// A row that opens something, "See all".
  chevronRight,

  /// Back.
  back,

  /// A whisper the viewer sent (the preview's "You").
  reply,

  /// Send a whisper.
  send,

  /// A whisper.
  whisper,
}

/// The elements of each glyph: path data and `c:cx,cy,r` circles.
const Map<StateGlyphKind, List<String>> _shapes = {
  StateGlyphKind.offline: [
    'M3 3l18 18',
    'M8.5 16.4a5 5 0 0 1 7 0',
    'M5 12.9a10 10 0 0 1 5-2.7M14.2 10.3a10 10 0 0 1 4.8 2.6',
    'M2 9a15 15 0 0 1 4-2.5M10.6 5.1A15 15 0 0 1 22 9',
    'M12 20h.01',
  ],
  StateGlyphKind.retry: ['M20 11a8 8 0 1 0-2.3 5.7', 'M20 5v6h-6'],
  StateGlyphKind.alert: ['c:12,12,8.5', 'M12 8v5M12 16h.01'],
  StateGlyphKind.account: [
    'c:10,8,4',
    'M3 20a7 7 0 0 1 14 0',
    'M17 8l4 4M21 8l-4 4',
  ],
  StateGlyphKind.bell: [
    'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z',
    'M10 20a2 2 0 0 0 4 0',
  ],
  StateGlyphKind.live: [
    'c:12,12,2',
    'M8.5 15.5a5 5 0 0 1 0-7M15.5 8.5a5 5 0 0 1 0 7',
    'M5.6 18.4a9 9 0 0 1 0-12.8M18.4 5.6a9 9 0 0 1 0 12.8',
  ],
  StateGlyphKind.mention: [
    'c:12,12,3.5',
    'M15.5 12v1.5a2.5 2.5 0 0 0 5 0V12a8.5 8.5 0 1 0-3.3 6.7',
  ],
  StateGlyphKind.calendar: [
    'M6 5h12a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 '
        '2-2z',
    'M4 10h16M9 3v4M15 3v4',
  ],
  StateGlyphKind.checkAll: ['M3 13l4 4 8-9', 'M11.5 16.5l.5.5 9-9.5'],
  StateGlyphKind.trash: ['M5 7h14', 'M10 7V5h4v2', 'M7 7l1 12h8l1-12'],
  StateGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  StateGlyphKind.back: ['M15 6l-6 6 6 6'],
  StateGlyphKind.reply: ['M9 7l-5 5 5 5', 'M4 12h10a6 6 0 0 1 6 6v1'],
  StateGlyphKind.send: ['M4 12l16-8-6 16-2.5-6.5z', 'M11.5 13.5L20 4'],
  StateGlyphKind.whisper: ['M4 5h16v11H9l-5 4z'],
};

final Map<StateGlyphKind, Path> _cache = {};

/// The 24 × 24 path of [kind], for tests.
@visibleForTesting
Path stateGlyphPath(StateGlyphKind kind) => _pathOf(kind);

Path _pathOf(StateGlyphKind kind) => _cache.putIfAbsent(kind, () {
  final path = Path();
  for (final shape in _shapes[kind]!) {
    if (shape.startsWith('c:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      path.addPath(svgCircle(v[0], v[1], v[2]), Offset.zero);
    } else {
      path.addPath(parseSvgPath(shape), Offset.zero);
    }
  }
  return path;
});

/// One of the state icons, stroked in [color].
class StateGlyph extends StatelessWidget {
  const StateGlyph(
    this.kind, {
    super.key,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.8,
  });

  final StateGlyphKind kind;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StateGlyphPainter(kind, color, strokeWidth),
        ),
      ),
    );
  }
}

class _StateGlyphPainter extends CustomPainter {
  const _StateGlyphPainter(this.kind, this.color, this.strokeWidth);

  final StateGlyphKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24);
    canvas.drawPath(
      _pathOf(kind),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StateGlyphPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
