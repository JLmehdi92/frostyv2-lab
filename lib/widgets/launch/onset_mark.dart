import 'package:flutter/widgets.dart';
import 'package:frosty/theme.dart';

/// The ONSET mark as drawn by the launch intro and, later, the header: "ON"
/// in the signal tile.
///
/// The outline is Inter Bold Italic (the app's own font) at 32 px with
/// -0.05 em tracking, centred in a 72 × 72 box, generated once by
/// `scripts/onset_mark_glyphs.py`. The Android splash draws the very same
/// outline (`res/drawable/launch_tile.xml`, checked by a test), so the native
/// splash hands over to the Flutter intro without a visible change.
abstract final class OnsetMark {
  /// Side of the box [glyphsSvg] is drawn in.
  static const designSize = 72.0;

  /// Corner radius of the tile at [designSize].
  static const designRadius = 20.0;

  /// The "ON" outline in a 72 × 72 box, as SVG path data (absolute M, L, Q
  /// and Z only).
  static const glyphsSvg =
      'M22.33,47.95Q19.57,47.95 17.46,46.84Q15.36,45.72 14.18,43.59'
      'Q13,41.45 13,38.44Q13,35.58 13.9,32.99Q14.8,30.41 16.47,28.39'
      'Q18.14,26.38 20.5,25.21Q22.86,24.05 25.78,24.05'
      'Q28.53,24.05 30.64,25.16Q32.74,26.28 33.92,28.41'
      'Q35.1,30.53 35.1,33.56Q35.1,36.42 34.2,39.02'
      'Q33.3,41.61 31.63,43.62Q29.96,45.62 27.6,46.79'
      'Q25.25,47.95 22.33,47.95ZM22.53,43.72Q24.46,43.72 25.91,42.82'
      'Q27.36,41.92 28.34,40.44Q29.32,38.95 29.81,37.16'
      'Q30.3,35.36 30.3,33.56Q30.3,30.97 29.04,29.62'
      'Q27.78,28.28 25.6,28.28Q23.66,28.28 22.21,29.18'
      'Q20.75,30.08 19.77,31.56Q18.78,33.05 18.29,34.84'
      'Q17.8,36.64 17.8,38.42Q17.8,41.03 19.07,42.38'
      'Q20.33,43.72 22.53,43.72ZM34.97,47.64L38.83,24.36L44.11,24.36'
      'L49.5,36.14Q49.98,37.23 50.5,38.65Q51.03,40.06 51.5,41.97'
      'Q51.67,40.23 51.87,38.48Q52.08,36.72 52.28,35.53L54.12,24.36'
      'L59,24.36L55.14,47.64L49.86,47.64L44.95,36.95'
      'Q44.48,35.92 44.09,34.94Q43.7,33.95 43.31,32.8'
      'Q42.92,31.64 42.42,30.12Q42.18,32.34 41.98,34.12'
      'Q41.78,35.89 41.61,36.94L39.84,47.64Z';

  static Path? _glyphs;

  /// [glyphsSvg] as a [Path] (parsed once).
  static Path glyphs() => _glyphs ??= _parse(glyphsSvg);

  static Path _parse(String svg) {
    final path = Path();
    final commands = RegExp(r'([MLQZ])([^MLQZ]*)').allMatches(svg);
    for (final command in commands) {
      final numbers = RegExp(r'-?[0-9.]+')
          .allMatches(command.group(2)!)
          .map((m) => double.parse(m.group(0)!))
          .toList();
      switch (command.group(1)) {
        case 'M':
          path.moveTo(numbers[0], numbers[1]);
        case 'L':
          path.lineTo(numbers[0], numbers[1]);
        case 'Q':
          path.quadraticBezierTo(
            numbers[0],
            numbers[1],
            numbers[2],
            numbers[3],
          );
        case 'Z':
          path.close();
      }
    }
    return path;
  }
}

/// The signal tile with the dark "ON", at [size] (72 on the launch boards,
/// 28 in the phone header, 30 in the tablet's).
///
/// [radius], [markOpacity], [markScale] and [glow] let the launch intro
/// animate it; at rest it is the plain mark.
class OnsetMarkTile extends StatelessWidget {
  final double size;

  /// Corner radius; defaults to the board's 20 at 72, scaled to [size].
  final double? radius;

  /// The "ON" fades and grows in on the launch boards.
  final double markOpacity;
  final double markScale;

  /// The soft accent halo around the tile on the launch boards.
  final List<BoxShadow>? glow;

  const OnsetMarkTile({
    super.key,
    this.size = OnsetMark.designSize,
    this.radius,
    this.markOpacity = 1,
    this.markScale = 1,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ONSET',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FrostyTokens.accent,
            borderRadius: BorderRadius.circular(
              radius ?? OnsetMark.designRadius * size / OnsetMark.designSize,
            ),
            boxShadow: glow,
          ),
          child: markOpacity <= 0
              ? null
              : CustomPaint(
                  painter: _MarkPainter(
                    opacity: markOpacity.clamp(0.0, 1.0),
                    scale: markScale,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final double opacity;
  final double scale;

  const _MarkPainter({required this.opacity, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / OnsetMark.designSize;
    const half = OnsetMark.designSize / 2;
    canvas
      ..save()
      ..scale(unit)
      ..translate(half, half)
      ..scale(scale)
      ..translate(-half, -half)
      ..drawPath(
        OnsetMark.glyphs(),
        Paint()
          ..color = FrostyTokens.backgroundDark.withValues(alpha: opacity)
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.scale != scale;
}
