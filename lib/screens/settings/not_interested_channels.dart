import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class NotInterestedChannels extends StatelessWidget {
  const NotInterestedChannels({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final l = context.l10n;
        final channels = settingsStore.notInterestedChannels.entries.toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );
        if (channels.isEmpty) {
          return SettingsGroupsView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Column(
                  spacing: 12,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.trackRing,
                          width: OnsetTokens.hairlineWidth,
                        ),
                      ),
                      child: SettingsGlyph(
                        SettingsGlyphKind.list,
                        size: 24,
                        color: colors.secondary,
                      ),
                    ),
                    Text(
                      l.notInterestedEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.body,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l.notInterestedNote,
                        textAlign: TextAlign.center,
                        style: SettingsText.detail.copyWith(
                          height: 1.5,
                          color: colors.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return SettingsGroupsView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                SettingsSectionLabel(
                  l.notInterestedCount(count: channels.length),
                ),
                SettingsCard(
                  child: Column(
                    children: [
                      for (final (index, channel) in channels.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: OnsetTokens.hairlineWidth,
                            thickness: OnsetTokens.hairlineWidth,
                            color: colors.hairline,
                          ),
                        _NotInterestedRow(
                          key: ValueKey('not-interested-${channel.key}'),
                          name: channel.value,
                          onRestore: () =>
                              settingsStore.clearNotInterested(channel.key),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    l.notInterestedNote,
                    style: SettingsText.detail.copyWith(
                      height: 1.5,
                      color: colors.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NotInterestedRow extends StatelessWidget {
  const _NotInterestedRow({
    super.key,
    required this.name,
    required this.onRestore,
  });

  final String name;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          spacing: 12,
          children: [
            InitialAvatar(name: name, size: 34),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SettingsText.row.copyWith(color: colors.text),
              ),
            ),
            Semantics(
              label: context.l10n.notInterestedRestoreName(name: name),
              button: true,
              onTap: onRestore,
              excludeSemantics: true,
              child: SettingsButton(
                label: context.l10n.notInterestedRestore,
                onPressed: onRestore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
