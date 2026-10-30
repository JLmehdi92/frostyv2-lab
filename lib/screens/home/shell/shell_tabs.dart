import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/state_views.dart';

/// A row of tabs with the signal underline sliding under the active one
/// (Home's Following / Live / Clips).
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

  /// A count after each label (Activity's unread), none at 0; the pill is
  /// [indicatorColor] with dark or light digits.
  final List<int>? badges;

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
    this.badges,
  });

  /// The pill after a label: 18 dp, 11/800 digits.
  static const _badgeGap = 7.0;
  static const _badgeHeight = 18.0;
  static const _badgeStyle = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  int _badge(int i) {
    final badges = this.badges;
    return badges == null || i >= badges.length ? 0 : badges[i];
  }

  TextStyle _style(bool active) => TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
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
    final badgeWidths = <double>[];
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: _style(i == index)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      var width = painter.width;
      painter.dispose();
      var badgeWidth = 0.0;
      final count = _badge(i);
      if (count > 0) {
        final digits = TextPainter(
          text: TextSpan(text: '$count', style: _badgeStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        badgeWidth = math.max(scaler.scale(_badgeHeight), digits.width + 10);
        digits.dispose();
        width += _badgeGap + badgeWidth;
      }
      widths.add(width);
      badgeWidths.add(badgeWidth);
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

    Widget label(int i) => AnimatedDefaultTextStyle(
      duration: duration200,
      curve: OnsetMotion.standard,
      style: _style(i == index),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      child: Text(labels[i]),
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
                      label: _badge(i) > 0
                          ? '${labels[i]}, ${_badge(i)} unread'
                          : labels[i],
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
                              child: _badge(i) > 0
                                  ? Row(
                                      children: [
                                        // The label may draw past its
                                        // measure while its weight
                                        // changes: never an overflow.
                                        Flexible(child: label(i)),
                                        const SizedBox(width: _badgeGap),
                                        _CountPill(
                                          count: _badge(i),
                                          width: badgeWidths[i],
                                          fill: indicatorColor,
                                          style: _badgeStyle,
                                        ),
                                      ],
                                    )
                                  : label(i),
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
              curve: OnsetMotion.standard,
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

/// A tab's count: the indicator's colour, dark or light digits.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.count,
    required this.width,
    required this.fill,
    required this.style,
  });

  final int count;
  final double width;
  final Color fill;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(
      context,
    ).scale(ShellTabs._badgeHeight);
    return Container(
      key: const ValueKey('tab-count'),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Text(
        '$count',
        maxLines: 1,
        softWrap: false,
        style: style.copyWith(color: onFillColor(fill)),
      ),
    );
  }
}
