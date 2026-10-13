import 'dart:math';

import 'package:flutter/material.dart';

/// Community emotes unlocking: a rocket climbs a curve from bottom left to
/// top right with a flame trail, bursting into a star at the top.
class RocketLaunch extends StatefulWidget {
  const RocketLaunch({
    super.key,
    required this.duration,
    this.reduceMotion = false,
  });

  final Duration duration;
  final bool reduceMotion;

  @override
  State<RocketLaunch> createState() => _RocketLaunchState();
}

class _RocketLaunchState extends State<RocketLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _rocket = 20.0;
  static const _burstAt = 0.85;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Quadratic bezier from bottom-left over a low control point to
  /// top-right, in a [size] box.
  static Offset _at(double t, Size size) {
    final p0 = Offset(0, size.height);
    final p1 = Offset(size.width * 0.55, size.height * 0.9);
    final p2 = Offset(size.width, 0);
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth - _rocket : 80,
          constraints.maxHeight.isFinite ? constraints.maxHeight - _rocket : 40,
        );
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeIn.transform(_controller.value);
            final here = _at(t, box);
            final ahead = _at(min(1, t + 0.01), box);
            final angle = atan2(ahead.dy - here.dy, ahead.dx - here.dx);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 1; i <= 5; i++)
                  if (t - i * 0.04 > 0) _flame(_at(t - i * 0.04, box), i),
                Positioned(
                  key: const ValueKey('rocket'),
                  left: here.dx,
                  top: here.dy,
                  child: Transform.rotate(
                    // The icon points up-right (−45°) by default.
                    angle: angle + pi / 4,
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      size: _rocket,
                      color: color,
                    ),
                  ),
                ),
                if (_controller.value >= _burstAt)
                  Positioned(
                    key: const ValueKey('rocket-burst'),
                    left: box.width - 4,
                    top: -8,
                    child: Opacity(
                      opacity: (1 - (_controller.value - _burstAt) / 0.3).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Transform.scale(
                        scale: 0.6 + (_controller.value - _burstAt) * 4,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 24,
                          color: Color(0xFFFFD54F),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _flame(Offset at, int i) => Positioned(
    left: at.dx + _rocket / 2 - 3,
    top: at.dy + _rocket / 2 - 3,
    child: Opacity(
      opacity: (0.7 - i * 0.12).clamp(0.0, 1.0),
      child: Container(
        width: 7 - i.toDouble(),
        height: 7 - i.toDouble(),
        decoration: const BoxDecoration(
          color: Color(0xFFFF9800),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
