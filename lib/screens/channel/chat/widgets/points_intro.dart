import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class PointsIntroCard extends StatelessWidget {
  const PointsIntroCard({
    super.key,
    required this.onDismiss,
    required this.onLearnMore,
  });

  final VoidCallback onDismiss;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    return Container(
      key: const ValueKey('points-intro'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 10,
            children: [
              SheetGlyph(
                SheetGlyphKind.coin,
                color: SheetColors.accentOf(context),
              ),
              Expanded(
                child: Text(
                  l.pointsIntroTitle,
                  style: SheetText.title.copyWith(
                    color: colors.text,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          Text(
            l.pointsIntroBody,
            style: SheetText.body.copyWith(color: colors.body),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              SheetButton(
                label: l.pointsHowToEarn,
                tone: SheetButtonTone.text,
                onPressed: onLearnMore,
              ),
              SheetButton(
                key: const ValueKey('points-intro-dismiss'),
                label: l.pointsIntroGotIt,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showPointsEarnSheet(BuildContext context) => showOnsetSheet<void>(
  context: context,
  panel: true,
  builder: (_) => const PointsEarnSheet(),
);

class PointsEarnSheet extends StatelessWidget {
  const PointsEarnSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final ways = [
      (SheetGlyphKind.monitor, l.pointsEarnWatch),
      (SheetGlyphKind.gift, l.pointsEarnBonus),
      (SheetGlyphKind.flame, l.pointsEarnStreak),
      (SheetGlyphKind.heart, l.pointsEarnFollow),
      (SheetGlyphKind.people, l.pointsEarnRaid),
      (SheetGlyphKind.star, l.pointsEarnSubscriber),
    ];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        SheetSectionLabel(l.pointsHowToEarn),
        for (final (glyph, text) in ways)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                SheetGlyph(glyph, color: colors.secondary),
                Expanded(
                  child: Text(
                    text,
                    style: SheetText.body.copyWith(color: colors.body),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l.pointsEarnNote,
            style: SheetText.body.copyWith(
              color: colors.secondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
