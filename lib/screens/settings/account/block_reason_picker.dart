import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class BlockReasonPicker extends StatelessWidget {
  const BlockReasonPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BlockReason? selected;
  final ValueChanged<BlockReason?> onSelected;

  static String label(AppLocalizations l, BlockReason reason) =>
      switch (reason) {
        BlockReason.harassment => l.blockReasonHarassment,
        BlockReason.spam => l.blockReasonSpam,
        BlockReason.other => l.blockReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            l.blockReasonTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in BlockReason.values)
                SheetChoicePill(
                  key: ValueKey('block-reason-${reason.name}'),
                  label: label(l, reason),
                  selected: selected == reason,
                  onSelected: () =>
                      onSelected(selected == reason ? null : reason),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
