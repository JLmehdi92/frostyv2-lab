import 'package:flutter/material.dart';
import 'package:onset/screens/channel/hype_train/hype_train_timings.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// "LVL n" on Twitch's black pill, with a trophy on a record. A jump of
/// several levels (a merge) counts up.
class HypeTrainLevelPill extends StatelessWidget {
  const HypeTrainLevelPill({
    super.key,
    required this.level,
    required this.background,
    required this.foreground,
    this.trophy = false,
    this.animate = true,
    this.from,
    this.horizontalPadding = HtDims.margin,
    this.colorDuration = Duration.zero,
  });

  final int level;
  final Color background;
  final Color foreground;

  /// The record: a trophy after the level.
  final bool trophy;

  /// Off with reduced motion: the new level shows at once.
  final bool animate;

  /// Counts up from this level when first shown (a merge).
  final int? from;

  /// 30 dp on the merge's pill.
  final double horizontalPadding;

  /// How long a new [foreground] takes to replace the old one (a level's
  /// colour morphing into the next).
  final Duration colorDuration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: foreground),
      duration: colorDuration,
      curve: Curves.easeOut,
      builder: (context, color, _) => _pill(color ?? foreground),
    );
  }

  Widget _pill(Color foreground) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: animate ? from : null, end: level),
      duration: animate ? HtTimings.fade : Duration.zero,
      builder: (context, value, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(HtDims.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: HtDims.marginQuarter,
              ),
              child: Text(
                HtCopy.of(context).level(value),
                maxLines: 1,
                style: HtType.titleExtraSmall.copyWith(
                  color: foreground,
                  fontFeatures: HtType.tabular,
                ),
              ),
            ),
            if (trophy)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: HtDims.margin),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: HtDims.icon,
                  color: foreground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
