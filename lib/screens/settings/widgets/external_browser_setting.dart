import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

class ExternalBrowserSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const ExternalBrowserSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsListSwitch(
        title: context.l10n.settingsExternalBrowser,
        value: settingsStore.launchUrlExternal,
        onChanged: (newValue) => settingsStore.launchUrlExternal = newValue,
      ),
    );
  }
}

class ConfirmLinksSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const ConfirmLinksSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsListSwitch(
        title: context.l10n.settingsConfirmLinks,
        subtitle: Text(context.l10n.settingsConfirmLinksDetail),
        value: settingsStore.confirmExternalLinks,
        onChanged: (newValue) => settingsStore.confirmExternalLinks = newValue,
      ),
    );
  }
}
