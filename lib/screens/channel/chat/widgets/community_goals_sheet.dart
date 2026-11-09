import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

typedef GoalContributor =
    Future<GoalContributionResult> Function(CommunityGoal goal, int amount);

class CommunityGoalTile extends StatelessWidget {
  const CommunityGoalTile({super.key, required this.goal, this.onContribute});

  final CommunityGoal goal;
  final VoidCallback? onContribute;

  static ValueKey<String> contributeKey(String goalId) =>
      ValueKey('community-goal-contribute-$goalId');

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final compact = NumberFormat.compact(locale: locale);
    final accent = goal.color == null
        ? SheetColors.accentOf(context)
        : Color(goal.color!);
    final state = !goal.isOpen
        ? l.communityGoalEnded
        : goal.isMaxedThisStream
        ? l.communityGoalMaxReached
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text(goal.title, style: _style(colors.text, 14, FontWeight.w700)),
            if (goal.description.isNotEmpty)
              Text(
                goal.description,
                style: _style(colors.body, 13, FontWeight.w400),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 6,
                color: accent,
                backgroundColor: colors.hairline,
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(
                  l.communityGoalRaised(percent: goal.percentRaised),
                  style: _style(colors.text, 12, FontWeight.w600),
                ),
                Text(
                  l.communityGoalAmount(
                    raised: compact.format(goal.pointsContributed),
                    needed: compact.format(goal.amountNeeded),
                  ),
                  style: _style(colors.secondary, 12, FontWeight.w400),
                ),
              ],
            ),
            if (state != null)
              Text(state, style: _style(colors.secondary, 12, FontWeight.w500))
            else if (onContribute != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: contributeKey(goal.id),
                  onPressed: onContribute,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: SheetColors.accentOf(context),
                    foregroundColor: SheetColors.onAccentOf(context),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l.communityGoalContribute),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static TextStyle _style(Color color, double size, FontWeight weight) =>
      TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: size,
        height: 1.35,
        fontWeight: weight,
        color: color,
      );
}

class GoalContributionDialog extends StatefulWidget {
  const GoalContributionDialog({
    super.key,
    required this.goal,
    required this.maximum,
  });

  final CommunityGoal goal;
  final int maximum;

  static const amountKey = ValueKey('goal-contribution-amount');
  static const maxKey = ValueKey('goal-contribution-max');
  static const sendKey = ValueKey('goal-contribution-send');

  @override
  State<GoalContributionDialog> createState() => _GoalContributionDialogState();
}

class _GoalContributionDialogState extends State<GoalContributionDialog> {
  late final _amount = TextEditingController(
    text: '${widget.goal.smallContribution.clamp(1, widget.maximum)}',
  );

  int? get _value {
    final value = int.tryParse(_amount.text);
    return value != null && value > 0 && value <= widget.maximum ? value : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final max = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(widget.maximum);
    return OnsetDialog(
      title: l.communityGoalContributeTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SheetTextField(
            key: GoalContributionDialog.amountKey,
            controller: _amount,
            hint: l.communityGoalAmountHint(max: max),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: GoalContributionDialog.maxKey,
              onPressed: () =>
                  setState(() => _amount.text = '${widget.maximum}'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(l.communityGoalMax(amount: max)),
            ),
          ),
        ],
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          key: GoalContributionDialog.sendKey,
          label: l.communityGoalContribute,
          onPressed: _value == null
              ? null
              : () => Navigator.pop(context, _value),
        ),
      ],
    );
  }
}

final _goalsInFlight = <String>{};

Future<void> contributeToGoal(
  BuildContext context, {
  required CommunityGoal goal,
  required int balance,
  required GoalContributor contribute,
  VoidCallback? onDone,
}) async {
  if (!_goalsInFlight.add(goal.id)) return;
  try {
    await _contributeOnce(
      context,
      goal: goal,
      balance: balance,
      contribute: contribute,
      onDone: onDone,
    );
  } finally {
    _goalsInFlight.remove(goal.id);
  }
}

Future<void> _contributeOnce(
  BuildContext context, {
  required CommunityGoal goal,
  required int balance,
  required GoalContributor contribute,
  VoidCallback? onDone,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final maximum = goal.maxContribution(balance: balance);
  if (maximum <= 0) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l.goalContributionResult(
            status: goal.isMaxedThisStream
                ? GoalContributionResult.maxPerStream.name
                : GoalContributionResult.notEnoughPoints.name,
          ),
        ),
      ),
    );
    return;
  }
  final amount = await showDialog<int>(
    context: context,
    builder: (_) => GoalContributionDialog(goal: goal, maximum: maximum),
  );
  if (amount == null) return;
  final result = await contribute(goal, amount);
  if (messenger != null && messenger.mounted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.goalContributionResult(status: result.name))),
      );
  }
  if (result == GoalContributionResult.contributed) onDone?.call();
}

class CommunityGoalsSheet extends StatefulWidget {
  const CommunityGoalsSheet({
    super.key,
    required this.load,
    this.contribute,
    this.balance,
  });

  final Future<List<CommunityGoal>?> Function() load;
  final GoalContributor? contribute;
  final int? Function()? balance;

  static const failedKey = ValueKey('community-goals-failed');
  static const emptyKey = ValueKey('community-goals-empty');

  @override
  State<CommunityGoalsSheet> createState() => _CommunityGoalsSheetState();
}

class _CommunityGoalsSheetState extends State<CommunityGoalsSheet> {
  late Future<List<CommunityGoal>?> _goals = widget.load();

  void _reload() {
    final goals = widget.load();
    setState(() {
      _goals = goals;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final panel = SheetPresentation.isPanel(context);
    final balance = widget.balance?.call();
    final contribute = widget.contribute;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: panel
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: FutureBuilder<List<CommunityGoal>?>(
        future: _goals,
        builder: (context, snapshot) {
          final goals = snapshot.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, panel ? 14 : 6, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l.communityGoalsTitle,
                    style: SheetText.subtitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (goals == null || goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Text(
                    goals == null
                        ? l.communityGoalsFailed
                        : l.communityGoalsEmpty,
                    key: goals == null
                        ? CommunityGoalsSheet.failedKey
                        : CommunityGoalsSheet.emptyKey,
                    style: SheetText.body.copyWith(color: colors.secondary),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final goal in goals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CommunityGoalTile(
                            goal: goal,
                            onContribute: contribute == null || balance == null
                                ? null
                                : () => contributeToGoal(
                                    context,
                                    goal: goal,
                                    balance: balance,
                                    contribute: contribute,
                                    onDone: _reload,
                                  ),
                          ),
                        ),
                      if (balance == null)
                        Text(
                          l.communityGoalLogIn,
                          style: SheetText.body.copyWith(
                            color: colors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showCommunityGoals(
  BuildContext context, {
  required Future<List<CommunityGoal>?> Function() load,
  GoalContributor? contribute,
  int? Function()? balance,
}) => showOnsetSheet<void>(
  context: context,
  panel: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) =>
      CommunityGoalsSheet(load: load, contribute: contribute, balance: balance),
);
