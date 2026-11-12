import 'package:flutter/material.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class SettingsNameList extends StatelessWidget {
  const SettingsNameList({
    super.key,
    required this.names,
    this.rowKeys,
    required this.emptyGlyph,
    required this.emptyText,
    this.emptyTextAlign,
    this.emptyNote,
    required this.countText,
    required this.note,
    this.onRefresh,
    required this.actionLabel,
    required this.actionSemantics,
    required this.onAction,
  });

  final List<String> names;
  final List<Key>? rowKeys;
  final SettingsGlyphKind emptyGlyph;
  final String emptyText;
  final TextAlign? emptyTextAlign;
  final String? emptyNote;
  final String countText;
  final String note;
  final RefreshCallback? onRefresh;
  final String actionLabel;
  final String Function(String name) actionSemantics;
  final void Function(int index, String name) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    if (names.isEmpty) {
      return SettingsGroupsView(
        onRefresh: onRefresh,
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
                    emptyGlyph,
                    size: 24,
                    color: colors.secondary,
                  ),
                ),
                Text(
                  emptyText,
                  textAlign: emptyTextAlign,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.body,
                  ),
                ),
                if (emptyNote case final emptyNote?)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      emptyNote,
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
      onRefresh: onRefresh,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            SettingsSectionLabel(countText),
            SettingsCard(
              child: Column(
                children: [
                  for (final (index, name) in names.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: OnsetTokens.hairlineWidth,
                        thickness: OnsetTokens.hairlineWidth,
                        color: colors.hairline,
                      ),
                    _NameRow(
                      key: rowKeys?[index],
                      name: name,
                      actionLabel: actionLabel,
                      actionSemantics: actionSemantics(name),
                      onAction: () => onAction(index, name),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                note,
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
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    super.key,
    required this.name,
    required this.actionLabel,
    required this.actionSemantics,
    required this.onAction,
  });

  final String name;
  final String actionLabel;
  final String actionSemantics;
  final VoidCallback onAction;

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
              label: actionSemantics,
              button: true,
              onTap: onAction,
              excludeSemantics: true,
              child: SettingsButton(label: actionLabel, onPressed: onAction),
            ),
          ],
        ),
      ),
    );
  }
}
