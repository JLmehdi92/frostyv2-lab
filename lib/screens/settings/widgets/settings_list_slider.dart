import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';

/// A setting picked on a scale: its title and value, then the boards'
/// slider (a 4 dp track filled in the signal colour, a 20 dp thumb).
class SettingsListSlider extends StatefulWidget {
  final String title;
  final String trailing;
  final String? subtitle;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  const SettingsListSlider({
    super.key,
    required this.title,
    required this.trailing,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  @override
  State<SettingsListSlider> createState() => _SettingsListSliderState();
}

class _SettingsListSliderState extends State<SettingsListSlider> {
  int? _previousStep;

  void _handleChanged(double newValue) {
    if (widget.divisions != null) {
      final step =
          ((newValue - widget.min) /
                  (widget.max - widget.min) *
                  widget.divisions!)
              .round();
      if (_previousStep != null && step != _previousStep) {
        HapticFeedback.selectionClick();
      }
      _previousStep = step;
    }
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final subtitle = widget.subtitle;
    return Opacity(
      opacity: widget.onChanged == null ? 0.42 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: SettingsText.row.copyWith(color: colors.text),
                  ),
                ),
                Text(
                  widget.trailing,
                  style: OnsetType.tabular(
                    TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.body,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 32,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: accent,
                  inactiveTrackColor: colors.sliderTrack,
                  disabledActiveTrackColor: accent,
                  disabledInactiveTrackColor: colors.sliderTrack,
                  thumbColor: colors.thumb,
                  disabledThumbColor: colors.thumb,
                  overlayColor: accent.withValues(alpha: 0.12),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    elevation: 2,
                    pressedElevation: 3,
                  ),
                  trackShape: const RoundedRectSliderTrackShape(),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  showValueIndicator: ShowValueIndicator.never,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Slider(
                  value: widget.value.clamp(widget.min, widget.max),
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  onChanged: widget.onChanged != null ? _handleChanged : null,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: SettingsText.detail.copyWith(color: colors.secondary),
              ),
          ],
        ),
      ),
    );
  }
}
