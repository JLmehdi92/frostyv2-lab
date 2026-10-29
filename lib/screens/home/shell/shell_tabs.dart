import 'package:flutter/material.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// A row of tabs with the signal underline sliding under the active one
/// (Accueil's Following / Live / Clips).
class ShellTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final double height;
  final double fontSize;
  final double gap;
  final double bottomPadding;
  final EdgeInsets padding;
  final Color activeColor;
  final Color idleColor;
  final Color indicatorColor;

  const ShellTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    required this.height,
    required this.fontSize,
    required this.gap,
    required this.bottomPadding,
    required this.padding,
    required this.activeColor,
    required this.idleColor,
    required this.indicatorColor,
  });

  TextStyle _style(bool active) => TextStyle(
    fontFamily: FrostyTokens.bodyFamily,
    fontSize: fontSize,
    height: 1.2,
    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    letterSpacing: active ? -0.01 * fontSize : 0,
    color: active ? activeColor : idleColor,
  );

  void _select(int i) {
    if (i != index) Haptics.selection();
    onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final widths = <double>[];
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: _style(i == index)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widths.add(painter.width);
      painter.dispose();
    }
    // An index out of range (a tab gone with the account) draws no line.
    final hasIndicator = index >= 0 && index < widths.length;
    var left = padding.left;
    for (var i = 0; i < index && i < widths.length; i++) {
      left += widths[i] + gap;
    }
    final width = hasIndicator ? widths[index] : 0.0;
    final duration = reduceMotionOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final duration200 = motionDuration(
      context,
      const Duration(milliseconds: 200),
    );

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                right: padding.right,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Semantics(
                      button: true,
                      selected: i == index,
                      inMutuallyExclusiveGroup: true,
                      label: labels[i],
                      // The text's own semantics are excluded, the tap with
                      // them: a screen reader taps through this one.
                      onTap: () => _select(i),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _select(i),
                        child: SizedBox(
                          height: height,
                          width: widths[i],
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: bottomPadding),
                              child: AnimatedDefaultTextStyle(
                                duration: duration200,
                                curve: FrostyMotion.standard,
                                style: _style(i == index),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                child: Text(labels[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedPositioned(
              key: const ValueKey('tab-indicator'),
              duration: duration,
              curve: FrostyMotion.standard,
              left: left,
              width: width,
              bottom: 0,
              height: 2.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
