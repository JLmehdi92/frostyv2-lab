import 'package:flutter/material.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// A pill that selects one of a few views or filters (boards Categorie,
/// ParcourirTablette, VideosChaine): the selected one is tinted with the
/// signal accent and outlined by it, the others sit on the raised grey.
///
/// The pill is drawn [height] tall inside a 44 dp touch target.
class OnsetChip extends StatelessWidget {
  const OnsetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.height = 34,
  });

  /// Sections of a page (Live / Videos / Clips).
  static const sectionHeight = 34.0;

  /// Filters inside a section (a clip period, a clip order).
  static const filterHeight = 30.0;

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final accent = context.frostyColors.live;
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    void select() {
      if (!selected) Haptics.selection();
      onSelected();
    }

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      // The pill's own tap is excluded with its text: a screen reader
      // taps through this one.
      onTap: select,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: select,
          child: SizedBox(
            height: 44,
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: duration,
                curve: FrostyMotion.standard,
                height: height,
                padding: EdgeInsets.symmetric(
                  horizontal: height > 32 ? 14 : 12,
                ),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.10)
                      : colors.raised,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected ? accent : colors.pillBorder,
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? accent : colors.body,
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
