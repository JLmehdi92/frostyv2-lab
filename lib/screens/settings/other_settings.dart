import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/cache_manager.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/release_notes.dart';
import 'package:frosty/screens/settings/widgets/settings_glyph.dart';
import 'package:frosty/screens/settings/widgets/settings_kit.dart';
import 'package:frosty/screens/settings/widgets/settings_list_switch.dart';
import 'package:frosty/screens/settings/widgets/settings_page.dart';
import 'package:frosty/screens/settings/widgets/update_check_tile.dart';
import 'package:frosty/services/onset_updater.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:provider/provider.dart';

/// Settings › Other (boards Parametres, MiseAJour): updates and release
/// notes, storage and reset, privacy, about. On a phone these groups end
/// the settings' first page.
class OtherSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const OtherSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) => SettingsGroupsView(
    footer: SettingsPaneScope.maybeOf(context) == null
        ? SettingsFooter(external: () => settingsStore.launchUrlExternal)
        : null,
    children: otherSettingsGroups(context, settingsStore),
  );
}

/// The groups of [OtherSettings].
List<Widget> otherSettingsGroups(
  BuildContext context,
  SettingsStore settingsStore,
) {
  final updater = context.read<OnsetUpdater?>();
  final updates = updater != null && updater.enabled;
  return [
    SettingsGroup(
      title: 'Updates',
      children: [
        if (updates) UpdateCheckTile(updater: updater),
        SettingsRow(
          glyph: SettingsGlyphKind.notes,
          title: 'Release notes',
          end: SettingsRowEnd.chevron,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: ReleaseNotes.routeName),
              builder: (context) => const ReleaseNotes(),
            ),
          ),
        ),
        if (updates)
          const SettingsNote(
            'ONSET looks for a newer build when it starts and when it comes '
            'back to the foreground. Release notes open by themselves after '
            'an update to a new version.',
          ),
      ],
    ),
    SettingsGroup(
      title: 'Storage and reset',
      children: [
        SettingsRow(
          glyph: SettingsGlyphKind.cache,
          title: 'Clear image cache',
          onTap: () => clearImageCache(context),
        ),
        SettingsRow(
          glyph: SettingsGlyphKind.reset,
          title: 'Reset settings',
          onTap: () => confirmResetSettings(context, settingsStore),
        ),
      ],
    ),
    SettingsGroup(
      title: 'Privacy',
      children: [
        Observer(
          builder: (_) => SettingsListSwitch(
            title: 'Share crash logs and analytics',
            subtitle: const Text(
              'Help improve ONSET by sending anonymous crash logs and '
              'analytics through Firebase.',
            ),
            value: settingsStore.shareCrashLogsAndAnalytics,
            onChanged: (newValue) {
              settingsStore.shareCrashLogsAndAnalytics = newValue;

              FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
                newValue,
              );
              FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
                newValue,
              );
              FirebasePerformance.instance.setPerformanceCollectionEnabled(
                newValue,
              );
            },
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: 'About',
      children: [
        SettingsRow(
          glyph: SettingsGlyphKind.heart,
          title: 'Support Frosty',
          end: SettingsRowEnd.external,
          onTap: () => launchSettingsLink(
            'https://www.buymeacoffee.com/tommychow',
            external: settingsStore.launchUrlExternal,
          ),
        ),
        SettingsRow(
          glyph: SettingsGlyphKind.code,
          title: 'View source on GitHub',
          end: SettingsRowEnd.external,
          onTap: () => launchSettingsLink(
            'https://github.com/tommyxchow/frosty',
            external: settingsStore.launchUrlExternal,
          ),
        ),
      ],
    ),
  ];
}

/// "Clear image cache": empties it, then says so.
Future<void> clearImageCache(BuildContext context) async {
  HapticFeedback.lightImpact();

  await CustomCacheManager.instance.emptyCache();
  await CustomCacheManager.removeOrphanedCacheFiles();

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: AlertMessage(message: 'Image cache cleared', centered: false),
    ),
  );
}

/// "Reset settings": asks first, then puts every setting back to its
/// default and says so.
Future<void> confirmResetSettings(
  BuildContext context,
  SettingsStore settingsStore,
) async {
  final confirmed = await confirmSettingsAction(
    context,
    title: 'Reset all settings',
    message: 'Are you sure you want to reset all settings?',
    confirm: 'Reset',
  );
  if (!confirmed) return;
  HapticFeedback.heavyImpact();
  settingsStore.resetAllSettings();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: AlertMessage(message: 'All settings reset', centered: false),
    ),
  );
}
