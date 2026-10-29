import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/hidden_content_labels_setting.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/stream_language_setting.dart';
import 'package:onset/widgets/accent_color_setting.dart';
import 'package:onset/widgets/external_browser_setting.dart';
import 'package:onset/widgets/theme_selection_setting.dart';

/// Settings › General (board Parametres): theme and accent, stream cards,
/// browsing, links. The notifications moved to their own page.
class GeneralSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const GeneralSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsGroupsView(
        children: [
          SettingsGroup(
            title: 'Theme',
            children: [
              ThemeSelectionSetting(settingsStore: settingsStore),
              AccentColorSetting(settingsStore: settingsStore),
            ],
          ),
          SettingsGroup(
            title: 'Stream card',
            children: [
              SettingsListSwitch(
                title: 'Use large stream card',
                value: settingsStore.largeStreamCard,
                onChanged: (newValue) =>
                    settingsStore.largeStreamCard = newValue,
              ),
              SettingsListSwitch(
                title: 'Show thumbnail',
                value: settingsStore.showThumbnails,
                onChanged: (newValue) =>
                    settingsStore.showThumbnails = newValue,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Browse',
            children: [
              SettingsListSelect(
                title: 'Open the app on',
                selectedOption: settingsStore.startTab.label,
                options: [for (final tab in HomeTab.values) tab.label],
                onChanged: (label) => settingsStore.startTab = HomeTab.values
                    .firstWhere((tab) => tab.label == label),
              ),
              StreamLanguageSetting(settingsStore: settingsStore),
              HiddenContentLabelsSetting(settingsStore: settingsStore),
            ],
          ),
          SettingsGroup(
            title: 'Links',
            children: [ExternalBrowserSetting(settingsStore: settingsStore)],
          ),
        ],
      ),
    );
  }
}
