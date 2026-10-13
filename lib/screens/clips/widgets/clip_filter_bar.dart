import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/stores/channel_clips_store.dart';

/// The period and sort chips above a channel's clips.
class ClipFilterBar extends StatelessWidget {
  const ClipFilterBar({super.key, required this.store});

  final ChannelClipsStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final period = store.period;
        final sort = store.sort;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            16 + MediaQuery.paddingOf(context).left,
            8,
            16 + MediaQuery.paddingOf(context).right,
            8,
          ),
          child: Row(
            spacing: 8,
            children: [
              for (final p in ClipPeriod.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: p == period,
                  onSelected: (_) => store.select(period: p),
                ),
              const SizedBox(height: 24, child: VerticalDivider(width: 8)),
              for (final s in ClipSort.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: s == sort,
                  onSelected: (_) => store.select(sort: s),
                ),
            ],
          ),
        );
      },
    );
  }
}
