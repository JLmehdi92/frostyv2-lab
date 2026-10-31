import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';

/// The official app's "Edit Chat Filters": a master switch, then the four
/// AutoMod categories it enables, with Twitch's wording. A word is hidden
/// when AutoMod rates it 3 or more in a category turned on.
class ChatFiltersSetting extends StatelessWidget {
  const ChatFiltersSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    final store = settingsStore;
    return Observer(
      builder: (context) {
        final on = store.chatFiltersEnabled;
        final l = context.l10n;
        Widget category({
          required String title,
          required String description,
          required bool value,
          required ValueChanged<bool> onChanged,
        }) => SettingsListSwitch(
          title: title,
          subtitle: Text(description),
          value: value,
          onChanged: on ? onChanged : null,
        );

        return SettingsGroupsView(
          children: [
            SettingsGroup(
              children: [
                SettingsListSwitch(
                  title: l.chatFiltersEnable,
                  value: on,
                  onChanged: (value) => store.chatFiltersEnabled = value,
                ),
                SettingsNote(l.chatFiltersExplanation),
              ],
            ),
            SettingsGroup(
              title: l.chatFiltersGroup,
              children: [
                category(
                  title: l.chatFilterDiscrimination,
                  description: l.chatFilterDiscriminationDetail,
                  value: store.chatFilterDiscrimination,
                  onChanged: (value) => store.chatFilterDiscrimination = value,
                ),
                category(
                  title: l.chatFilterSexual,
                  description: l.chatFilterSexualDetail,
                  value: store.chatFilterSexual,
                  onChanged: (value) => store.chatFilterSexual = value,
                ),
                category(
                  title: l.chatFilterHarassment,
                  description: l.chatFilterHarassmentDetail,
                  value: store.chatFilterHarassment,
                  onChanged: (value) => store.chatFilterHarassment = value,
                ),
                category(
                  title: l.chatFilterProfanity,
                  description: l.chatFilterProfanityDetail,
                  value: store.chatFilterProfanity,
                  onChanged: (value) => store.chatFilterProfanity = value,
                ),
              ],
            ),
            SettingsGroup(children: [SettingsNote(l.chatFiltersNote)]),
          ],
        );
      },
    );
  }
}
