import 'package:flutter/material.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// The Mythic train's gold.
const _mythic = Color(0xFFFFD760);

Widget _emoteImage(HtReward emote, double size) {
  final url = emote.emoteUrl;
  return SizedBox.square(
    dimension: size,
    child: url == null
        ? const Icon(Icons.auto_awesome_rounded, color: _mythic)
        : OnsetCachedNetworkImage(
            imageUrl: url.toString(),
            width: size,
            height: size,
            useFade: false,
          ),
  );
}

/// The mythic emote pool with a shimmer passing over it.
class MythicPool extends StatefulWidget {
  const MythicPool({
    super.key,
    required this.duration,
    required this.pool,
    this.reduceMotion = false,
  });

  final Duration duration;
  final List<HtReward> pool;
  final bool reduceMotion;

  @override
  State<MythicPool> createState() => _MythicPoolState();
}

class _MythicPoolState extends State<MythicPool>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (!widget.reduceMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final emote in widget.pool.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _emoteImage(emote, 22),
          ),
      ],
    );
    if (widget.reduceMotion) return FittedBox(child: row);
    return FittedBox(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-2 + _controller.value * 4, 0),
            end: Alignment(-1 + _controller.value * 4, 0),
            colors: const [
              Colors.transparent,
              Colors.white54,
              Colors.transparent,
            ],
          ).createShader(rect),
          child: child,
        ),
        child: row,
      ),
    );
  }
}

/// The mythic emote being chosen: a highlight runs over the pool like a
/// roulette, slowing down until it lands on [selected].
class MythicSelect extends StatefulWidget {
  const MythicSelect({
    super.key,
    required this.duration,
    required this.pool,
    this.selected,
    this.reduceMotion = false,
  });

  final Duration duration;
  final List<HtReward> pool;
  final HtReward? selected;

  /// No roulette: the chosen emote at once.
  final bool reduceMotion;

  @override
  State<MythicSelect> createState() => MythicSelectState();
}

class MythicSelectState extends State<MythicSelect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Three full turns, then on to the selected emote.
  late final int _target = () {
    final index = widget.pool.indexWhere((e) => e.id == widget.selected?.id);
    return widget.pool.length * 3 + (index < 0 ? 0 : index);
  }();

  @visibleForTesting
  int get highlighted {
    if (widget.pool.isEmpty) return 0;
    final step = (Curves.decelerate.transform(_controller.value) * _target)
        .floor();
    return step % widget.pool.length;
  }

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

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final current = highlighted;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.pool.length; i++)
                AnimatedScale(
                  scale: i == current ? 1.25 : 1,
                  duration: const Duration(milliseconds: 80),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: i == current ? _mythic : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _emoteImage(widget.pool[i], 22),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The chosen mythic emote, scaling up with a glow.
class MythicReveal extends StatefulWidget {
  const MythicReveal({
    super.key,
    required this.duration,
    this.emote,
    this.reduceMotion = false,
  });

  final Duration duration;
  final HtReward? emote;
  final bool reduceMotion;

  @override
  State<MythicReveal> createState() => _MythicRevealState();
}

class _MythicRevealState extends State<MythicReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

  @override
  Widget build(BuildContext context) {
    final emote = widget.emote;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(
          (_controller.value * 2).clamp(0.0, 1.0),
        );
        return Container(
          key: const ValueKey('mythic-reveal'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _mythic.withValues(alpha: 0.6 * t.clamp(0.0, 1.0)),
                blurRadius: 16 * t.clamp(0.0, 1.0),
              ),
            ],
          ),
          child: Transform.scale(
            scale: 0.4 + 0.6 * t,
            child: emote == null
                ? const Icon(Icons.auto_awesome_rounded, color: _mythic)
                : _emoteImage(emote, 28),
          ),
        );
      },
    );
  }
}
