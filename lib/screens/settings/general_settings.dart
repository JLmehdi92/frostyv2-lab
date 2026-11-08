import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/not_interested_channels.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/accent_color_setting.dart';
import 'package:onset/screens/settings/widgets/external_browser_setting.dart';
import 'package:onset/screens/settings/widgets/hidden_content_labels_setting.dart';
import 'package:onset/screens/settings/widgets/language_setting.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/stream_language_setting.dart';
import 'package:onset/screens/settings/widgets/theme_selection_setting.dart';

/// Settings › General: the language, theme and accent, stream cards,
/// browsing, links. The notifications moved to their own page.
class GeneralSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const GeneralSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        return SettingsGroupsView(
          children: [
            SettingsGroup(
              title: l.settingsLanguageTitle,
              children: [LanguageSetting(settingsStore: settingsStore)],
            ),
            SettingsGroup(
              title: l.settingsTheme,
              children: [
                ThemeSelectionSetting(settingsStore: settingsStore),
                AccentColorSetting(settingsStore: settingsStore),
              ],
            ),
            SettingsGroup(
              title: l.settingsStreamCard,
              children: [
                SettingsListSwitch(
                  title: l.settingsLargeStreamCard,
                  value: settingsStore.largeStreamCard,
                  onChanged: (newValue) =>
                      settingsStore.largeStreamCard = newValue,
                ),
                SettingsListSwitch(
                  title: l.settingsShowThumbnail,
                  value: settingsStore.showThumbnails,
                  onChanged: (newValue) =>
                      settingsStore.showThumbnails = newValue,
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsBrowse,
              children: [
                SettingsListSelect(
                  title: l.settingsStartTab,
                  value: settingsStore.startTab,
                  values: HomeTab.values,
                  labelOf: (tab) => tab.label(l),
                  onChanged: (tab) => settingsStore.startTab = tab,
                ),
                StreamLanguageSetting(settingsStore: settingsStore),
                HiddenContentLabelsSetting(settingsStore: settingsStore),
                SettingsRow(
                  glyph: SettingsGlyphKind.list,
                  title: l.settingsPageNotInterested,
                  value: '${settingsStore.notInterestedChannels.length}',
                  end: SettingsRowEnd.chevron,
                  onTap: () => openSettingsPage(
                    context,
                    id: SettingsPageId.notInterested,
                    builder: (context) =>
                        NotInterestedChannels(settingsStore: settingsStore),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsLinks,
              children: [
                ExternalBrowserSetting(settingsStore: settingsStore),
                ConfirmLinksSetting(settingsStore: settingsStore),
              ],
            ),
          ],
        );
      },
    );
  }
}
