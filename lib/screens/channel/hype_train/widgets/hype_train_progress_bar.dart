import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// The rounded 6 px level bar. It animates to [percent] in [duration]
/// (a `fillTo` step), with the style's gradient.
class HypeTrainProgressBar extends StatefulWidget {
  const HypeTrainProgressBar({
    super.key,
    required this.percent,
    required this.palette,
    this.duration = HtTimings.extraShort,
  });

  final int percent;
  final HtPalette palette;
  final Duration duration;

  @override
  State<HypeTrainProgressBar> createState() => HypeTrainProgressBarState();
}

class HypeTrainProgressBarState extends State<HypeTrainProgressBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.percent / 100,
  );

  /// The drawn fill, 0–1.
  double get value => _controller.value;

  @override
  void didUpdateWidget(HypeTrainProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _controller.animateTo(
        widget.percent / 100,
        duration: widget.duration,
        curve: Curves.easeOut,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(color: palette.track),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: _controller.value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: palette.fillGradient),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
