import 'package:flutter/widgets.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/widgets/sheet/svg_path.dart';

/// The icons of the recorded-video screens, read from ONSET's own 24 × 24
/// elements: round caps and joins, stroked unless filled.
enum VideoGlyphKind {
  back,
  settings,
  replay10,
  forward10,
  play,
  pause,
  replay,
  volume,
  muted,
  pip,
  fullscreen,
  exitFullscreen,
  fillScreen,
  skipBack,
  skipForward,
  playNext,
  info,
  arrowDown,
  warning,
  link,
  share,
  captions,
  speed,
  broadcast,
  loop,
  check,
  lock,
  camera,
  cameraAdd,
  clip,
  pencil,
  chevronRight,
  chevronUp,
  close,
  expand,
  alert,
  download,
}

/// The elements of each glyph: path data (`f:` when filled),
/// `c:cx,cy,r` circles and `r:x,y,w,h,rx` rectangles (`fr:` filled).
const Map<VideoGlyphKind, List<String>> _shapes = {
  VideoGlyphKind.back: ['M15 6l-6 6 6 6'],
  VideoGlyphKind.download: ['M12 4v11', 'M7 10l5 5 5-5', 'M5 19h14'],
  VideoGlyphKind.settings: [
    'M4 7h10M18 7h2M4 17h4M12 17h8',
    'c:16,7,2',
    'c:10,17,2',
  ],
  VideoGlyphKind.replay10: ['M4.6 9A8 8 0 1 1 4 12', 'M4 4.5V9h4.5'],
  VideoGlyphKind.forward10: ['M19.4 9A8 8 0 1 0 20 12', 'M20 4.5V9h-4.5'],
  VideoGlyphKind.play: ['f:M8 5v14l11-7z'],
  VideoGlyphKind.pause: ['fr:6,5,4,14,1.2', 'fr:14,5,4,14,1.2'],
  VideoGlyphKind.replay: ['M4.6 9A8 8 0 1 1 4 12', 'M4 4.5V9h4.5'],
  VideoGlyphKind.volume: ['M4 9h4l5-4v14l-5-4H4z', 'M17 9a4 4 0 0 1 0 6'],
  VideoGlyphKind.muted: ['M4 9h4l5-4v14l-5-4H4z', 'M17 9l4 6M21 9l-4 6'],
  VideoGlyphKind.pip: ['r:3,5,18,14,2', 'r:12,11,7,6,1'],
  VideoGlyphKind.fullscreen: ['M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5'],
  // The same corners turned inwards.
  VideoGlyphKind.exitFullscreen: ['M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5'],
  VideoGlyphKind.fillScreen: ['r:3,6,18,12,2', 'M7 10v4M17 10v4'],
  VideoGlyphKind.skipBack: ['f:M11 6v12l-8-6zM21 6v12l-8-6z'],
  VideoGlyphKind.skipForward: ['f:M3 6v12l8-6zM13 6v12l8-6z'],
  VideoGlyphKind.playNext: ['f:M6 5v14l10-7z', 'fr:17,5,2.4,14,1'],
  VideoGlyphKind.info: ['c:12,12,8.5', 'M12 11v5M12 8h.01'],
  VideoGlyphKind.arrowDown: ['M12 5v14M6 13l6 6 6-6'],
  VideoGlyphKind.warning: ['M12 4l9 16H3z', 'M12 10v4M12 17h.01'],
  VideoGlyphKind.link: [
    'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1',
    'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  ],
  VideoGlyphKind.share: ['M12 4v11M7 9l5-5 5 5M5 14v5h14v-5'],
  VideoGlyphKind.captions: [
    'r:3,5,18,14,3',
    'M10.5 10.2a2 2 0 1 0 0 3.6M17 10.2a2 2 0 1 0 0 3.6',
  ],
  VideoGlyphKind.speed: ['M5 17a8 8 0 1 1 14 0', 'M12 13l3.5-4'],
  VideoGlyphKind.broadcast: ['r:3,5,18,14,2', 'M10 9.5v5l4-2.5z'],
  VideoGlyphKind.loop: [
    'M17 3l3 3-3 3',
    'M4 11V9a3 3 0 0 1 3-3h13',
    'M7 21l-3-3 3-3',
    'M20 13v2a3 3 0 0 1-3 3H4',
  ],
  VideoGlyphKind.check: ['M5 12.5l4.5 4.5L19 7.5'],
  VideoGlyphKind.lock: ['r:5,11,14,9,2', 'M8 11V8a4 4 0 0 1 8 0v3'],
  VideoGlyphKind.camera: ['r:3,6,14,12,2', 'M17 10l4-2.5v9L17 14'],
  VideoGlyphKind.cameraAdd: [
    'r:3,6,14,12,2',
    'M17 10l4-2.5v9L17 14',
    'M10 9.5v5M7.5 12h5',
  ],
  VideoGlyphKind.clip: ['r:3,6,13,12,2', 'M16 10l5-3v10l-5-3z'],
  VideoGlyphKind.pencil: ['M4 20h4L19 9l-4-4L4 16z', 'M13.5 6.5l4 4'],
  VideoGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  VideoGlyphKind.chevronUp: ['M6 15l6-6 6 6'],
  VideoGlyphKind.close: ['M6 6l12 12M18 6L6 18'],
  VideoGlyphKind.expand: ['M14 4h6v6M10 20H4v-6M20 4l-7 7M4 20l7-7'],
  VideoGlyphKind.alert: ['c:12,12,8.5', 'M12 8v5M12 16h.01'],
};

/// The "10" inside the skip arrows, and where it goes.
const Map<VideoGlyphKind, double> _tenAt = {
  VideoGlyphKind.replay10: 12.6,
  VideoGlyphKind.forward10: 11.4,
};

/// A glyph's parsed elements, filled or stroked.
typedef _Shape = ({Path path, bool fill});

final Map<VideoGlyphKind, List<_Shape>> _cache = {};

List<_Shape> _shapesOf(VideoGlyphKind kind) => _cache.putIfAbsent(kind, () {
  final shapes = <_Shape>[];
  for (final shape in _shapes[kind]!) {
    if (shape.startsWith('c:')) {
      final v = shape.substring(2).split(',').map(double.parse).toList();
      shapes.add((path: svgCircle(v[0], v[1], v[2]), fill: false));
    } else if (shape.startsWith('r:') || shape.startsWith('fr:')) {
      final fill = shape.startsWith('f');
      final v = shape
          .substring(fill ? 3 : 2)
          .split(',')
          .map(double.parse)
          .toList();
      shapes.add((path: svgRect(v[0], v[1], v[2], v[3], v[4]), fill: fill));
    } else if (shape.startsWith('f:')) {
      shapes.add((path: parseSvgPath(shape.substring(2)), fill: true));
    } else {
      shapes.add((path: parseSvgPath(shape), fill: false));
    }
  }
  return shapes;
});

/// The 24 × 24 path of [kind] (stroked and filled parts together), for
/// tests and hit checks.
@visibleForTesting
Path videoGlyphPath(VideoGlyphKind kind) {
  final path = Path();
  for (final shape in _shapesOf(kind)) {
    path.addPath(shape.path, Offset.zero);
  }
  return path;
}

/// One of the video icons in [color].
class VideoGlyph extends StatelessWidget {
  const VideoGlyph(
    this.kind, {
    super.key,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.8,
    this.shadow = false,
  });

  final VideoGlyphKind kind;
  final Color color;
  final double size;
  final double strokeWidth;

  /// [kPlayerChromeShadow] under it, over a bright picture.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _VideoGlyphPainter(kind, color, strokeWidth, shadow),
        ),
      ),
    );
  }
}

class _VideoGlyphPainter extends CustomPainter {
  const _VideoGlyphPainter(
    this.kind,
    this.color,
    this.strokeWidth,
    this.shadow,
  );

  final VideoGlyphKind kind;
  final Color color;
  final double strokeWidth;
  final bool shadow;

  static final _shadowColor = kPlayerChromeShadow.first.color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    if (shadow) {
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
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = blur
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = blur
      ..isAntiAlias = true;
    for (final shape in _shapesOf(kind)) {
      canvas.drawPath(shape.path, shape.fill ? fill : stroke);
    }
    final tenX = _tenAt[kind];
    if (tenX != null) {
      // "10" at 6.6 / 700, its baseline at y 15.2.
      final painter = TextPainter(
        text: TextSpan(
          text: '10',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 6.6,
            fontWeight: FontWeight.w700,
            height: 1,
            foreground: Paint()
              ..color = color
              ..maskFilter = blur,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      painter
        ..paint(canvas, Offset(tenX - painter.width / 2, 15.2 - baseline))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_VideoGlyphPainter old) =>
      old.kind != kind ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.shadow != shadow;
}
