import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/highlight_math.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_card_shell.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_countdown.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// Twitch's prediction colours.
const kPredictionBlue = Color(0xFF387AFF);
const kPredictionPink = Color(0xFFF5009B);

Color predictionColor(PredictionOutcome outcome, ColorScheme scheme) =>
    switch (outcome.color) {
      PredictionColor.blue => kPredictionBlue,
      PredictionColor.pink => kPredictionPink,
      PredictionColor.unknown => scheme.primary,
    };

/// What every card needs from the screen.
class HighlightCardContext {
  const HighlightCardContext({
    required this.expanded,
    required this.onToggle,
    required this.now,
    this.onDismiss,
    this.onTakePart,
    this.onReport,
    this.onVote,
    this.votedChoiceId,
    this.voting = false,
  });

  final VoidCallback? onReport;

  final ValueChanged<String>? onVote;
  final String? votedChoiceId;
  final bool voting;

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onDismiss;

  /// Twitch's current time, for countdowns.
  final DateTime Function() now;

  /// Opens the channel's twitch.tv chat to vote or predict there; null
  /// hides the button.
  final VoidCallback? onTakePart;
}

/// The button that sends a viewer to twitch.tv to take part (Twitch keeps
/// voting and predicting to its own pages): the 40 dp text button.
Widget? _takePart(
  HighlightCardContext card,
  String label, {
  required bool open,
}) {
  final onTap = card.onTakePart;
  final onReport = card.onReport;
  final takePart = !open || onTap == null
      ? null
      : _takePartButton(onTap, label);
  if (!card.expanded || (takePart == null && onReport == null)) return null;
  return Wrap(
    alignment: WrapAlignment.end,
    spacing: 4,
    children: [
      if (onReport != null)
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('highlight-report'),
            onPressed: onReport,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: SheetColors.of(context).secondary,
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.l10n.reportOnTwitch),
          ),
        ),
      ?takePart,
    ],
  );
}

Widget _takePartButton(VoidCallback onTap, String label) {
  return Builder(
    builder: (context) {
      final colors = SheetColors.of(context);
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            foregroundColor: colors.text,
            shape: const StadiumBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: SheetGlyph(
            SheetGlyphKind.external,
            size: 16,
            color: colors.text,
          ),
          label: Text(label),
        ),
      );
    },
  );
}

/// The poll bars' fills: the leaders brighter.
Color _pollFill(BuildContext context, {required bool leader}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = dark ? Colors.white : Colors.black;
  return base.withValues(
    alpha: leader ? (dark ? 0.20 : 0.12) : (dark ? 0.08 : 0.06),
  );
}

class PollCard extends StatefulWidget {
  const PollCard({super.key, required this.poll, required this.card});

  final Poll poll;
  final HighlightCardContext card;

  static ValueKey<String> choiceKey(String choiceId) =>
      ValueKey('poll-choice-$choiceId');

  static const voteKey = ValueKey('poll-vote');

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  String? _selected;

  @override
  void didUpdateWidget(PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.id != widget.poll.id) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final card = widget.card;
    final votes = [for (final c in poll.choices) c.votes];
    final shares = percentages(votes);
    final top = leaders(votes);
    final ends = poll.endsAt;
    final finished = !poll.isActive;
    final leaderIndex = top.isEmpty ? null : top.first;
    final leader = leaderIndex == null ? null : poll.choices[leaderIndex];
    final l = context.l10n;
    final votesText = l.highlightVotes(count: poll.totalVotes);
    final voted = poll.choices
        .where((c) => c.id == card.votedChoiceId)
        .firstOrNull;
    final onVote = card.onVote;
    final choosing =
        !finished && card.expanded && onVote != null && voted == null;
    final selected = choosing ? _selected : null;
    final summary = [
      l.highlightKind(kind: HighlightKind.poll.name),
      poll.title,
      if (finished) l.highlightFinalResultsLower,
      if (leader != null)
        l.highlightPollLeads(
          choice: leader.title,
          percent: shares[leaderIndex!],
        ),
      votesText,
      if (voted != null) l.pollVotedFor(choice: voted.title),
    ].join(', ');

    Widget bar(int i) {
      final choice = poll.choices[i];
      final mine = choice.id == voted?.id || choice.id == selected;
      final colors = SheetColors.of(context);
      final content = HighlightBar(
        fraction: shares[i] / 100,
        fill: _pollFill(context, leader: top.contains(i)),
        label: choice.title,
        trailing: l.commonPercent(value: shares[i]),
        bold: top.contains(i) || mine,
        leading: choosing || voted != null
            ? _PollMark(chosen: mine, color: colors.text)
            : null,
      );
      if (!choosing) return content;
      return Semantics(
        key: PollCard.choiceKey(choice.id),
        container: true,
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: mine,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: card.voting
              ? null
              : () => setState(() => _selected = choice.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      );
    }

    final footer = choosing
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: PollCard.voteKey,
              onPressed: selected == null || card.voting
                  ? null
                  : () => onVote(selected),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: SheetColors.accentOf(context),
                foregroundColor: SheetColors.onAccentOf(context),
                disabledBackgroundColor: SheetColors.of(context).raised,
                shape: const StadiumBorder(),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l.pollVoteSend),
            ),
          )
        : _takePart(card, l.highlightVote, open: !finished && voted == null);

    return HighlightCardShell(
      icon: Icons.poll_outlined,
      glyph: SheetGlyphKind.poll,
      title: l.highlightKind(kind: HighlightKind.poll.name),
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: summary,
      status: finished
          ? Text(l.highlightFinalResults)
          : ends == null
          ? Text(votesText)
          : HighlightCountdown(
              deadline: ends,
              now: card.now,
              builder: (context, left) =>
                  Text(l.highlightTimeLeft(time: formatTimeLeft(left))),
            ),
      footer: footer,
      interactiveBody: choosing,
      headline: Text(
        poll.title,
        maxLines: card.expanded ? 3 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: choosing ? 2 : 6,
        children: [
          for (var i = 0; i < poll.choices.length; i++) bar(i),
          ExcludeSemantics(
            excluding: choosing,
            child: Text(
              voted == null
                  ? votesText
                  : '$votesText · ${l.pollVotedFor(choice: voted.title)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SheetText.tabular(
                TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 12,
                  color: SheetColors.of(context).secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollMark extends StatelessWidget {
  const _PollMark({required this.chosen, required this.color});

  final bool chosen;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: motionDuration(context, const Duration(milliseconds: 160)),
        curve: OnsetMotion.standard,
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: chosen ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: chosen
            ? SheetGlyph(
                SheetGlyphKind.check,
                size: 11,
                strokeWidth: 2.4,
                color: Theme.of(context).colorScheme.surface,
              )
            : null,
      ),
    );
  }
}

/// A prediction: the outcomes with their colours, share of the points,
/// return ratio and predictors; locked, pending, winner or refunded.
/// Predicting opens twitch.tv.
class PredictionCard extends StatelessWidget {
  const PredictionCard({
    super.key,
    required this.prediction,
    required this.card,
  });

  final Prediction prediction;
  final HighlightCardContext card;

  String _statusText(AppLocalizations l) => switch (prediction.status) {
    PredictionStatus.active => l.highlightPredictionsOpen,
    PredictionStatus.locked => l.highlightPredictionsClosed,
    PredictionStatus.resolvePending ||
    PredictionStatus.cancelPending => l.highlightPredictionWaiting,
    PredictionStatus.resolved => l.highlightPredictionResult,
    PredictionStatus.canceled => l.highlightPredictionCanceled,
    PredictionStatus.unknown => '',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = [for (final o in prediction.outcomes) o.points];
    final shares = percentages(points);
    final winner = prediction.outcomes
        .where((o) => o.id == prediction.winningOutcomeId)
        .firstOrNull;
    final locks = prediction.locksAt;
    final l = context.l10n;
    final statusText = _statusText(l);
    final summary = [
      l.highlightKind(kind: HighlightKind.prediction.name),
      prediction.title,
      statusText,
      if (winner != null) l.highlightWinnerLower(outcome: winner.title),
      for (var i = 0; i < prediction.outcomes.length; i++)
        l.highlightOutcomeShare(
          outcome: prediction.outcomes[i].title,
          percent: shares[i],
        ),
    ].where((s) => s.isNotEmpty).join(', ');

    final dark = Theme.of(context).brightness == Brightness.dark;
    return HighlightCardShell(
      icon: Icons.emoji_events_outlined,
      glyph: SheetGlyphKind.trophy,
      title: l.highlightKind(kind: HighlightKind.prediction.name),
      // The trophy in light blue on a blue-tinted tile.
      accent: dark ? const Color(0xFF8DB4FF) : kPredictionBlue,
      tint: kPredictionBlue.withValues(alpha: 0.18),
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: summary,
      status: prediction.status == PredictionStatus.active && locks != null
          ? HighlightCountdown(
              deadline: locks,
              now: card.now,
              builder: (context, left) =>
                  Text(l.highlightTimeToPredict(time: formatTimeLeft(left))),
            )
          : Text(
              winner == null
                  ? statusText
                  : l.highlightWinner(outcome: winner.title),
            ),
      footer: _takePart(
        card,
        l.highlightPredict,
        open: prediction.status == PredictionStatus.active,
      ),
      headline: Text(
        prediction.title,
        maxLines: card.expanded ? 3 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          for (var i = 0; i < prediction.outcomes.length; i++)
            _OutcomeRow(
              prediction: prediction,
              outcome: prediction.outcomes[i],
              share: shares[i],
              isWinner: prediction.outcomes[i].id == winner?.id,
              resolved: winner != null,
              color: predictionColor(prediction.outcomes[i], scheme),
            ),
        ],
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.prediction,
    required this.outcome,
    required this.share,
    required this.isWinner,
    required this.resolved,
    required this.color,
  });

  final Prediction prediction;
  final PredictionOutcome outcome;
  final int share;
  final bool isWinner;

  /// A winner is known: the other outcomes fade to grey.
  final bool resolved;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = outcome.topPredictors.firstOrNull;
    final meta = SheetText.tabular(
      TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: 12,
        color: colors.secondary,
      ),
    );
    final fill = resolved && !isWinner
        ? (dark ? Colors.white : Colors.black).withValues(alpha: 0.06)
        : color.withValues(alpha: 0.38);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        HighlightBar(
          fraction: share / 100,
          fill: fill,
          label: outcome.title,
          trailing: context.l10n.commonPercent(value: share),
          bold: isWinner,
          leading: isWinner
              ? Semantics(
                  label: context.l10n.highlightWinnerMark,
                  child: SheetGlyph(
                    SheetGlyphKind.check,
                    size: 16,
                    strokeWidth: 2.6,
                    color: colors.text,
                  ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Wrap(
            spacing: 10,
            children: [
              Text(
                context.l10n.highlightPoints(count: outcome.points),
                style: meta,
              ),
              Text(formatRatio(returnRatio(prediction, outcome)), style: meta),
              Text(
                context.l10n.highlightPredictors(count: outcome.users),
                style: meta,
              ),
              if (top != null && top.name.isNotEmpty)
                Text(
                  context.l10n.highlightTopPredictor(name: top.name),
                  style: meta,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A message moderators pinned. [message] renders it like chat (emotes,
/// badges, colour); without it, plain text with the sender.
class PinnedCard extends StatelessWidget {
  const PinnedCard({
    super.key,
    required this.pin,
    required this.card,
    this.message,
  });

  final PinnedChatMessage pin;
  final HighlightCardContext card;
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final ends = pin.endsAt;
    final sender = pin.senderDisplayName.isEmpty
        ? pin.senderLogin
        : pin.senderDisplayName;
    final plain = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$sender: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _parseColor(pin.color),
            ),
          ),
          TextSpan(text: pin.text),
        ],
      ),
      maxLines: card.expanded ? 12 : 2,
      overflow: TextOverflow.ellipsis,
      // The pinned message at 14 / 1.5, not the 15 / 600 headline.
      style: TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: SheetColors.of(context).text,
      ),
    );
    return HighlightCardShell(
      icon: Icons.push_pin_outlined,
      glyph: SheetGlyphKind.pin,
      title: context.l10n.highlightKind(kind: HighlightKind.pinned.name),
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      dismissTooltip: context.l10n.highlightHideForMe,
      semanticsLabel: context.l10n.highlightPinnedFrom(
        sender: sender,
        text: pin.text,
      ),
      status: ends == null
          ? Text(switch (pin.pinnedBy) {
              final by? => context.l10n.highlightPinnedBy(name: by),
              null => '',
            })
          : HighlightCountdown(
              deadline: ends,
              now: card.now,
              builder: (context, left) => Text(
                context.l10n.highlightTimeLeft(time: formatTimeLeft(left)),
              ),
            ),
      headline: card.expanded
          ? null
          : message == null
          ? plain
          : ClipRect(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 48),
                child: message,
              ),
            ),
      body: message ?? plain,
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return null;
    }
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}
