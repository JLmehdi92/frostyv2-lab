import 'package:flutter/material.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_math.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_card_shell.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_countdown.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:intl/intl.dart';

/// Twitch's prediction colours.
const kPredictionBlue = Color(0xFF387AFF);
const kPredictionPink = Color(0xFFF5009B);

Color predictionColor(PredictionOutcome outcome, ColorScheme scheme) =>
    switch (outcome.color) {
      PredictionColor.blue => kPredictionBlue,
      PredictionColor.pink => kPredictionPink,
      PredictionColor.unknown => scheme.primary,
    };

String _count(int value, String one, String many) =>
    '${NumberFormat.compact().format(value)} ${value == 1 ? one : many}';

/// What every card needs from the screen.
class HighlightCardContext {
  const HighlightCardContext({
    required this.expanded,
    required this.onToggle,
    required this.now,
    this.onDismiss,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onDismiss;

  /// Twitch's current time, for countdowns.
  final DateTime Function() now;
}

/// A live poll: the question, then each choice with its share of the
/// votes; the final results once it ended. Read-only (no voting).
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.card});

  final Poll poll;
  final HighlightCardContext card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final votes = [for (final c in poll.choices) c.votes];
    final shares = percentages(votes);
    final top = leaders(votes);
    final ends = poll.endsAt;
    final finished = !poll.isActive;
    final leaderIndex = top.isEmpty ? null : top.first;
    final leader = leaderIndex == null ? null : poll.choices[leaderIndex];
    final summary = [
      'Poll',
      poll.title,
      if (finished) 'final results',
      if (leader != null)
        '${leader.title} leads with ${shares[leaderIndex!]} percent',
      _count(poll.totalVotes, 'vote', 'votes'),
    ].join(', ');

    return HighlightCardShell(
      icon: Icons.poll_outlined,
      title: 'Poll',
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: summary,
      status: finished
          ? const Text('Final results')
          : ends == null
          ? Text(_count(poll.totalVotes, 'vote', 'votes'))
          : HighlightCountdown(
              deadline: ends,
              now: card.now,
              builder: (context, left) => Text('${formatTimeLeft(left)} left'),
            ),
      headline: Text(
        poll.title,
        maxLines: card.expanded ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          for (var i = 0; i < poll.choices.length; i++)
            HighlightBar(
              fraction: shares[i] / 100,
              color: top.contains(i) ? scheme.primary : scheme.outline,
              label: poll.choices[i].title,
              trailing: '${shares[i]}%',
              bold: top.contains(i),
            ),
          Text(
            _count(poll.totalVotes, 'vote', 'votes'),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A prediction: the outcomes with their colours, share of the points,
/// return ratio and predictors; locked, pending, winner or refunded. Read
/// only (predicting needs a Twitch session).
class PredictionCard extends StatelessWidget {
  const PredictionCard({
    super.key,
    required this.prediction,
    required this.card,
  });

  final Prediction prediction;
  final HighlightCardContext card;

  String get _statusText => switch (prediction.status) {
    PredictionStatus.active => 'Predictions open',
    PredictionStatus.locked => 'Predictions closed',
    PredictionStatus.resolvePending ||
    PredictionStatus.cancelPending => 'Waiting for the result',
    PredictionStatus.resolved => 'Result',
    PredictionStatus.canceled => 'Canceled · points refunded',
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
    final summary = [
      'Prediction',
      prediction.title,
      _statusText,
      if (winner != null) 'winner ${winner.title}',
      for (var i = 0; i < prediction.outcomes.length; i++)
        '${prediction.outcomes[i].title} ${shares[i]} percent',
    ].where((s) => s.isNotEmpty).join(', ');

    return HighlightCardShell(
      icon: Icons.emoji_events_outlined,
      title: 'Prediction',
      accent: kPredictionBlue,
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: summary,
      status: prediction.status == PredictionStatus.active && locks != null
          ? HighlightCountdown(
              deadline: locks,
              now: card.now,
              builder: (context, left) =>
                  Text('${formatTimeLeft(left)} to predict'),
            )
          : Text(winner == null ? _statusText : 'Winner: ${winner.title}'),
      headline: Text(
        prediction.title,
        maxLines: card.expanded ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          for (var i = 0; i < prediction.outcomes.length; i++)
            _OutcomeRow(
              prediction: prediction,
              outcome: prediction.outcomes[i],
              share: shares[i],
              isWinner: prediction.outcomes[i].id == winner?.id,
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
    required this.color,
  });

  final Prediction prediction;
  final PredictionOutcome outcome;
  final int share;
  final bool isWinner;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final top = outcome.topPredictors.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        HighlightBar(
          fraction: share / 100,
          color: color,
          label: isWinner ? '✓ ${outcome.title}' : outcome.title,
          trailing: '$share%',
          bold: isWinner,
        ),
        Wrap(
          spacing: 10,
          children: [
            Text(
              _count(outcome.points, 'point', 'points'),
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Text(
              formatRatio(returnRatio(prediction, outcome)),
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Text(
              _count(outcome.users, 'predictor', 'predictors'),
              style: TextStyle(color: muted, fontSize: 12),
            ),
            if (top != null && top.name.isNotEmpty)
              Text(
                'Top: ${top.name}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
          ],
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
    );
    return HighlightCardShell(
      icon: Icons.push_pin_outlined,
      title: 'Pinned',
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: 'Pinned message from $sender: ${pin.text}',
      status: ends == null
          ? Text(pin.pinnedBy == null ? '' : 'by ${pin.pinnedBy}')
          : HighlightCountdown(
              deadline: ends,
              now: card.now,
              builder: (context, left) => Text('${formatTimeLeft(left)} left'),
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

/// This channel is raiding another: who, with how many viewers, the time
/// left before it leaves, and a button to follow it in-app.
class RaidCard extends StatelessWidget {
  const RaidCard({
    super.key,
    required this.raid,
    required this.card,
    required this.onWatch,
  });

  final RaidState raid;
  final HighlightCardContext card;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final target = raid.raid;
    final goAt = target.goAt;
    final viewers = _count(target.viewerCount, 'viewer', 'viewers');
    final image = target.targetProfileImage;
    return HighlightCardShell(
      icon: Icons.groups_outlined,
      title: 'Raid',
      expanded: card.expanded,
      onToggle: card.onToggle,
      onDismiss: card.onDismiss,
      semanticsLabel: raid.gone
          ? 'The raid to ${target.targetDisplayName} has started'
          : 'Raiding ${target.targetDisplayName} with $viewers',
      status: raid.gone || goAt == null
          ? Text(raid.gone ? 'Raid started' : viewers)
          : HighlightCountdown(
              deadline: goAt,
              now: card.now,
              builder: (context, left) =>
                  Text('$viewers · leaves in ${formatTimeLeft(left)}'),
            ),
      headline: Row(
        spacing: 8,
        children: [
          if (image != null)
            ClipOval(
              child: SizedBox.square(
                dimension: 24,
                child: FrostyCachedNetworkImage(imageUrl: image),
              ),
            ),
          Expanded(
            child: Text(
              'Raiding ${target.targetDisplayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onWatch,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Watch ${target.targetDisplayName}'),
        ),
      ),
    );
  }
}
