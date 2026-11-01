import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';

/// A setting with a few options: a segmented pill, or
/// with [stacked] one option per line (Video Autoplaying). A pill whose
/// labels would not fit their segments whole (a long word, large text)
/// shows one option per line too: no option loses words.
///
/// The options are [values], shown by [labelOf], with [value] selected:
/// the choice is the value itself, never found back from its label (two
/// languages, two labels).
class SettingsListSelect<T> extends StatelessWidget {
  final String? title;
  final String? subtitle;

  /// The option selected.
  final T value;

  /// The options, in order.
  final List<T> values;

  /// What an option is called on screen.
  final String Function(T value) labelOf;

  /// Told the option tapped, when it is not [value].
  final ValueChanged<T> onChanged;

  /// One option per line, for long labels.
  final bool stacked;

  /// What a screen reader calls the options without a [title].
  final String? groupLabel;

  const SettingsListSelect({
    super.key,
    this.title,
    this.subtitle,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.stacked = false,
    this.groupLabel,
  });

  void _pick(T option) {
    if (option == value) return;
    HapticFeedback.selectionClick();
    onChanged(option);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final title = this.title;
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (title != null)
            Text(title, style: SettingsText.row.copyWith(color: colors.text)),
          Semantics(
            label: title ?? groupLabel,
            container: true,
            explicitChildNodes: true,
            child: stacked
                ? _stack(context)
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        _segmentsFit(context, constraints.maxWidth)
                        ? _segments(context)
                        : _stack(context),
                  ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: SettingsText.detail.copyWith(color: colors.secondary),
            ),
        ],
      ),
    );
  }

  /// The style of a segment's label (bold when selected).
  static TextStyle _segmentStyle({required bool selected}) => TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 12.5,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
  );

  /// Whether every label fits its segment whole in [width], bold (as when
  /// selected), at the text size shown.
  bool _segmentsFit(BuildContext context, double width) {
    if (!width.isFinite || values.isEmpty) return true;
    // Each segment: 4 dp of ring on each side, then 8 dp of padding.
    final room = width / values.length - 2 * (4 + 8);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    for (final option in values) {
      final painter = TextPainter(
        text: TextSpan(
          text: labelOf(option),
          style: _segmentStyle(selected: true),
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final fits = painter.width <= room;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }

  Widget _segments(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final duration = settingsMotion(context, 220);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.track,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.trackRing,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final option in values)
            Expanded(
              child: _Option(
                label: labelOf(option),
                selected: option == value,
                onTap: () => _pick(option),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedContainer(
                            duration: duration,
                            curve: OnsetMotion.standard,
                            decoration: ShapeDecoration(
                              color: option == value
                                  ? accent.withValues(alpha: 0.14)
                                  : accent.withValues(alpha: 0),
                              shape: StadiumBorder(
                                side: option == value
                                    ? BorderSide(
                                        color: accent.withValues(alpha: 0.85),
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            labelOf(option),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _segmentStyle(selected: option == value)
                                .copyWith(
                                  color: option == value ? accent : colors.body,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stack(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final duration = settingsMotion(context, 220);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        for (final option in values)
          _Option(
            label: labelOf(option),
            selected: option == value,
            onTap: () => _pick(option),
            child: AnimatedContainer(
              duration: duration,
              curve: OnsetMotion.standard,
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 12),
              decoration: BoxDecoration(
                color: option == value
                    ? accent.withValues(alpha: 0.08)
                    : colors.stackIdle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: option == value
                      ? accent.withValues(alpha: 0.7)
                      : colors.stackRing,
                  width: option == value ? 1 : OnsetTokens.hairlineWidth,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labelOf(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 14,
                        fontWeight: option == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (option == value)
                    SettingsGlyph(
                      SettingsGlyphKind.check,
                      strokeWidth: 2.4,
                      color: accent,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One option: a radio button for a screen reader, pressed on touch.
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}
