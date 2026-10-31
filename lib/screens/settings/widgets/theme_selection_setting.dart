import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';

class ThemeSelectionSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const ThemeSelectionSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsListSelect(
        groupLabel: context.l10n.settingsTheme,
        value: settingsStore.themeType,
        values: ThemeType.values,
        labelOf: (theme) => theme.label(context.l10n),
        onChanged: (theme) => settingsStore.themeType = theme,
      ),
    );
  }
}
