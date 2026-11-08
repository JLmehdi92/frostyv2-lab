import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/utils/stream_languages.dart';

/// Picks the language Top and category lists are filtered by.
class StreamLanguageSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const StreamLanguageSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final selected = streamLanguageOrAll(settingsStore.streamLanguage);

        return SettingsRow(
          title: context.l10n.settingsStreamLanguage,
          value: streamLanguageName(selected, context.l10n),
          end: SettingsRowEnd.chevron,
          onTap: () => showSettingsSheet<void>(
            context: context,
            builder: (context) => StreamLanguageList(
              selected: selected,
              onSelected: (code) {
                settingsStore.streamLanguage = code;
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class StreamLanguageList extends StatelessWidget {
  const StreamLanguageList({
    super.key,
    required this.selected,
    required this.onSelected,
    this.followSetting,
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final ({String label, VoidCallback onTap})? followSetting;

  @override
  Widget build(BuildContext context) {
    return SettingsSheetContent(
      title: context.l10n.settingsStreamLanguage,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              label: context.l10n.settingsStreamLanguage,
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (followSetting case final follow?)
                    SettingsChoiceRow(
                      label: follow.label,
                      selected: selected == null,
                      onTap: follow.onTap,
                    ),
                  for (final code in kStreamLanguageCodes)
                    SettingsChoiceRow(
                      label: streamLanguageName(code, context.l10n),
                      selected: code == selected,
                      onTap: () => onSelected(code),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
