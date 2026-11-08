import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/feedback_prompt.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
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

/// Settings › Other: updates and release
/// notes, storage and reset, privacy, about. On a phone these groups end
/// the settings' first page.
class OtherSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  /// ONSET's source code (About › "Source code"); empty hides that row.
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
    children: otherSettingsGroups(context, settingsStore, sourceUrl: sourceUrl),
  );
}

/// The groups of [OtherSettings]. About holds ONSET's own source code link
/// (gone when [sourceUrl] is empty) and the licences.
List<Widget> otherSettingsGroups(
  BuildContext context,
  SettingsStore settingsStore, {
  String sourceUrl = onsetRepoUrl,
}) {
  final updater = context.read<OnsetUpdater?>();
  final updates = updater != null && updater.enabled;
  final l = context.l10n;
  return [
    SettingsGroup(
      title: l.settingsUpdates,
      children: [
        if (updates) UpdateCheckTile(updater: updater),
        SettingsRow(
          glyph: SettingsGlyphKind.notes,
          title: l.settingsReleaseNotes,
          end: SettingsRowEnd.chevron,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: ReleaseNotes.routeName),
              builder: (context) => const ReleaseNotes(),
            ),
          ),
        ),
        if (updates) SettingsNote(l.settingsUpdatesNote),
      ],
    ),
    SettingsGroup(
      title: l.settingsStorage,
      children: [
        SettingsRow(
          glyph: SettingsGlyphKind.cache,
          title: l.settingsClearCache,
          onTap: () => clearImageCache(context),
        ),
        SettingsRow(
          glyph: SettingsGlyphKind.reset,
          title: l.settingsReset,
          onTap: () => confirmResetSettings(context, settingsStore),
        ),
      ],
    ),
    SettingsGroup(
      title: l.settingsPrivacy,
      children: [
        Observer(
          builder: (context) => SettingsListSwitch(
            title: context.l10n.onboardingSetupCrashTitle,
            subtitle: Text(context.l10n.onboardingSetupCrashDetail),
            value: settingsStore.shareCrashLogsAndAnalytics,
            onChanged: (newValue) {
              // The app follows it (syncFirebaseCollection).
              settingsStore.shareCrashLogsAndAnalytics = newValue;
            },
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: l.settingsAbout,
      children: [
        if (sourceUrl.isNotEmpty)
          SettingsRow(
            glyph: SettingsGlyphKind.code,
            title: l.settingsSourceCode,
            end: SettingsRowEnd.external,
            onTap: () => launchSettingsLink(
              sourceUrl,
              external: settingsStore.launchUrlExternal,
            ),
          ),
        SettingsRow(
          glyph: SettingsGlyphKind.notes,
          title: l.settingsSendFeedback,
          end: SettingsRowEnd.external,
          onTap: () => launchSettingsLink(
            onsetFeedbackUrl,
            external: settingsStore.launchUrlExternal,
          ),
        ),
        SettingsRow(
          glyph: SettingsGlyphKind.link,
          title: l.settingsTwitchHelp,
          end: SettingsRowEnd.external,
          onTap: () => launchSettingsLink(
            twitchHelpUrl,
            external: settingsStore.launchUrlExternal,
          ),
        ),
        SettingsRow(
          glyph: SettingsGlyphKind.list,
          title: l.settingsLicenses,
          end: SettingsRowEnd.chevron,
          onTap: () => showOnsetLicenses(context),
        ),
      ],
    ),
  ];
}

/// The notice the licences page opens with, in [l]'s language: ONSET's
/// licence, its lack of warranty and where its source is (AGPL section 5).
/// Where the code comes from is in NOTICE, shipped with the source.
String onsetLegalese(AppLocalizations l) =>
    l.settingsLegalese(url: onsetRepoUrl);

/// "Licenses": Flutter's licence page, ONSET's notice first, then every
/// package's licence.
void showOnsetLicenses(BuildContext context) => showLicensePage(
  context: context,
  applicationName: 'ONSET',
  applicationLegalese: onsetLegalese(context.l10n),
);

/// "Clear image cache": empties it, then says so.
Future<void> clearImageCache(BuildContext context) async {
  HapticFeedback.lightImpact();

  await CustomCacheManager.instance.emptyCache();
  await CustomCacheManager.removeOrphanedCacheFiles();

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: AlertMessage(
        message: context.l10n.settingsCacheCleared,
        centered: false,
      ),
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
    title: context.l10n.settingsResetTitle,
    message: context.l10n.settingsResetMessage,
    confirm: context.l10n.settingsResetConfirm,
  );
  if (!confirmed) return;
  HapticFeedback.heavyImpact();
  settingsStore.resetAllSettings();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: AlertMessage(
        message: context.l10n.settingsResetDone,
        centered: false,
      ),
    ),
  );
}
