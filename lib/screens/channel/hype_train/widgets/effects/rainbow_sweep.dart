import 'package:flutter/material.dart';

/// Twitch's shared-train and record rainbow: a top-to-bottom gradient of
/// four colours behind [child], filling it. Over each quarter of a cycle
/// every stop slides linearly to the next colour; [cycles] cycles play,
/// then it rests. Text over it reads in black.
class RainbowSweep extends StatefulWidget {
  const RainbowSweep({
    super.key,
    required this.cycleDuration,
    required this.child,
    this.cycles = 3,
  });

  final Duration cycleDuration;
  final int cycles;
  final Widget child;

  /// Pink, lilac, orange and yellow, as on Twitch.
  static const colors = [
    Color(0xFFFA1ED2),
    Color(0xFFF093F9),
    Color(0xFFED722F),
    Color(0xFFFAF31A),
  ];

  @override
  State<RainbowSweep> createState() => RainbowSweepState();
}

class RainbowSweepState extends State<RainbowSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _done = 0;

  @visibleForTesting
  bool get isAnimating => _controller.isAnimating;

  /// For quarter q of the cycle, stop k moves from colour k + q to k + q + 1.
  @visibleForTesting
  LinearGradient get gradient {
    const colors = RainbowSweep.colors;
    final position = (_controller.value * 4).clamp(0.0, 4.0);
    final quarter = position.floor().clamp(0, 3);
    final t = position - quarter;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        for (var k = 0; k < colors.length; k++)
          Color.lerp(
            colors[(k + quarter) % colors.length],
            colors[(k + quarter + 1) % colors.length],
            t,
          )!,
      ],
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
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => DecoratedBox(
                key: const ValueKey('rainbow'),
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
