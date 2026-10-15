import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// Two trains merging, as on Twitch: up to six channel avatars in green
/// auras, staggered up and down around a pill whose level counts up. The
/// previous channels sit before the pill, the joining ones after it; they
/// fade in one after the other.
class MergeAura extends StatefulWidget {
  const MergeAura({
    super.key,
    required this.duration,
    this.previous = const [],
    this.joining = const [],
    this.level,
    this.fromLevel,
    this.pill = HtNeutrals.pill,
    this.pillText = Colors.white,
    this.glow = HtGreen.g10,
    this.reduceMotion = false,
  });

  final Duration duration;
  final List<HtUser> previous;
  final List<HtUser> joining;

  /// The merged level, counting up from [fromLevel]; no pill without it.
  final int? level;
  final int? fromLevel;
  final Color pill;
  final Color pillText;
  final Color glow;
  final bool reduceMotion;

  /// Twitch's vertical offsets of aura 1–6, in dp.
  static const offsets = [-12.0, 12.0, -22.0, -12.0, 12.0, 22.0];

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

  /// Aura [number] (1–6) with its channel.
  Widget _aura(int number, HtUser user) => Transform.translate(
    key: ValueKey('ht-aura-$number'),
    offset: Offset(0, MergeAura.offsets[number - 1]),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: _opacity(number - 1), child: child),
      child: SizedBox(
        width: HtDims.avatar + HtDims.marginHalf,
        height: HtDims.avatar,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            OverflowBox(
              maxWidth: HtDims.aura,
              maxHeight: HtDims.aura,
              child: IgnorePointer(
                child: Container(
                  width: HtDims.aura,
                  height: HtDims.aura,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.glow.withValues(alpha: 0.6),
                        widget.glow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            HtAvatar(user: user, size: HtDims.avatar),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final previous = widget.previous.take(3).toList();
    final joining = widget.joining.take(3).toList();
    final level = widget.level;
    // Before the pill, outwards: aura 1, 3, 5; after it: aura 2, 4, 6.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = previous.length - 1; i >= 0; i--)
                _aura(i * 2 + 1, previous[i]),
              if (level != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HtDims.marginHalf,
                  ),
                  child: HypeTrainLevelPill(
                    key: const ValueKey('ht-merge-pill'),
                    level: level,
                    from: widget.fromLevel,
                    background: widget.pill,
                    foreground: widget.pillText,
                    horizontalPadding: 30,
                    animate: !widget.reduceMotion,
                  ),
                ),
              for (var i = 0; i < joining.length; i++)
                _aura(i * 2 + 2, joining[i]),
            ],
          ),
        ),
      ),
    );
  }
}
