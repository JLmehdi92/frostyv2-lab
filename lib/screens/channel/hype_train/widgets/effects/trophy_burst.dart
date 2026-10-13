import 'package:flutter/material.dart';

/// A new all-time high: the trophy pops in elastically with a ring pulse.
class TrophyBurst extends StatefulWidget {
  const TrophyBurst({
    super.key,
    required this.duration,
    this.reduceMotion = false,
  });

  final Duration duration;
  final bool reduceMotion;

  @override
  State<TrophyBurst> createState() => TrophyBurstState();
}

class TrophyBurstState extends State<TrophyBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The pop-in lasts at most a second, then the pulse repeats.
  late final _pop = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _popEnd, curve: Curves.elasticOut),
  );

  double get _popEnd {
    final ms = widget.duration.inMilliseconds;
    return ms <= 0 ? 1 : (1000 / ms).clamp(0.1, 1.0);
  }

  @visibleForTesting
  double get scale => _pop.value;

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
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFB300);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final ring = (_controller.value * 4) % 1;
        return SizedBox.square(
          dimension: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!widget.reduceMotion)
                Opacity(
                  opacity: (1 - ring) * 0.6,
                  child: Container(
                    width: 18 + 18 * ring,
                    height: 18 + 18 * ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 2),
                    ),
                  ),
                ),
              Transform.scale(
                scale: _pop.value,
                child: const Icon(
                  Icons.emoji_events_rounded,
                  key: ValueKey('trophy'),
                  size: 24,
                  color: gold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
