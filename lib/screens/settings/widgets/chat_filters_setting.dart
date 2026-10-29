import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
                  title: 'Enable filtering in chat',
                  value: on,
                  onChanged: (value) => store.chatFiltersEnabled = value,
                ),
                const SettingsNote(
                  'Select the filters you would like to block in chat across '
                  'all channels. In channels you moderate, you will still see '
                  'all messages.',
                ),
              ],
            ),
            SettingsGroup(
              title: 'Filters',
              children: [
                category(
                  title: 'Discrimination',
                  description:
                      'Negative language about race, gender, orientation, or '
                      'similar',
                  value: store.chatFilterDiscrimination,
                  onChanged: (value) => store.chatFilterDiscrimination = value,
                ),
                category(
                  title: 'Sexually Explicit Language',
                  description:
                      'References to sexual acts, sexual content, and body '
                      'parts',
                  value: store.chatFilterSexual,
                  onChanged: (value) => store.chatFilterSexual = value,
                ),
                category(
                  title: 'Harassment',
                  description:
                      'Aggressive or sexually harassing language towards '
                      'other people',
                  value: store.chatFilterHarassment,
                  onChanged: (value) => store.chatFilterHarassment = value,
                ),
                category(
                  title: 'Profanity',
                  description: 'Curse words, expletives, or other obscenities',
                  value: store.chatFilterProfanity,
                  onChanged: (value) => store.chatFilterProfanity = value,
                ),
              ],
            ),
            const SettingsGroup(
              children: [
                SettingsNote(
                  "Twitch's AutoMod rates the words of each live chat "
                  'message; only words it rates are hidden, so a message it '
                  'did not rate always shows. Hidden words show as stars: '
                  'tap them to see the message. Chat replays of past '
                  'broadcasts are not filtered.',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
