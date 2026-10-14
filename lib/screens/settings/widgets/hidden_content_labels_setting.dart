import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/utils/content_labels.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';

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
        return ListTile(
          title: const Text('Hide labeled streams'),
          subtitle: Text(switch (hidden.length) {
            0 => 'None',
            1 => contentLabelName(hidden.single),
            final count => '$count labels',
          }),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showModalBottomSheetWithProperFocus(
            context: context,
            isScrollControlled: true,
            builder: (context) => _LabelsSheet(settingsStore: settingsStore),
          ),
        );
      },
    );
  }
}

class _LabelsSheet extends StatelessWidget {
  const _LabelsSheet({required this.settingsStore});

  final SettingsStore settingsStore;

  void _toggle(String id, bool hide) {
    final labels = [...settingsStore.hiddenContentLabels]..remove(id);
    if (hide) labels.add(id);
    // A new list, so the stream lists see the change.
    settingsStore.hiddenContentLabels = labels;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Observer(
          builder: (context) => ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Streams with these labels are left out of Top, '
                  'categories and tags. Followed channels always show.',
                ),
              ),
              for (final id in knownContentLabels)
                CheckboxListTile(
                  title: Text(contentLabelName(id)),
                  value: settingsStore.hiddenContentLabels.contains(id),
                  onChanged: (hide) => _toggle(id, hide ?? false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
