import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';

/// Settings › General › Language: System, English, Français, one per line.
/// A change applies at once (the app follows [SettingsStore.appLanguage]);
/// the line under the options says which language System gives here, and
/// follows the device's language when it changes.
class LanguageSetting extends StatefulWidget {
  const LanguageSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<LanguageSetting> createState() => _LanguageSettingState();
}

class _LanguageSettingState extends State<LanguageSetting>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The device's languages changed: with an explicit language nothing
  /// else rebuilds this page, and System's line must say the new one.
  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settingsStore = widget.settingsStore;
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
          subtitle: l.settingsLanguageSystemSubtitle(
            language: device.nameInText(l),
          ),
          onChanged: (label) =>
              settingsStore.chooseLanguage(languages[labels.indexOf(label)]),
        );
      },
    );
  }
}
