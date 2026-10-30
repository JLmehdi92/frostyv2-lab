import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/constants.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/update_check_tile.dart';
import 'package:onset/services/cache_manager.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:provider/provider.dart';

/// Settings › Other (boards Parametres, MiseAJour): updates and release
/// notes, storage and reset, privacy, about. On a phone these groups end
/// the settings' first page.
class OtherSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  /// ONSET's source code (About › "Source code"); empty hides the row.
  final String sourceUrl;

  const OtherSettings({
    super.key,
    required this.settingsStore,
    this.sourceUrl = onsetRepoUrl,
  });

  @override
  Widget build(BuildContext context) => SettingsGroupsView(
    footer: SettingsPaneScope.maybeOf(context) == null
        ? const SettingsFooter()
        : null,
    children: otherSettingsGroups(
      context,
      settingsStore,
      sourceUrl: sourceUrl,
    ),
  );
}

/// The groups of [OtherSettings]. About holds ONSET's own source code link,
/// and goes when there is none ([sourceUrl] empty).
List<Widget> otherSettingsGroups(
  BuildContext context,
  SettingsStore settingsStore, {
  String sourceUrl = onsetRepoUrl,
}) {
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
              'Help improve ONSET by sending crash logs and analytics '
              'through Firebase, without your Twitch account or channels.',
            ),
            value: settingsStore.shareCrashLogsAndAnalytics,
            onChanged: (newValue) {
              // The app follows it (syncFirebaseCollection).
              settingsStore.shareCrashLogsAndAnalytics = newValue;
            },
          ),
        ),
      ],
    ),
    if (sourceUrl.isNotEmpty)
      SettingsGroup(
        title: 'About',
        children: [
          SettingsRow(
            glyph: SettingsGlyphKind.code,
            title: 'Source code',
            end: SettingsRowEnd.external,
            onTap: () => launchSettingsLink(
              sourceUrl,
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
