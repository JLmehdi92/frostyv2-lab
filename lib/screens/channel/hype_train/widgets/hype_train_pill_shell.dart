import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// Twitch's landscape hype train pill: 32 dp of translucent black with a
/// 16 dp radius, a green fill sweeping [fraction] of it from the start
/// edge, and white content. It is tappable over at least 48 dp.
class HtPillShell extends StatelessWidget {
  const HtPillShell({
    super.key,
    required this.pillKey,
    required this.fraction,
    required this.label,
    required this.hint,
    required this.onTap,
    required this.child,
    this.targetKey,
  });

  /// On the visible 32 dp pill.
  final Key pillKey;

  /// On the 48 dp touch target.
  final Key? targetKey;

  /// 0–1 of the pill filled.
  final double fraction;
  final String label;
  final String hint;
  final VoidCallback onTap;

  /// One row, white, at most 24 dp tall; scaled down when space is short.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(HtDims.videoPill / 2));
    return Semantics(
      container: true,
      button: true,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            key: targetKey,
            constraints: const BoxConstraints(
              minHeight: HtDims.touchTarget,
              minWidth: HtDims.touchTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: DecoratedBox(
                key: pillKey,
                decoration: const BoxDecoration(
                  color: HtNeutrals.overlayPill,
                  borderRadius: radius,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: SizedBox(
                    height: HtDims.videoPill,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        Positioned.fill(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: fraction.clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: const DecoratedBox(
                                key: ValueKey('ht-pill-fill'),
                                decoration: BoxDecoration(color: HtGreen.g8),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HtDims.margin,
                            vertical: HtDims.marginHalf,
                          ),
                          child: IconTheme.merge(
                            data: const IconThemeData(
                              color: Colors.white,
                              size: 20,
                            ),
                            child: DefaultTextStyle.merge(
                              style: HtType.titleExtraSmall.copyWith(
                                color: Colors.white,
                                fontFeatures: HtType.tabular,
                              ),
                              maxLines: 1,
                              // A narrow chat shrinks the content.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Twitch's approaching circles: two, three past a goal of 5.
int htCheckCircleCount(HypeTrainApproaching approaching) =>
    approaching.goal > 5 ? 3 : 2;

/// The filled circles: the deadlines 1 to [count] still ahead. Deadlines
/// for more events run longer, so every key from the smallest one ahead
/// ([eventsLeft], 0 before the first tick) is ahead too.
int htFilledChecks(
  HypeTrainApproaching approaching,
  int eventsLeft,
  int count,
) {
  if (eventsLeft <= 0) return 0;
  return approaching.deadlines.keys
      .where((key) => key >= eventsLeft && key <= count)
      .length;
}

/// The approaching check circles, white, for the pills: filled for the
/// events already in, rings for the rest. The icons draw their glyph
/// about 12 dp inside a 14 dp box.
class HtCheckCircles extends StatelessWidget {
  const HtCheckCircles({super.key, required this.filled, required this.count});

  final int filled;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= count; i++)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: HtDims.marginHalf),
          child: filled >= i
              ? const Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('ht-check-filled'),
                  size: 14,
                  color: Colors.white,
                )
              : const Icon(
                  Icons.radio_button_unchecked_rounded,
                  key: ValueKey('ht-check-empty'),
                  size: 14,
                  color: Colors.white,
                ),
        ),
    ],
  );
}
