import 'package:flutter/widgets.dart';
import 'package:onset/widgets/sheet/svg_path.dart';

/// The icons of the profile and settings screens, drawn from the boards' own
/// 24 × 24 strokes (Moi, MoiDeconnecte, Parametres, ParametresTablette,
/// MiseAJour): round caps and joins.
enum SettingsGlyphKind {
  general,
  video,
  chat,
  bell,
  other,
  user,
  ban,
  shield,
  link,
  logout,
  update,
  notes,
  cache,
  reset,
  code,
  filter,
  mute,
  chevronRight,
  chevronLeft,
  chevronDown,
  external,
  lock,
  check,
  dice,
  calendar,
  play,
  search,
  anonymous,
  error,
  reconnect,
  trash,
}

/// The board's elements of each glyph: path data, `c:cx,cy,r` circles and
/// `r:x,y,w,h,rx` rectangles.
const Map<SettingsGlyphKind, List<String>> _shapes = {
  SettingsGlyphKind.general: [
    'c:12,12,3',
    'M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 '
        '0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 '
        '0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 '
        '0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 '
        '1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 '
        '0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 '
        '1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 '
        '0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 '
        '0-1.5 1z',
  ],
  SettingsGlyphKind.video: ['r:3,5,18,12,2', 'M8 21h8M12 17v4'],
  SettingsGlyphKind.chat: ['M4 5h16v11H9l-5 4z'],
  SettingsGlyphKind.bell: [
    'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z',
    'M10 20a2 2 0 0 0 4 0',
  ],
  SettingsGlyphKind.other: ['c:12,12,9', 'M12 11v5M12 8h.01'],
  SettingsGlyphKind.user: ['c:12,8,4', 'M4 21a8 8 0 0 1 16 0'],
  SettingsGlyphKind.ban: ['c:12,12,9', 'M5.6 5.6l12.8 12.8'],
  SettingsGlyphKind.shield: ['M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z'],
  SettingsGlyphKind.link: [
    'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1',
    'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  ],
  SettingsGlyphKind.logout: [
    'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
    'M16 17l5-5-5-5M21 12H9',
  ],
  SettingsGlyphKind.update: ['M12 4v11M7 10l5 5 5-5M5 20h14'],
  SettingsGlyphKind.notes: ['M6 3h8l4 4v14H6z', 'M14 3v4h4M9 12h6M9 16h6'],
  SettingsGlyphKind.cache: ['r:3,4,18,16,2', 'c:9,10,2', 'M21 16l-5-5-9 9'],
  SettingsGlyphKind.reset: ['M3 12a9 9 0 1 0 3-6.7L3 8', 'M3 3v5h5'],
  SettingsGlyphKind.code: ['M8 8l-4 4 4 4M16 8l4 4-4 4M14 5l-4 14'],
  SettingsGlyphKind.filter: ['M4 5h16l-6 7v6l-4 2v-8z'],
  SettingsGlyphKind.mute: ['M4 5h16v11H9l-5 4z', 'M9 9l6 4M15 9l-6 4'],
  SettingsGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  SettingsGlyphKind.chevronLeft: ['M15 6l-6 6 6 6'],
  SettingsGlyphKind.chevronDown: ['M6 9l6 6 6-6'],
  SettingsGlyphKind.external: [
    'M14 4h6v6M20 4l-9 9',
    'M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5',
  ],
  SettingsGlyphKind.lock: ['r:5,11,14,9,2', 'M8 11V8a4 4 0 0 1 8 0v3'],
  SettingsGlyphKind.check: ['M5 12.5l4.5 4.5L19 7.5'],
  SettingsGlyphKind.dice: [
    'r:4,4,16,16,3.5',
    'c:9,9,1.3',
    'c:15,15,1.3',
    'c:15,9,1.3',
    'c:9,15,1.3',
  ],
  SettingsGlyphKind.calendar: ['r:4,5,16,15,2', 'M4 10h16M9 3v4M15 3v4'],
  SettingsGlyphKind.play: ['M7 4v16l13-8z'],
  SettingsGlyphKind.search: ['c:11,11,7', 'M20 20l-3.5-3.5'],
  SettingsGlyphKind.anonymous: [
    'c:10,8,4',
    'M3 21a7 7 0 0 1 13-3.6',
    'M17 15l4 4M21 15l-4 4',
  ],
  SettingsGlyphKind.error: ['c:12,12,9', 'M12 7.5v5.5M12 16.5h.01'],
  SettingsGlyphKind.trash: [
    'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
  ],
  SettingsGlyphKind.reconnect: [
    'M20 11a8 8 0 0 0-14.6-4.5L3 9',
    'M3 4v5h5',
    'M4 13a8 8 0 0 0 14.6 4.5L21 15',
    'M21 20v-5h-5',
  ],
};

/// The glyphs drawn filled instead of stroked.
const _filled = {SettingsGlyphKind.play};

/// Parsed once per glyph.
final Map<SettingsGlyphKind, Path> _cache = {};

/// The 24 × 24 path of [kind].
Path settingsGlyphPath(SettingsGlyphKind kind) => _cache.putIfAbsent(kind, () {
  final path = Path();
  for (final shape in _shapes[kind]!) {
    if (shape.startsWith('c:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      path.addPath(svgCircle(v[0], v[1], v[2]), Offset.zero);
    } else if (shape.startsWith('r:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      path.addPath(svgRect(v[0], v[1], v[2], v[3], v[4]), Offset.zero);
    } else {
      path.addPath(parseSvgPath(shape), Offset.zero);
    }
  }
  return path;
});

/// One of the boards' profile and settings icons, stroked in [color].
class SettingsGlyph extends StatelessWidget {
  const SettingsGlyph(
    this.kind, {
    super.key,
    this.color,
    this.size = 18,
    this.strokeWidth = 1.9,
  });

  final SettingsGlyphKind kind;

  /// The surrounding [IconTheme]'s colour when null.
  final Color? color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFFF5F5F5);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SettingsGlyphPainter(kind, color, strokeWidth),
        ),
      ),
    );
  }
}

class _SettingsGlyphPainter extends CustomPainter {
  const _SettingsGlyphPainter(this.kind, this.color, this.strokeWidth);

  final SettingsGlyphKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final fill = _filled.contains(kind);
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(
        settingsGlyphPath(kind),
        Paint()
          ..color = color
          ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SettingsGlyphPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
