import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// The level's progress as the banner's background, as on Twitch: the
/// track fills the banner and the fill grows over it from the start edge.
/// A gradient spans the whole width and is clipped to the progress, not
/// squeezed into it; an unlocked treasure's gradient covers everything.
/// It animates to [percent] in [duration] (a `fillTo` step).
class HypeTrainProgressBar extends StatefulWidget {
  const HypeTrainProgressBar({
    super.key,
    required this.percent,
    required this.palette,
    this.duration = HtTimings.extraShort,
  });

  final int percent;
  final HtPalette palette;

  /// Zero with reduced motion.
  final Duration duration;

  @override
  State<HypeTrainProgressBar> createState() => HypeTrainProgressBarState();
}

class HypeTrainProgressBarState extends State<HypeTrainProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The drawn fill, 0–1.
  double get value => _controller.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: widget.percent / 100);
  }

  @override
  void didUpdateWidget(HypeTrainProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent == widget.percent) return;
    final target = widget.percent / 100;
    if (widget.duration == Duration.zero) {
      _controller.value = target;
    } else {
      _controller.animateTo(
        target,
        duration: widget.duration,
        curve: Curves.decelerate,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final colors = palette.fillColors;
    final decoration = BoxDecoration(
      color: colors == null ? palette.fill : null,
      gradient: colors == null
          ? null
          : LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: colors,
            ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        );
        final fill = SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            key: const ValueKey('ht-fill'),
            decoration: decoration,
          ),
        );
        return ColoredBox(
          color: palette.track,
          child: palette.fillCoversAll
              ? fill
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRect(
                      key: const ValueKey('ht-fill-clip'),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: _controller.value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  ),
                  child: fill,
                ),
        );
      },
    );
  }
}
