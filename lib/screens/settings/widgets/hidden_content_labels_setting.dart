import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
          title: 'Hide labeled streams',
          value: switch (hidden.length) {
            0 => 'None',
            1 => contentLabelName(hidden.single),
            final count => '$count labels',
          },
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
        title: 'Hide labeled streams',
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
                      'Streams with these labels are left out of Top, '
                      'categories and tags. Followed channels always show.',
                      style: SettingsText.body.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                  for (final id in knownContentLabels)
                    SettingsCheckRow(
                      label: contentLabelName(id),
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
