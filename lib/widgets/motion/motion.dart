import 'package:flutter/animation.dart';

/// Motion tokens of Noir & Signal 2.0 (the "Mouvement" card of the design
/// system board and the micro-animation board).
///
/// The grammar, in short:
/// - Anything the finger moves or that moves in space uses a spring, so it
///   can be interrupted and picks up from where it is.
/// - Things that enter decelerate ([emphasizedDecelerate]); things that leave
///   accelerate ([emphasizedAccelerate]) and take less time ([exit] <
///   [enter]). What enters from the right leaves by the right.
/// - Reduce motion (see `reduce_motion.dart`) turns all of it into short
///   cross-fades ([reducedFade]): no travel, no overshoot, no stagger.
abstract final class OnsetMotion {
  /// Menus, tabs, things appearing: critically damped (no bounce), 0.35 s.
  static final springStandard = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
  );

  /// After a swipe (and a press letting go): damping ratio 0.8, 0.4 s — a
  /// hint of life that carries the gesture's velocity.
  static final springMomentum = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 400),
    bounce: 0.2,
  );

  /// Entering elements.
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Leaving elements.
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Everything else that is not a spring (indicators, rings, rolls).
  static const standard = Cubic(0.2, 0, 0, 1);

  /// The launch tile settling: goes a little past its size, then lands.
  static const overshoot = Cubic(0.3, 1.5, 0.5, 1);

  /// How far a pressed card sinks, and how fast (as soon as the finger is
  /// down).
  static const pressScale = 0.97;
  static const pressDuration = Duration(milliseconds: 100);

  /// An element entering, and leaving.
  static const enter = Duration(milliseconds: 350);
  static const exit = Duration(milliseconds: 250);

  /// The cross-fade every motion becomes under reduce motion.
  static const reducedFade = Duration(milliseconds: 150);

  /// Gap between two rows of a list entering, and between two cards of the
  /// home screen entering after the launch intro.
  static const staggerStep = Duration(milliseconds: 40);
  static const launchStaggerStep = Duration(milliseconds: 60);

  /// Rows past this many enter with the last one, so a list never takes more
  /// than a few hundred milliseconds to settle.
  static const staggerCap = 8;
}
