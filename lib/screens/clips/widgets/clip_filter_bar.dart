import 'dart:async';

import 'package:flutter/material.dart' hide Clip;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_chip.dart';

String clipRangeLabel(BuildContext context, ClipDateRange range) {
  final format = DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  return context.l10n.clipDateRange(
    start: format.format(range.start),
    end: format.format(range.end),
  );
}

String clipsEmptyText(BuildContext context, ChannelClipsStore store) {
  final l = context.l10n;
  final range = store.range;
  if (range != null) {
    final format = DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return l.clipsNoneInRange(
      start: format.format(range.start),
      end: format.format(range.end),
    );
  }
  return switch (store.period) {
    ClipPeriod.lastDay => l.clipsNoneLastDay,
    ClipPeriod.lastWeek => l.clipsNoneLastWeek,
    ClipPeriod.lastMonth => l.clipsNoneLastMonth,
    ClipPeriod.allTime => l.clipsNoneAllTime,
  };
}

Future<void> pickClipRange(
  BuildContext context,
  ChannelClipsStore store, {
  DateTime? now,
}) async {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final current = store.range;
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2016),
    lastDate: today,
    initialDateRange: current == null
        ? null
        : DateTimeRange(
            start: current.start,
            end: current.end.subtract(const Duration(days: 1)),
          ),
  );
  if (picked == null) return;
  await store.selectRange(
    picked.start,
    picked.end.add(const Duration(days: 1)),
  );
}

class ClipFilterBar extends StatelessWidget {
  const ClipFilterBar({super.key, required this.store});

  final ChannelClipsStore store;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Observer(
      builder: (context) {
        final range = store.range;
        final period = range == null ? store.period : null;
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
                  label: p.label(context.l10n),
                  selected: p == period,
                  height: OnsetChip.filterHeight,
                  onSelected: () => store.select(period: p),
                ),
              if (store.canPickRange)
                OnsetChip(
                  key: const ValueKey('clip-dates'),
                  label: range == null
                      ? context.l10n.clipPickDates
                      : clipRangeLabel(context, range),
                  selected: range != null,
                  height: OnsetChip.filterHeight,
                  onSelected: () => unawaited(pickClipRange(context, store)),
                ),
              Container(
                width: OnsetTokens.hairlineWidth,
                height: 20,
                color: colors.pillBorder,
              ),
              for (final s in store.sorts)
                OnsetChip(
                  label: s.label(context.l10n),
                  selected: s == sort,
                  height: OnsetChip.filterHeight,
                  onSelected: () => store.select(sort: s),
                ),
              if (store.isFiltered)
                OnsetChip(
                  key: const ValueKey('clip-reset'),
                  label: context.l10n.clipFiltersReset,
                  selected: false,
                  height: OnsetChip.filterHeight,
                  onSelected: store.reset,
                ),
            ],
          ),
        );
      },
    );
  }
}
