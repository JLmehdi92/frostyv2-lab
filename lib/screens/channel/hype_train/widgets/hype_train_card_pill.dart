import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// "LVL n" with the variant icon, over a stream thumbnail.
class HypeTrainCardPill extends StatelessWidget {
  const HypeTrainCardPill({super.key, required this.status});

  final HtCardStatus status;

  HtStyle get _style {
    if (status.isAllTimeHigh) return HtStyle.athReached;
    return switch (status.variant) {
      HtVariant.goldenKappa => HtStyle.goldenKappa,
      HtVariant.mythic => HtStyle.mythic,
      _ when status.isShared => HtStyle.shared,
      HtVariant.treasure => HtStyle.treasure,
      HtVariant.community => HtStyle.community,
      HtVariant.regular => HtStyle.regular,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = HtPalette.of(_style, Theme.of(context).colorScheme);
    return Semantics(
      label: '${palette.a11yName} level ${status.level}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(palette.icon, size: 13, color: palette.iconColor),
              const SizedBox(width: 3),
              Text(
                'LVL ${status.level}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.onBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
