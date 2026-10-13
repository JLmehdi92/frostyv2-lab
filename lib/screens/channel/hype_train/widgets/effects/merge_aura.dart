import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';

/// Two trains merging: the previous channels, "+", the joining ones, fading
/// in one after the other over a soft glow.
class MergeAura extends StatefulWidget {
  const MergeAura({
    super.key,
    required this.duration,
    this.previous = const [],
    this.joining = const [],
    this.reduceMotion = false,
  });

  final Duration duration;
  final List<HtUser> previous;
  final List<HtUser> joining;
  final bool reduceMotion;

  @override
  State<MergeAura> createState() => _MergeAuraState();
}

class _MergeAuraState extends State<MergeAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _stagger = Duration(milliseconds: 80);

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

  double _opacity(int index) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 1;
    final start = _stagger.inMilliseconds * index / total;
    return ((_controller.value - start) * 4).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final glow = Theme.of(context).colorScheme.tertiary;
    final previous = widget.previous.take(6).toList();
    final joining = widget.joining.take(6).toList();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        var index = 0;
        Widget avatar(HtUser user) => Opacity(
          opacity: _opacity(index++),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: HtAvatar(user: user, size: 22),
          ),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                glow.withValues(alpha: 0.35 * _controller.value),
                glow.withValues(alpha: 0),
              ],
            ),
          ),
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final user in previous) avatar(user),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '+',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final user in joining) avatar(user),
              ],
            ),
          ),
        );
      },
    );
  }
}
