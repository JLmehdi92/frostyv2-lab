import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_math.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_card_shell.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_countdown.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';
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
    this.onTakePart,
  });

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
/// voting and predicting to its own pages): the board's 40 dp text button.
Widget? _takePart(
  HighlightCardContext card,
  String label, {
  required bool open,
}) {
  final onTap = card.onTakePart;
  if (!open || !card.expanded || onTap == null) return null;
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
              fontFamily: FrostyTokens.bodyFamily,
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

/// The poll bars' fills: the leaders brighter (board ChaineSondagePari).
Color _pollFill(BuildContext context, {required bool leader}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = dark ? Colors.white : Colors.black;
  return base.withValues(
    alpha: leader ? (dark ? 0.20 : 0.12) : (dark ? 0.08 : 0.06),
  );
}

/// A live poll: the question, then each choice with its share of the
/// votes; the final results once it ended. Voting opens twitch.tv.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.card});

  final Poll poll;
  final HighlightCardContext card;

  @override
  Widget build(BuildContext context) {
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
      glyph: SheetGlyphKind.poll,
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
      footer: _takePart(card, 'Vote on Twitch', open: !finished),
      headline: Text(
        poll.title,
        maxLines: card.expanded ? 3 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          for (var i = 0; i < poll.choices.length; i++)
            HighlightBar(
              fraction: shares[i] / 100,
              fill: _pollFill(context, leader: top.contains(i)),
              label: poll.choices[i].title,
              trailing: '${shares[i]}%',
              bold: top.contains(i),
            ),
          Text(
            _count(poll.totalVotes, 'vote', 'votes'),
            style: SheetText.tabular(
              TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 12,
                color: SheetColors.of(context).secondary,
              ),
            ),
          ),
        ],
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

    final dark = Theme.of(context).brightness == Brightness.dark;
    return HighlightCardShell(
      icon: Icons.emoji_events_outlined,
      glyph: SheetGlyphKind.trophy,
      title: 'Prediction',
      // Board: the trophy in light blue on a blue-tinted tile.
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
                  Text('${formatTimeLeft(left)} to predict'),
            )
          : Text(winner == null ? _statusText : 'Winner: ${winner.title}'),
      footer: _takePart(
        card,
        'Predict on Twitch',
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
        fontFamily: FrostyTokens.bodyFamily,
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
          trailing: '$share%',
          bold: isWinner,
          leading: isWinner
              ? Semantics(
                  label: 'Winner',
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
              Text(_count(outcome.points, 'point', 'points'), style: meta),
              Text(formatRatio(returnRatio(prediction, outcome)), style: meta),
              Text(
                _count(outcome.users, 'predictor', 'predictors'),
                style: meta,
              ),
              if (top != null && top.name.isNotEmpty)
                Text('Top: ${top.name}', style: meta),
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
      // Board: the pinned message at 14 / 1.5, not the 15 / 600 headline.
      style: TextStyle(
        fontFamily: FrostyTokens.bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: SheetColors.of(context).text,
      ),
    );
    return HighlightCardShell(
      icon: Icons.push_pin_outlined,
      glyph: SheetGlyphKind.pin,
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

/// The banner Twitch pins above chat for a gift bomb of five subs or more,
/// drawn to Twitch's own measurements rather than in the highlight card
/// frame: a 74dp card (growing with the text size, up to twice as tall), 8dp
/// clear of its surroundings, with 6dp corners; a 32dp green gift icon;
/// "**Gifter** is gifting 5 Subscriptions!" on a single line; a close
/// button; and a 3dp green bar draining along its bottom edge until the
/// banner leaves.
class GiftBombCard extends StatelessWidget {
  const GiftBombCard({super.key, required this.banner, required this.card});

  final GiftBombBanner banner;
  final HighlightCardContext card;

  /// The card itself, inside its 8dp margin.
  static const cardKey = ValueKey('gift-bomb-card');

  /// The single-line title.
  static const titleKey = ValueKey('gift-bomb-card-title');

  static const _height = 74.0;
  static const _maxTextScale = 2.0;

  @override
  Widget build(BuildContext context) {
    final bomb = banner.bomb;
    final theme = Theme.of(context);
    final accent = context.frostyColors.subNoticeAccent;
    final subscriptions = bomb.count == 1 ? 'Subscription' : 'Subscriptions';
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _maxTextScale);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          key: cardKey,
          color: theme.colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: textScaler.scale(_height),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          size: 32,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label:
                              '${bomb.gifterName} is gifting ${bomb.count} '
                              '$subscriptions',
                          child: ExcludeSemantics(
                            child: Text.rich(
                              key: titleKey,
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: bomb.gifterName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' is gifting ${bomb.count} '
                                        '$subscriptions!',
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ),
                      ),
                      if (card.onDismiss case final onDismiss?)
                        IconButton(
                          tooltip: 'Hide',
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: onDismiss,
                        )
                      else
                        const SizedBox(width: 12),
                    ],
                  ),
                ),
                GiftBombCountdownBar(
                  startedAt: banner.startedAt,
                  endsAt: banner.endsAt,
                  now: card.now,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 3dp bar that drains linearly from [startedAt] to [endsAt] (Twitch time,
/// from [now]). With reduced motion it steps once a second instead.
///
/// The countdown keeps its real duration even when the system removes
/// animations, which would otherwise shorten it to a twentieth.
class GiftBombCountdownBar extends StatefulWidget {
  const GiftBombCountdownBar({
    super.key,
    required this.startedAt,
    required this.endsAt,
    required this.now,
    required this.color,
  });

  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime Function() now;
  final Color color;

  @override
  State<GiftBombCountdownBar> createState() => _GiftBombCountdownBarState();
}

class _GiftBombCountdownBarState extends State<GiftBombCountdownBar>
    with SingleTickerProviderStateMixin {
  // Preserve: the drain is a timer, not a decoration.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Ticks once a second under reduced motion.
  Timer? _stepper;

  /// Whole seconds left, under reduced motion.
  var _stepsLeft = 0;

  bool? _reduceMotion;

  Duration get _total => widget.endsAt.difference(widget.startedAt);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _start();
    }
  }

  @override
  void didUpdateWidget(GiftBombCountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.endsAt != widget.endsAt) {
      _start();
    }
  }

  /// One linear drain, or one step a second, over the time left.
  void _start() {
    _stepper?.cancel();
    _stepper = null;
    _controller.stop();

    final total = _total;
    final left = widget.endsAt.difference(widget.now());
    if (total <= Duration.zero || left <= Duration.zero) {
      _controller.value = 0;
      _stepsLeft = 0;
      return;
    }

    if (_reduceMotion ?? false) {
      _stepsLeft = (left.inMilliseconds / 1000).ceil();
      _stepper = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _stepsLeft--);
        if (_stepsLeft <= 0) timer.cancel();
      });
      return;
    }

    _controller.value = (left.inMicroseconds / total.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    _controller.animateBack(0, duration: left);
  }

  @override
  void dispose() {
    _stepper?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double value) => LinearProgressIndicator(
    value: value.clamp(0.0, 1.0),
    minHeight: 3,
    color: widget.color,
    backgroundColor: widget.color.withValues(alpha: 0.2),
  );

  @override
  Widget build(BuildContext context) {
    final seconds = _total.inMilliseconds / 1000;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: (_reduceMotion ?? false)
          ? _bar(seconds <= 0 ? 0 : _stepsLeft / seconds)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _bar(_controller.value),
            ),
    );
  }
}
