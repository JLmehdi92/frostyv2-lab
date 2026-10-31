import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/utils/content_labels.dart';

/// Picks the content classification labels whose streams are left out of
/// Top, category and tag lists.
class HiddenContentLabelsSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const HiddenContentLabelsSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final hidden = settingsStore.hiddenContentLabels;
        return SettingsRow(
          title: context.l10n.settingsHideLabeled,
          value: hidden.length == 1
              ? contentLabelName(hidden.single, context.l10n)
              : context.l10n.settingsHideLabeledValue(count: hidden.length),
          end: SettingsRowEnd.chevron,
          onTap: () => showSettingsSheet<void>(
            context: context,
            builder: (context) => _LabelsList(settingsStore: settingsStore),
          ),
        );
      },
    );
  }
}

class _LabelsList extends StatelessWidget {
  const _LabelsList({required this.settingsStore});

  final SettingsStore settingsStore;

  void _toggle(String id, bool hide) {
    final labels = [...settingsStore.hiddenContentLabels]..remove(id);
    if (hide) labels.add(id);
    // A new list, so the stream lists see the change.
    settingsStore.hiddenContentLabels = labels;
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Observer(
      builder: (context) => SettingsSheetContent(
        title: context.l10n.settingsHideLabeled,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: Text(
                      context.l10n.settingsHideLabeledNote,
                      style: SettingsText.body.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                  for (final id in knownContentLabelIds)
                    SettingsCheckRow(
                      label: contentLabelName(id, context.l10n),
                      value: settingsStore.hiddenContentLabels.contains(id),
                      onChanged: (hide) => _toggle(id, hide),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
