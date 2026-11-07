import 'package:flutter/widgets.dart';
import 'package:onset/widgets/sheet/svg_path.dart';

/// The icons of the channel screen's sheets, menus and panels, drawn from
/// ONSET's own 24 × 24 strokes: round caps and joins, 1.8 wide unless a
/// glyph says otherwise.
enum SheetGlyphKind {
  emote,
  trash,
  clearChat,
  copy,
  paste,
  link,
  external,
  reply,
  whisper,
  profile,
  more,
  videos,
  block,
  bell,
  heart,
  share,
  flag,
  timer,
  unban,
  warn,
  chevronDown,
  chevronRight,
  chevronLeft,
  hourglass,
  star,
  unique,
  check,
  close,
  refresh,
  plug,
  palette,
  coin,
  gift,
  shield,
  rules,
  people,
  addChat,
  settings,
  monitor,
  filter,
  flame,
  trophy,
  poll,
  pin,
  cake,
  diamond,
  lock,
  contrast,
}

/// The elements of each glyph: path data, `c:cx,cy,r` circles and
/// `r:x,y,w,h,rx` rectangles.
const Map<SheetGlyphKind, List<String>> _shapes = {
  SheetGlyphKind.emote: [
    'c:12,12,8',
    'M9 14.5c1.6 1.4 4.4 1.4 6 0',
    'M9.5 10h.01M14.5 10h.01',
  ],
  SheetGlyphKind.trash: ['M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12'],
  SheetGlyphKind.clearChat: [
    'M4 7h10M10 7V5h4v2M6 7l1 12h7l1-6',
    'M16 14l5 5M21 14l-5 5',
  ],
  SheetGlyphKind.copy: ['r:9,9,11,11,2', 'M5 15V6a1 1 0 0 1 1-1h9'],
  SheetGlyphKind.paste: ['r:6,4.5,12,16,2', 'M9.5 3.5h5v3h-5z'],
  SheetGlyphKind.link: [
    'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1',
    'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  ],
  SheetGlyphKind.external: [
    'M14 4h6v6M20 4l-9 9',
    'M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5',
  ],
  SheetGlyphKind.reply: ['M10 8L5 12l5 4', 'M5 12h9a5 5 0 0 1 5 5v1'],
  SheetGlyphKind.whisper: ['M4 5h16v11H9l-5 4z'],
  SheetGlyphKind.profile: [
    'c:12,12,9',
    'c:12,10,3',
    'M6.6 18.2c1.4-2.1 3.3-3.1 5.4-3.1s4 1 5.4 3.1',
  ],
  SheetGlyphKind.more: ['c:5,12,1.4', 'c:12,12,1.4', 'c:19,12,1.4'],
  SheetGlyphKind.videos: [
    'r:3.5,7,17,12,2',
    'M7 4h10',
    'M10.5 10.5l4 2.5-4 2.5z',
  ],
  SheetGlyphKind.block: ['c:12,12,8.5', 'M6 6l12 12'],
  SheetGlyphKind.bell: [
    'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z',
    'M10 20a2 2 0 0 0 4 0',
  ],
  SheetGlyphKind.heart: [
    'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z',
  ],
  SheetGlyphKind.share: ['M12 4v11M7 9l5-5 5 5M5 14v5h14v-5'],
  SheetGlyphKind.flag: ['M5 21V4h11l-1.5 4L16 12H5'],
  SheetGlyphKind.timer: ['c:12,13,7.5', 'M12 13V9.5M10 2.5h4'],
  SheetGlyphKind.unban: ['M9 14L4 9l5-5', 'M4 9h11a5 5 0 0 1 0 10h-3'],
  SheetGlyphKind.warn: ['M12 4l9 16H3z', 'M12 10v4M12 17h.01'],
  SheetGlyphKind.chevronDown: ['M6 9l6 6 6-6'],
  SheetGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  SheetGlyphKind.chevronLeft: ['M15 6l-6 6 6 6'],
  SheetGlyphKind.hourglass: [
    'M7 3h10M7 21h10',
    'M8 3c0 5 8 5 8 9s-8 4-8 9M16 3c0 5-8 5-8 9s8 4 8 9',
  ],
  SheetGlyphKind.star: [
    'M12 4l2.4 5 5.6.7-4.1 3.8 1 5.5L12 16.4 7.1 19l1-5.5L4 9.7 9.6 9z',
  ],
  SheetGlyphKind.unique: [
    'c:12,12,8.5',
    'M9.6 9.6a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.4M12 16.5h.01',
  ],
  SheetGlyphKind.check: ['M5 12.5l4.5 4.5L19 7.5'],
  SheetGlyphKind.close: ['M6 6l12 12M18 6L6 18'],
  SheetGlyphKind.refresh: [
    'M19.5 11a7.5 7.5 0 0 0-13.4-3.6L4.5 9',
    'M4.5 4.5V9H9',
    'M4.5 13a7.5 7.5 0 0 0 13.4 3.6l1.6-1.6',
    'M19.5 19.5V15H15',
  ],
  SheetGlyphKind.plug: ['M9 3v4M15 3v4M7 7h10v4a5 5 0 0 1-10 0z', 'M12 16v5'],
  SheetGlyphKind.palette: [
    'M12 3a9 9 0 1 0 0 18c1.2 0 1.8-.9 1.4-2-.5-1.3.3-2.5 1.7-2.5H17a4 4 0 0 0 '
        '4-4c0-5-4-9.5-9-9.5z',
    'M7.5 11.5h.01M10 7.5h.01M14.5 7.5h.01',
  ],
  SheetGlyphKind.coin: [
    'c:12,12,8.5',
    'M14.5 9.5a2.5 2 0 0 0-2.5-1.5c-1.4 0-2.5.8-2.5 2s1.1 1.6 2.5 2 2.5.8 '
        '2.5 2-1.1 2-2.5 2a2.5 2 0 0 1-2.5-1.5M12 6.5V8M12 16v1.5',
  ],
  SheetGlyphKind.gift: [
    'r:4,9,16,4,1',
    'M5.5 13v7h13v-7M12 9v11',
    'M12 9c-1-3-5.5-4-5.5-1.5S10 9 12 9zM12 9c1-3 5.5-4 5.5-1.5S14 9 12 9z',
  ],
  SheetGlyphKind.shield: ['M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z'],
  SheetGlyphKind.rules: [
    'M6 4h10a3 3 0 0 1 3 3v13H9a3 3 0 0 1-3-3z',
    'M6 17a3 3 0 0 1 3-3h10M10 8h5',
  ],
  SheetGlyphKind.people: [
    'c:9,8.5,3.2',
    'M3.5 19c.8-3 3-4.5 5.5-4.5s4.7 1.5 5.5 4.5',
    'M16 5.4a3 3 0 0 1 0 5.6',
    'M17.5 14.6c1.6.6 2.7 2.1 3 4.4',
  ],
  SheetGlyphKind.addChat: ['M4 5h16v11H9l-5 4z', 'M12 8v5M9.5 10.5h5'],
  SheetGlyphKind.settings: [
    'c:12,12,3',
    'M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 '
        '0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 '
        '0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 '
        '0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 '
        '1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 '
        '0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 '
        '1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 '
        '0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 '
        '0-1.5 1z',
  ],
  SheetGlyphKind.monitor: ['r:3,5,18,12,2', 'M8 21h8M12 17v4'],
  SheetGlyphKind.filter: ['M4 7h16M7 12h10M10 17h4'],
  SheetGlyphKind.flame: [
    'M12 3c.8 3 4.5 4.6 4.5 9a4.5 4.5 0 0 1-9 0c0-2.2 1-3.6 2.2-4.6.1 2 1 '
        '3.2 2.3 3.3-.4-3 .2-5.3 0-7.7z',
  ],
  SheetGlyphKind.trophy: [
    'M8 4h8v5a4 4 0 0 1-8 0z',
    'M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8.5 20h7',
  ],
  SheetGlyphKind.poll: ['M5 20V11M12 20V4M19 20v-6'],
  SheetGlyphKind.pin: ['M9 4h6l-1 6 3 3H7l3-3z', 'M12 13v7'],
  SheetGlyphKind.cake: [
    'M4 20h16M5 20v-7h14v7',
    'M5 16.5c2 0 2-1.6 3.5-1.6S10 16.5 12 16.5s2-1.6 3.5-1.6 1.5 1.6 3.5 1.6',
    'M12 13V9.5M12 6.5v.01',
  ],
  SheetGlyphKind.diamond: ['M12 3l7.5 7.5L12 21 4.5 10.5z', 'M4.5 10.5h15'],
  SheetGlyphKind.lock: ['r:6,11,12,9,2', 'M9 11V8a3 3 0 0 1 6 0v3'],
  SheetGlyphKind.contrast: ['c:12,12,8', 'M12 4v16', 'M12 8h4M12 12h6M12 16h4'],
};

/// Parsed once per glyph.
final Map<SheetGlyphKind, Path> _cache = {};

/// The 24 × 24 path of [kind].
Path sheetGlyphPath(SheetGlyphKind kind) => _cache.putIfAbsent(kind, () {
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

/// One of the sheet icons, stroked in [color].
class SheetGlyph extends StatelessWidget {
  const SheetGlyph(
    this.kind, {
    super.key,
    this.color,
    this.size = 20,
    this.strokeWidth = 1.8,
  });

  final SheetGlyphKind kind;

  /// The icon colour of the surrounding [IconTheme] when null.
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
          painter: _SheetGlyphPainter(kind, color, strokeWidth),
        ),
      ),
    );
  }
}

class _SheetGlyphPainter extends CustomPainter {
  const _SheetGlyphPainter(this.kind, this.color, this.strokeWidth);

  final SheetGlyphKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas
      ..save()
      ..scale(scale);
    canvas.drawPath(
      sheetGlyphPath(kind),
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
  bool shouldRepaint(_SheetGlyphPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
