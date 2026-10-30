import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_chip.dart';

/// The period and sort chips above a channel's or a category's clips:
/// 30 dp pills, the chosen ones in the
/// signal tint, a hairline between the two groups.
class ClipFilterBar extends StatelessWidget {
  const ClipFilterBar({super.key, required this.store});

  final ChannelClipsStore store;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Observer(
      builder: (context) {
        final period = store.period;
        final sort = store.sort;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            16 + MediaQuery.paddingOf(context).left,
            4,
            16 + MediaQuery.paddingOf(context).right,
            4,
          ),
          child: Row(
            spacing: 8,
            children: [
              for (final p in ClipPeriod.values)
                OnsetChip(
                  label: p.label,
                  selected: p == period,
                  height: OnsetChip.filterHeight,
                  onSelected: () => store.select(period: p),
                ),
              Container(
                width: OnsetTokens.hairlineWidth,
                height: 20,
                color: colors.pillBorder,
              ),
              for (final s in ClipSort.values)
                OnsetChip(
                  label: s.label,
                  selected: s == sort,
                  height: OnsetChip.filterHeight,
                  onSelected: () => store.select(sort: s),
                ),
            ],
          ),
        );
      },
    );
  }
}
