import 'package:flutter/material.dart';

/// A rainbow sweeping behind [child] [cycles] times (shared trains and
/// records), at 35% opacity.
class RainbowSweep extends StatefulWidget {
  const RainbowSweep({
    super.key,
    required this.cycleDuration,
    required this.child,
    this.cycles = 3,
    this.opacity = 0.35,
  });

  final Duration cycleDuration;
  final int cycles;
  final double opacity;
  final Widget child;

  @override
  State<RainbowSweep> createState() => RainbowSweepState();
}

class RainbowSweepState extends State<RainbowSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _done = 0;

  static const _colors = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFE040FB),
  ];

  @visibleForTesting
  bool get isAnimating => _controller.isAnimating;

  @visibleForTesting
  LinearGradient get gradient {
    final shift = _controller.value * 2;
    return LinearGradient(
      begin: Alignment(-3 + shift * 2, 0),
      end: Alignment(-1 + shift * 2, 0),
      colors: _colors,
      tileMode: TileMode.mirror,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.cycleDuration)
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            _done++;
            if (_done < widget.cycles) _controller.forward(from: 0);
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: widget.opacity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => DecoratedBox(
                  key: const ValueKey('rainbow'),
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
