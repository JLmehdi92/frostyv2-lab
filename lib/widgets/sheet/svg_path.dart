import 'dart:math' as math;
import 'dart:ui';

/// Reads SVG path data (`d="…"`) into a [Path]: the subset ONSET's glyphs
/// use (M L H V C S Q T A Z, absolute and relative).
///
/// The glyphs are ONSET's own 24 × 24 strokes; parsing their path
/// data keeps each glyph exact instead of a re-drawing.
/// Throws a [FormatException] on data it cannot read.
Path parseSvgPath(String data) {
  final tokens = _tokenize(data);
  final path = Path();
  var i = 0;
  var command = '';
  var current = Offset.zero;
  var start = Offset.zero;
  // The last control point, for the S and T shorthands.
  Offset? lastCubic;
  Offset? lastQuad;

  bool isCommand(String token) => _command.hasMatch(token);

  double number() {
    if (i >= tokens.length || isCommand(tokens[i])) {
      throw FormatException('Missing number in path', data);
    }
    return double.parse(tokens[i++]);
  }

  // SVG arc flags may be written with no separator ("a1 1 0 0 1 2 2" or
  // "a1 1 0 011 2 2"): the tokenizer splits numbers, a flag is one digit.
  bool flag() {
    if (i >= tokens.length) {
      throw FormatException('Missing arc flag in path', data);
    }
    final token = tokens[i];
    if (token.length > 1 && _flags.hasMatch(token)) {
      // "011" is a flag followed by the rest.
      tokens[i] = token.substring(1);
      return token[0] == '1';
    }
    return number() != 0;
  }

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      command = tokens[i++];
    } else if (command.isEmpty) {
      throw FormatException('Path data must start with a command', data);
    }
    final relative = command == command.toLowerCase();
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);

    switch (command.toUpperCase()) {
      case 'M':
        current = point(number(), number());
        start = current;
        path.moveTo(current.dx, current.dy);
        // Pairs after a moveto are linetos.
        command = relative ? 'l' : 'L';
        lastCubic = null;
        lastQuad = null;
      case 'L':
        current = point(number(), number());
        path.lineTo(current.dx, current.dy);
        lastCubic = null;
        lastQuad = null;
      case 'H':
        final x = number();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastCubic = null;
        lastQuad = null;
      case 'V':
        final y = number();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
        lastCubic = null;
        lastQuad = null;
      case 'C':
        final c1 = point(number(), number());
        final c2 = point(number(), number());
        final end = point(number(), number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        lastCubic = c2;
        lastQuad = null;
      case 'S':
        final c1 = lastCubic == null ? current : current * 2 - lastCubic;
        final c2 = point(number(), number());
        final end = point(number(), number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        lastCubic = c2;
        lastQuad = null;
      case 'Q':
        final c = point(number(), number());
        final end = point(number(), number());
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        current = end;
        lastQuad = c;
        lastCubic = null;
      case 'T':
        final c = lastQuad == null ? current : current * 2 - lastQuad;
        final end = point(number(), number());
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        current = end;
        lastQuad = c;
        lastCubic = null;
      case 'A':
        final rx = number().abs();
        final ry = number().abs();
        final rotation = number();
        final largeArc = flag();
        final sweep = flag();
        final end = point(number(), number());
        if (rx == 0 || ry == 0) {
          path.lineTo(end.dx, end.dy);
        } else {
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
        }
        current = end;
        lastCubic = null;
        lastQuad = null;
      case 'Z':
        path.close();
        current = start;
        lastCubic = null;
        lastQuad = null;
        // Z takes no numbers: one after it would be read again and again.
        if (i < tokens.length && !isCommand(tokens[i])) {
          throw FormatException('Number after closepath in path', data);
        }
      default:
        throw FormatException('Unsupported path command $command', data);
    }
  }
  return path;
}

final _command = RegExp(r'^[A-Za-z]$');
final _flags = RegExp(r'^[01]+');
final _token = RegExp(r'[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Numbers and command letters, in order. Handles "-", "." and exponent
/// joins the way SVG writes them ("1-2", "1.5.5", "2e-3").
List<String> _tokenize(String data) {
  final tokens = <String>[];
  for (final match in _token.allMatches(data)) {
    tokens.add(match.group(0)!);
  }
  return tokens;
}

/// The circle `cx cy r` of a glyph.
Path svgCircle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

/// The rounded rectangle `x y width height rx` of a glyph.
Path svgRect(double x, double y, double width, double height, double rx) =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(math.max(0, rx)),
      ),
    );

Path glyphPathOf(List<String> shapes) {
  final path = Path();
  for (final shape in shapes) {
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
}
