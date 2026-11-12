import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_name_list.dart';

class NotInterestedChannels extends StatelessWidget {
  const NotInterestedChannels({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final channels = settingsStore.notInterestedChannels.entries.toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );
        return SettingsNameList(
          names: [for (final channel in channels) channel.value],
          rowKeys: [
            for (final channel in channels)
              ValueKey('not-interested-${channel.key}'),
          ],
          emptyGlyph: SettingsGlyphKind.list,
          emptyText: l.notInterestedEmpty,
          emptyTextAlign: TextAlign.center,
          emptyNote: l.notInterestedNote,
          countText: l.notInterestedCount(count: channels.length),
          note: l.notInterestedNote,
          actionLabel: l.notInterestedRestore,
          actionSemantics: (name) => l.notInterestedRestoreName(name: name),
          onAction: (index, _) =>
              settingsStore.clearNotInterested(channels[index].key),
        );
      },
    );
  }
}
