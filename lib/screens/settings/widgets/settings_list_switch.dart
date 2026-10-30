import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';

/// A setting turned on or off: its title (and explanation) and the
/// switch; the whole row toggles it. Without [onChanged] it is dimmed and
/// does nothing.
class SettingsListSwitch extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsListSwitch({
    super.key,
    required this.title,
    this.subtitle,
    this.onChanged,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    void toggle() {
      HapticFeedback.selectionClick();
      onChanged!(!value);
    }

    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: onChanged != null,
        child: SettingsRow(
          title: title,
          subtitle: subtitle,
          enabled: onChanged != null,
          onTap: onChanged == null ? null : toggle,
          trailing: SettingsSwitch(value: value),
        ),
      ),
    );
  }
}
