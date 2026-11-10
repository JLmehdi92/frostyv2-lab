import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/models/emotes.dart';

class FfzModifierClock extends ChangeNotifier {
  FfzModifierClock._();

  static final instance = FfzModifierClock._();

  Ticker? _ticker;
  var _seconds = 0.0;

  double get seconds => _seconds;

  bool get isTicking => _ticker?.isActive ?? false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!hasListeners) return;
    final ticker = _ticker ??= Ticker(_tick);
    if (!ticker.isActive) ticker.start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _ticker?.stop();
  }

  void _tick(Duration elapsed) {
    _seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
  }
}

class FfzModifiedEmote extends StatelessWidget {
  final int modifiers;
  final bool animate;
  final double width;
  final double height;
  final Widget child;
  final FfzModifierClock? clock;

  const FfzModifiedEmote({
    super.key,
    required this.modifiers,
    required this.animate,
    required this.width,
    required this.height,
    required this.child,
    this.clock,
  });

  bool get _moves => modifiers & FfzModifier.moving != 0;

  @override
  Widget build(BuildContext context) {
    final still =
        !animate ||
        !TickerMode.of(context) ||
        MediaQuery.disableAnimationsOf(context);
    if (still || !_moves) return frame(0);
    final ticker = clock ?? FfzModifierClock.instance;
    return AnimatedBuilder(
      animation: ticker,
      builder: (context, _) => frame(ticker.seconds),
    );
  }

  @visibleForTesting
  Widget frame(double seconds) {
    var result = child;
    final matrix = colorMatrix(modifiers, seconds);
    if (matrix != null) {
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: result,
      );
    }
    final flipX = modifiers & FfzModifier.flipX != 0;
    final flipY = modifiers & FfzModifier.flipY != 0;
    final transform = motion(modifiers, seconds, width, height)
      ..multiply(Matrix4.diagonal3Values(flipX ? -1 : 1, flipY ? -1 : 1, 1));
    if (modifiers & FfzModifier.rotate90 != 0) {
      transform.rotateZ(math.pi / 2);
    }
    if (transform.isIdentity()) return result;
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: result,
    );
  }

  static double _cycle(double seconds, double period) =>
      (seconds % period) / period;

  @visibleForTesting
  static Matrix4 motion(
    int modifiers,
    double seconds,
    double width,
    double height,
  ) {
    var dx = 0.0;
    var dy = 0.0;
    var angle = 0.0;
    if (modifiers & FfzModifier.slide != 0) {
      dx += (_cycle(seconds, 2) * 2 - 1) * width;
    }
    if (modifiers & FfzModifier.appear != 0) {
      dx += (_cycle(seconds, 2) - 1) * width;
    }
    if (modifiers & FfzModifier.disappear != 0) {
      dx += _cycle(seconds, 2) * width;
    }
    if (modifiers & FfzModifier.rotate != 0) {
      angle += _cycle(seconds, 1.5) * 2 * math.pi;
    }
    if (modifiers & FfzModifier.jam != 0) {
      angle += math.sin(_cycle(seconds, 0.6) * 2 * math.pi) * 0.25;
      dy -= math.sin(_cycle(seconds, 0.3) * math.pi).abs() * height * 0.08;
    }
    if (modifiers & FfzModifier.bounce != 0) {
      dy -= math.sin(_cycle(seconds, 0.8) * math.pi).abs() * height * 0.25;
    }
    if (modifiers & FfzModifier.hyperShake != 0) {
      dx += math.sin(seconds * 61) * 2;
      dy += math.cos(seconds * 47) * 2;
    }
    final matrix = Matrix4.translationValues(dx, dy, 0);
    if (angle != 0) matrix.rotateZ(angle);
    return matrix;
  }

  @visibleForTesting
  static List<double>? colorMatrix(int modifiers, double seconds) {
    if (modifiers & FfzModifier.tinted == 0) return null;
    var matrix = _identity;
    if (modifiers & (FfzModifier.greyscale | FfzModifier.cursed) != 0) {
      matrix = _multiply(_greyscale, matrix);
    }
    if (modifiers & FfzModifier.sepia != 0) {
      matrix = _multiply(_sepia, matrix);
    }
    if (modifiers & FfzModifier.cursed != 0) {
      matrix = _multiply(_cursedContrast, matrix);
    }
    if (modifiers & FfzModifier.hyperRed != 0) {
      matrix = _multiply(_red, matrix);
    }
    if (modifiers & FfzModifier.rainbow != 0) {
      matrix = _multiply(_hue(_cycle(seconds, 2) * 2 * math.pi), matrix);
    }
    return matrix;
  }

  static const _identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _greyscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _sepia = <double>[
    0.393,
    0.769,
    0.189,
    0,
    0,
    0.349,
    0.686,
    0.168,
    0,
    0,
    0.272,
    0.534,
    0.131,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _cursedContrast = <double>[
    1.75,
    0,
    0,
    0,
    -96,
    0,
    1.75,
    0,
    0,
    -96,
    0,
    0,
    1.75,
    0,
    -96,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _red = <double>[
    1,
    0,
    0,
    0,
    60,
    0,
    0.35,
    0,
    0,
    0,
    0,
    0,
    0.35,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static List<double> _hue(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return [
      0.213 + cos * 0.787 - sin * 0.213,
      0.715 - cos * 0.715 - sin * 0.715,
      0.072 - cos * 0.072 + sin * 0.928,
      0,
      0,
      0.213 - cos * 0.213 + sin * 0.143,
      0.715 + cos * 0.285 + sin * 0.140,
      0.072 - cos * 0.072 - sin * 0.283,
      0,
      0,
      0.213 - cos * 0.213 - sin * 0.787,
      0.715 - cos * 0.715 + sin * 0.715,
      0.072 + cos * 0.928 + sin * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _multiply(List<double> a, List<double> b) => [
    for (var row = 0; row < 4; row++)
      for (var column = 0; column < 5; column++)
        a[row * 5] * b[column] +
            a[row * 5 + 1] * b[5 + column] +
            a[row * 5 + 2] * b[10 + column] +
            a[row * 5 + 3] * b[15 + column] +
            (column == 4 ? a[row * 5 + 4] : 0),
  ];
}
