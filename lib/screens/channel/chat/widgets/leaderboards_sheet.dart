import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class LeaderboardsSheet extends StatefulWidget {
  const LeaderboardsSheet({super.key, required this.load});

  final Future<ChannelLeaderboards?> Function() load;

  static const failedKey = ValueKey('leaderboards-failed');
  static ValueKey<String> tabKey(LeaderboardKind kind) =>
      ValueKey('leaderboards-tab-${kind.name}');

  @override
  State<LeaderboardsSheet> createState() => _LeaderboardsSheetState();
}

class _LeaderboardsSheetState extends State<LeaderboardsSheet> {
  late final Future<ChannelLeaderboards?> _boards = widget.load();
  LeaderboardKind? _picked;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final panel = SheetPresentation.isPanel(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: panel
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: FutureBuilder<ChannelLeaderboards?>(
        future: _boards,
        builder: (context, snapshot) {
          final boards = snapshot.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, panel ? 14 : 6, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    l.leaderboardsTitle,
                    style: SheetText.subtitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (boards == null || boards.kinds.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(
                    l.leaderboardsFailed,
                    key: LeaderboardsSheet.failedKey,
                    style: SheetText.body.copyWith(color: colors.secondary),
                  ),
                )
              else
                Flexible(child: _board(context, boards)),
            ],
          );
        },
      ),
    );
  }

  Widget _board(BuildContext context, ChannelLeaderboards boards) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final kinds = boards.kinds;
    final kind =
        _picked ??
        (kinds.contains(boards.preferred) ? boards.preferred! : kinds.first);
    final entries = boards.boards[kind] ?? const [];
    final mine = boards.mine[kind];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            l.leaderboardsPeriod(period: boards.period.name),
            style: SheetText.rowDetail.copyWith(color: colors.secondary),
          ),
        ),
        if (kinds.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in kinds)
                  SheetChoicePill(
                    key: LeaderboardsSheet.tabKey(option),
                    label: l.leaderboardsTab(kind: option.name),
                    selected: option == kind,
                    large: true,
                    onSelected: () => setState(() => _picked = option),
                  ),
              ],
            ),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              l.leaderboardsEmpty,
              style: SheetText.body.copyWith(color: colors.secondary),
            ),
          )
        else
          for (final entry in entries) _EntryRow(entry: entry, kind: kind),
        if (mine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              l.leaderboardsYourRank(rank: mine.rank),
              style: SheetText.rowDetail.copyWith(color: colors.body),
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.kind});

  final LeaderboardEntry entry;
  final LeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final amount = NumberFormat.decimalPattern(
      l.localeName,
    ).format(entry.score);
    final score = switch (kind) {
      LeaderboardKind.cheers => l.leaderboardsBits(
        count: entry.score,
        amount: amount,
      ),
      LeaderboardKind.gifts => l.leaderboardsGifts(
        count: entry.score,
        amount: amount,
      ),
    };
    final podium = entry.rank <= 3;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: podium
                        ? SheetColors.accentOf(context)
                        : colors.secondary,
                  ),
                ),
              ),
            ),
            InitialAvatar(name: entry.displayName),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 1,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetText.row.copyWith(color: colors.text),
                  ),
                  Text(
                    score,
                    style: SheetText.tabular(
                      SheetText.rowDetail.copyWith(color: colors.body),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showLeaderboards(
  BuildContext context,
  Future<ChannelLeaderboards?> Function() load,
) => showOnsetSheet<void>(
  context: context,
  panel: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => LeaderboardsSheet(load: load),
);
