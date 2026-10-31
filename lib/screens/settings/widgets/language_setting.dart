import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';

/// Settings › General › Language: System, English, Français, one per line.
/// A change applies at once (the app follows [SettingsStore.appLanguage]);
/// the line under the options says which language System gives here.
class LanguageSetting extends StatelessWidget {
  const LanguageSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        const languages = AppLanguage.values;
        final labels = [for (final language in languages) language.label(l)];
        final device = resolveAppLanguage(
          AppLanguage.system,
          WidgetsBinding.instance.platformDispatcher.locales,
        );
        return SettingsListSelect(
          groupLabel: l.settingsLanguageTitle,
          stacked: true,
          selectedOption: settingsStore.appLanguage.label(l),
          options: labels,
          subtitle: l.settingsLanguageSystemSubtitle(language: device.label(l)),
          onChanged: (label) =>
              settingsStore.chooseLanguage(languages[labels.indexOf(label)]),
        );
      },
    );
  }
}
