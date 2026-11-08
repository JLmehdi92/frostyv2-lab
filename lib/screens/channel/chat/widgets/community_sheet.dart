import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/screens/channel/chat/widgets/community_goals_sheet.dart';
import 'package:onset/screens/channel/goals/creator_goal_banner.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class CommunitySheet extends StatefulWidget {
  const CommunitySheet({
    super.key,
    required this.loadChallenges,
    required this.loadLeaderboards,
    required this.creatorGoals,
    this.contribute,
    this.balance,
    this.onSeeAllSupporters,
  });

  final Future<List<CommunityGoal>?> Function() loadChallenges;
  final Future<ChannelLeaderboards?> Function() loadLeaderboards;
  final List<CreatorGoal> Function() creatorGoals;
  final GoalContributor? contribute;
  final int? Function()? balance;
  final VoidCallback? onSeeAllSupporters;

  static const topShown = 3;
  static const seeAllKey = ValueKey('community-see-all-supporters');

  @override
  State<CommunitySheet> createState() => _CommunitySheetState();
}

class _CommunitySheetState extends State<CommunitySheet> {
  late Future<List<CommunityGoal>?> _challenges = widget.loadChallenges();
  late final Future<ChannelLeaderboards?> _boards = widget.loadLeaderboards();

  void _reloadChallenges() {
    final challenges = widget.loadChallenges();
    setState(() {
      _challenges = challenges;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final panel = SheetPresentation.isPanel(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: panel
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, panel ? 14 : 6, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                l.communityTabTitle,
                style: SheetText.subtitle.copyWith(color: colors.text),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _heading(context, l.communityChallenges),
                _challengesSection(context),
                _heading(context, l.communityCreatorGoals),
                _creatorGoalsSection(context),
                _heading(context, l.communityTopSupporters),
                _supportersSection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: SheetText.body.copyWith(
          color: SheetColors.of(context).text,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _note(BuildContext context, String text) => Text(
    text,
    style: SheetText.body.copyWith(color: SheetColors.of(context).secondary),
  );

  Widget _loading() => const Padding(
    padding: EdgeInsets.all(12),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _challengesSection(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<CommunityGoal>?>(
      future: _challenges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _loading();
        final goals = snapshot.data;
        if (goals == null) return _note(context, l.communitySectionFailed);
        if (goals.isEmpty) return _note(context, l.communityNothing);
        final balance = widget.balance?.call();
        final contribute = widget.contribute;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            for (final goal in goals)
              CommunityGoalTile(
                goal: goal,
                onContribute: contribute == null || balance == null
                    ? null
                    : () => contributeToGoal(
                        context,
                        goal: goal,
                        balance: balance,
                        contribute: contribute,
                        onDone: _reloadChallenges,
                      ),
              ),
          ],
        );
      },
    );
  }

  Widget _creatorGoalsSection(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final goals = widget.creatorGoals();
    if (goals.isEmpty) return _note(context, l.communityNothing);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        for (final goal in goals)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Text(
                goal.description.isEmpty
                    ? creatorGoalTitle(l, goal.kind)
                    : '${creatorGoalTitle(l, goal.kind)} · ${goal.description}',
                style: SheetText.body.copyWith(color: colors.text),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 6,
                  color: SheetColors.accentOf(context),
                  backgroundColor: colors.hairline,
                ),
              ),
              Text(
                '${number.format(goal.current)} / ${number.format(goal.target)}',
                style: SheetText.body.copyWith(color: colors.secondary),
              ),
            ],
          ),
      ],
    );
  }

  Widget _supportersSection(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    return FutureBuilder<ChannelLeaderboards?>(
      future: _boards,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _loading();
        final boards = snapshot.data;
        if (boards == null) return _note(context, l.communitySectionFailed);
        if (boards.isEmpty) return _note(context, l.communityNothing);
        final number = NumberFormat.decimalPattern(
          Localizations.localeOf(context).toLanguageTag(),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final kind in boards.kinds)
              if (boards.boards[kind]!.isNotEmpty) ...[
                Text(
                  l.leaderboardsTab(kind: kind.name),
                  style: SheetText.body.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final entry in boards.boards[kind]!.take(
                  CommunitySheet.topShown,
                ))
                  Row(
                    spacing: 10,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${entry.rank}',
                          style: SheetText.body.copyWith(
                            color: SheetColors.accentOf(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: SheetText.body.copyWith(color: colors.text),
                        ),
                      ),
                      Text(
                        switch (kind) {
                          LeaderboardKind.cheers => l.leaderboardsBits(
                            count: entry.score,
                            amount: number.format(entry.score),
                          ),
                          LeaderboardKind.gifts => l.leaderboardsGifts(
                            count: entry.score,
                            amount: number.format(entry.score),
                          ),
                        },
                        style: SheetText.body.copyWith(color: colors.secondary),
                      ),
                    ],
                  ),
              ],
            if (widget.onSeeAllSupporters != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: CommunitySheet.seeAllKey,
                  onPressed: widget.onSeeAllSupporters,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: SheetColors.accentOf(context),
                  ),
                  child: Text(l.communitySeeAll),
                ),
              ),
          ],
        );
      },
    );
  }
}
