import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_select.dart';
import 'package:onset/services/locale_bridge.dart';

/// Settings › General › Language: System, English, Français, one per line.
/// A change applies at once (the app follows [SettingsStore.appLanguage]);
/// the line under the options says which language System gives here, and
/// follows the device's language when it changes.
///
/// On Android 13+ the device's languages come from the system ([bridge]):
/// once the app set a per-app language, Flutter's list is that language,
/// not what System would give.
class LanguageSetting extends StatefulWidget {
  LanguageSetting({
    super.key,
    required this.settingsStore,
    LocaleBridge? bridge,
  }) : bridge = bridge ?? LocaleBridge.shared;

  final SettingsStore settingsStore;

  /// Asks the system for the device's own languages.
  final LocaleBridge bridge;

  @override
  State<LanguageSetting> createState() => _LanguageSettingState();
}

class _LanguageSettingState extends State<LanguageSetting>
    with WidgetsBindingObserver {
  /// The device's own languages as the system last said them, null where
  /// it does not say (Flutter's list is the device's there).
  late List<Locale>? _system = widget.bridge.lastSystemLocales;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _askSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _askSystem() async {
    final system = await widget.bridge.systemLocales();
    if (mounted && system != null) setState(() => _system = system);
  }

  /// The device's languages changed: with an explicit language nothing
  /// else rebuilds this page, and System's line must say the new one.
  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() {});
    _askSystem();
  }

  /// Back from the system's settings, where the device's languages may
  /// have changed without the app's (a per-app language is set).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _askSystem();
  }

  @override
  Widget build(BuildContext context) {
    final settingsStore = widget.settingsStore;
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final device = resolveAppLanguage(
          AppLanguage.system,
          _system ?? WidgetsBinding.instance.platformDispatcher.locales,
        );
        return SettingsListSelect(
          groupLabel: l.settingsLanguageTitle,
          stacked: true,
          value: settingsStore.appLanguage,
          values: AppLanguage.values,
          labelOf: (language) => language.label(l),
          subtitle: l.settingsLanguageSystemSubtitle(
            language: device.nameInText(l),
          ),
          onChanged: settingsStore.chooseLanguage,
        );
      },
    );
  }
}
