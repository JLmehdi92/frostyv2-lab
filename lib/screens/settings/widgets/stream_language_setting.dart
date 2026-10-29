import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
          title: 'Stream language',
          value: kStreamLanguages[selected]!,
          end: SettingsRowEnd.chevron,
          onTap: () => showSettingsSheet<void>(
            context: context,
            builder: (context) => _LanguageList(
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

class _LanguageList extends StatelessWidget {
  const _LanguageList({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsSheetContent(
      title: 'Stream language',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              label: 'Stream language',
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final MapEntry(key: code, value: name)
                      in kStreamLanguages.entries)
                    SettingsChoiceRow(
                      label: name,
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
