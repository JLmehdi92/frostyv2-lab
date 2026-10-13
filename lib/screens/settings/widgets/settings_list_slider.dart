import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom-styled adaptive [Slider].
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
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          Text(
            widget.trailing,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider.adaptive(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged:
                  widget.onChanged != null ? _handleChanged : null,
            ),
            if (widget.subtitle != null) Text(widget.subtitle!),
          ],
        ),
      ),
    );
  }
}
