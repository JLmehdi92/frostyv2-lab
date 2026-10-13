import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';

/// "LVL n". A jump of several levels (a merge) counts up.
class HypeTrainLevelPill extends StatelessWidget {
  const HypeTrainLevelPill({
    super.key,
    required this.level,
    required this.background,
    required this.foreground,
  });

  final int level;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(end: level),
      duration: HtTimings.fade,
      builder: (context, value, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            'LVL $value',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
