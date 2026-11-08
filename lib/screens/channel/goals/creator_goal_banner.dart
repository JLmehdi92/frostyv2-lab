import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

String creatorGoalTitle(AppLocalizations l, CreatorGoalKind kind) =>
    switch (kind) {
      CreatorGoalKind.subs => l.goalKindSubs,
      CreatorGoalKind.subPoints => l.goalKindSubPoints,
      CreatorGoalKind.newSubs => l.goalKindNewSubs,
      CreatorGoalKind.newSubPoints => l.goalKindNewSubPoints,
      CreatorGoalKind.followers => l.goalKindFollowers,
      CreatorGoalKind.other => l.goalKindOther,
    };

class CreatorGoalBanner extends StatelessWidget {
  const CreatorGoalBanner({super.key, required this.goals});

  final List<CreatorGoal> Function() goals;

  static const maxShown = 2;

  @override
  Widget build(BuildContext context) => Observer(
    warnWhenNoObservables: false,
    builder: (context) {
      final all = goals();
      if (all.isEmpty) return const SizedBox.shrink();
      final shown = all.take(maxShown).toList();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final (index, goal) in shown.indexed)
              CreatorGoalRow(
                key: ValueKey(goal.id),
                goal: goal,
                ordinal: all.length > 1 ? index + 1 : null,
                count: all.length,
              ),
          ],
        ),
      );
    },
  );
}

class CreatorGoalRow extends StatelessWidget {
  const CreatorGoalRow({
    super.key,
    required this.goal,
    this.ordinal,
    this.count = 1,
  });

  final CreatorGoal goal;
  final int? ordinal;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final reached = goal.isReached;
    final title = reached ? l.goalReachedTitle : creatorGoalTitle(l, goal.kind);
    final ordinalText = switch (ordinal) {
      final index? => l.goalOrdinal(index: index, count: count),
      null => null,
    };
    final progress = l.goalProgress(current: goal.current, target: goal.target);
    void open() {
      HapticFeedback.selectionClick();
      showCreatorGoalDetails(context, goal);
    }

    return Semantics(
      button: true,
      onTap: open,
      label: [?ordinalText, title, progress].join(', '),
      excludeSemantics: true,
      child: Material(
        color: colors.dialog.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnsetTokens.radiusCard),
          side: BorderSide(
            color: reached
                ? OnsetTokens.accent.withValues(alpha: 0.45)
                : colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Icon(
                      reached ? Icons.check_circle_rounded : Icons.flag_rounded,
                      size: 16,
                      color: reached ? OnsetTokens.accent : colors.secondary,
                    ),
                    Expanded(
                      child: Text(
                        [?ordinalText, title].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SheetText.rowDetail.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      progress,
                      style: SheetText.rowDetail.copyWith(
                        color: colors.secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                _GoalBar(progress: goal.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: 4,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 4,
          color: OnsetTokens.accent,
          backgroundColor: SheetColors.of(context).ring,
        ),
      ),
    ),
  );
}

enum GoalReachedPresentation { dialog, notice, none }

GoalReachedPresentation goalReachedPresentation({
  required bool routeCurrent,
  required bool resumed,
  required bool pip,
  required bool fullScreen,
  required bool typing,
}) {
  if (!routeCurrent || !resumed || pip) return GoalReachedPresentation.none;
  if (fullScreen || typing) return GoalReachedPresentation.notice;
  return GoalReachedPresentation.dialog;
}

Future<void> showCreatorGoalDetails(BuildContext context, CreatorGoal goal) =>
    showDialog<void>(
      context: context,
      builder: (context) => CreatorGoalDialog(goal: goal),
    );

class CreatorGoalDialog extends StatelessWidget {
  const CreatorGoalDialog({super.key, required this.goal});

  final CreatorGoal goal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final reached = goal.isReached;
    return OnsetDialog(
      title: reached ? l.goalReachedTitle : creatorGoalTitle(l, goal.kind),
      message: reached ? l.goalReachedBody : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (goal.description.isNotEmpty)
            Text(
              goal.description,
              style: SheetText.row.copyWith(color: colors.text),
            ),
          _GoalBar(progress: goal.progress),
          Text(
            l.goalProgress(current: goal.current, target: goal.target),
            style: SheetText.rowDetail.copyWith(color: colors.secondary),
          ),
        ],
      ),
      actions: [
        SheetButton(
          label: l.commonClose,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
