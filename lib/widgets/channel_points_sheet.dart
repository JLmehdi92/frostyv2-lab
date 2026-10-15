import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';

/// The channel points panel: balance, what the channel offers, and any
/// prediction running.
///
/// Spending is done with the viewer's own credential, which is what any
/// official client does on their behalf. Twitch guards some of these mutations
/// with an integrity attestation — measured, not assumed: `claimCommunityPoints`
/// answers "failed integrity check" without one. Nothing here tries to satisfy
/// that check; a refusal is reported as a refusal.
///
/// Built for a landscape tablet, where this opens over a chat column narrow
/// enough that the message box is already collapsing: the panel is height-capped
/// and scrolls, and every label that can grow is ellipsised rather than allowed
/// to wrap the layout apart.
class ChannelPointsSheet extends StatelessWidget {
  final CommunityPointsContext points;

  /// Absent in read-only contexts, where the panel still shows everything but
  /// offers no way to spend.
  final ChannelEventsStore? store;

  const ChannelPointsSheet({super.key, required this.points, this.store});

  static String formatPoints(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      // Thin space every three digits from the right, so a seven-figure reward
      // cost stays readable at a glance.
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final events = store;
    if (events == null) return _Panel(points: points, store: null);

    // Live, so a redeem's new balance lands without reopening the panel.
    return Observer(builder: (_) => _Panel(points: events.points, store: events));
  }
}

class _Panel extends StatelessWidget {
  final CommunityPointsContext points;
  final ChannelEventsStore? store;

  const _Panel({required this.points, required this.store});

  @override
  Widget build(BuildContext context) {
    final colors = context.frostyColors;
    final prediction = points.activePrediction;
    final events = store;
    final canSpend = events != null && points.balance != null;

    return SafeArea(
      child: ConstrainedBox(
        // Landscape leaves very little height. Without a cap the sheet grows
        // past the screen on a channel with a long reward list; with one it
        // scrolls, which is the behaviour that survives both orientations.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (points.pointsImageUrl != null) ...[
                    Image.network(
                      // 4x: this one is larger than the bar's copy.
                      points.pointsImageUrlAt(4)!,
                      width: 20,
                      height: 20,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      points.pointsName?.toUpperCase() ?? 'CHANNEL POINTS',
                      style: context.frostyText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (points.balance != null)
                    Text(
                      ChannelPointsSheet.formatPoints(points.balance!),
                      style: context.frostyText.metadata.copyWith(
                        fontSize: 18,
                        color: colors.live,
                      ),
                    ),
                ],
              ),
            ),

            if (events != null && points.hasClaim)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ClaimButton(store: events),
              ),

            if (points.balance == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Log in to see your balance.',
                  style: TextStyle(color: colors.metadata),
                ),
              ),

            if (prediction != null) ...[
              _SectionLabel(
                prediction.isOpen ? 'PREDICTION — OPEN' : 'PREDICTION — LOCKED',
              ),
              _PredictionCard(
                prediction: prediction,
                balance: points.balance,
                // Only an open prediction takes bets. A locked one still shows
                // its odds, which is why it is rendered at all.
                store: prediction.isOpen && canSpend ? events : null,
              ),
            ],

            if (points.rewards.isNotEmpty) ...[
              const _SectionLabel('REWARDS'),
              ...points.rewards.map(
                (reward) => _RewardTile(
                  reward: reward,
                  balance: points.balance,
                  store: canSpend ? events : null,
                ),
              ),
            ],

            if (points.rewards.isEmpty && prediction == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This channel has no rewards set up.',
                  style: TextStyle(color: colors.metadata),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(text, style: context.frostyText.label),
  );
}

/// Shows the outcome of a points action.
///
/// Deliberately loud and deliberately specific: the integrity refusal is the
/// most informative answer Twitch gives, and reducing it to "failed" would
/// throw away the one thing worth knowing — that nothing is broken and that
/// retrying will not help.
/// A refusal is distinguished by wording and dwell time, not by colour: red is
/// reserved elsewhere in this design, and the accent is built on lightness
/// difference rather than hue, so a tinted background would carry no meaning.
void _report(BuildContext context, PointsActionResult result) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: Duration(seconds: result.isSuccess ? 2 : 6),
      ),
    );
}

/// The bonus chest, shown only while Twitch is actually offering one.
///
/// Whether Twitch accepts the claim from this client is genuinely unknown: the
/// integrity refusal was measured once and it is not recorded whether that
/// attempt carried a real token. The button exists so the question gets a real
/// answer instead of an assumption — and if the answer is no, the refusal says
/// so in as many words.
class _ClaimButton extends StatelessWidget {
  final ChannelEventsStore store;

  const _ClaimButton({required this.store});

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      // Measured on 2026-07-31 with a real token: Twitch answers
      // `failed integrity check`. Once it has said no, the button stops
      // inviting a retry — eight taps in twelve seconds were all refused, and
      // a control that keeps offering an impossible action is a lie.
      final blocked = store.isIntegrityBlocked(claimAction);

      if (blocked) {
        return Row(
          children: [
            Icon(
              Icons.block_rounded,
              size: 16,
              color: context.frostyColors.metadata,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Twitch blocks collecting the bonus from here — its anti-bot '
                'check. Collect it on twitch.tv and the balance follows.',
                style: context.frostyText.metadata.copyWith(fontSize: 11),
              ),
            ),
          ],
        );
      }

      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: store.pointsActionInFlight
              ? null
              : () => _claim(context),
          icon: const Icon(Icons.card_giftcard_rounded, size: 18),
          label: const Text('Collect bonus'),
        ),
      );
    },
  );

  Future<void> _claim(BuildContext context) async {
    final result = await store.claimBonus();

    if (!context.mounted) return;
    _report(context, result);
  }
}

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;
  final int? balance;

  /// Null when betting is not on offer — locked, signed out, or no store.
  final ChannelEventsStore? store;

  const _PredictionCard({
    required this.prediction,
    required this.balance,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final total = prediction.totalPoints;
    final events = store;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prediction.title,
            style: context.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          ...prediction.outcomes.map((outcome) {
            final odds = outcome.odds(total);
            final share = total <= 0 ? 0.0 : outcome.totalPoints / total;

            final body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outcome.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      odds == null ? '—' : '${odds.toStringAsFixed(2)} ×',
                      style: context.frostyText.metadata,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(FrostyTokens.radiusSmall),
                  ),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 3,
                    backgroundColor: context.frostyColors.hairline,
                    valueColor: AlwaysStoppedAnimation(
                      context.frostyColors.live,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ChannelPointsSheet.formatPoints(outcome.totalPoints)}'
                  '  ·  ${outcome.totalUsers} '
                  '${outcome.totalUsers == 1 ? 'viewer' : 'viewers'}',
                  style: context.frostyText.metadata.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );

            if (events == null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: body,
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: const BorderRadius.all(
                  Radius.circular(FrostyTokens.radiusSmall),
                ),
                onTap: () => _openBetSheet(context, events, outcome),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: body,
                ),
              ),
            );
          }),
          if (events != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                'Tap an outcome to bet.',
                style: context.frostyText.metadata.copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openBetSheet(
    BuildContext context,
    ChannelEventsStore events,
    PredictionOutcome outcome,
  ) async {
    final messengerContext = context;

    final stake = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BetSheet(
        prediction: prediction,
        outcome: outcome,
        balance: balance ?? 0,
      ),
    );

    if (stake == null) return;

    final result = await events.placePrediction(
      eventId: prediction.id,
      outcomeId: outcome.id,
      points: stake,
    );

    if (!messengerContext.mounted) return;
    _report(messengerContext, result);
  }
}

/// Picks a stake for one outcome.
///
/// Presets rather than a free slider: this opens over a narrow landscape chat
/// column where a drag target would be both cramped and easy to misfire, and
/// the amounts people actually bet cluster on round numbers anyway. The exact
/// field is there for everything else.
class _BetSheet extends StatefulWidget {
  final Prediction prediction;
  final PredictionOutcome outcome;
  final int balance;

  const _BetSheet({
    required this.prediction,
    required this.outcome,
    required this.balance,
  });

  @override
  State<_BetSheet> createState() => _BetSheetState();
}

class _BetSheetState extends State<_BetSheet> {
  /// Twitch's own floor, and the amount worth risking to learn whether the
  /// mutation passes the integrity check at all.
  static const _minimumStake = 10;

  static const _presets = [10, 100, 1000, 10000];

  late int _stake = _minimumStake;
  late final _controller = TextEditingController(text: '$_minimumStake');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setStake(int value) {
    final clamped = value.clamp(_minimumStake, widget.balance);
    setState(() => _stake = clamped);
    _controller.text = '$clamped';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frostyColors;
    final affordable = widget.balance >= _minimumStake;

    // Payout is quoted against the pot as it stands, which is what Twitch
    // shows too — it moves with every other bet, so this is an indication and
    // labelled as one rather than a promise.
    final projectedPot = widget.prediction.totalPoints + _stake;
    final projectedOutcome = widget.outcome.totalPoints + _stake;
    final odds = projectedOutcome <= 0 ? null : projectedPot / projectedOutcome;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text('BET ON', style: context.frostyText.label),
              const SizedBox(height: 6),
              Text(
                widget.outcome.title,
                style: context.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Balance ${ChannelPointsSheet.formatPoints(widget.balance)}',
                style: context.frostyText.metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              if (!affordable)
                Text(
                  'You need at least $_minimumStake points to bet.',
                  style: TextStyle(color: colors.metadata),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _presets)
                      if (preset <= widget.balance)
                        ChoiceChip(
                          label: Text(
                            ChannelPointsSheet.formatPoints(preset),
                          ),
                          selected: _stake == preset,
                          onSelected: (_) => _setStake(preset),
                        ),
                    ChoiceChip(
                      label: const Text('Max'),
                      selected: _stake == widget.balance,
                      onSelected: (_) => _setStake(widget.balance),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null) setState(() => _stake = parsed);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  odds == null
                      ? 'No odds yet.'
                      : 'Pays about ${odds.toStringAsFixed(2)} × '
                            'if this wins — moves with every other bet.',
                  style: context.frostyText.metadata.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _stake >= _minimumStake && _stake <= widget.balance
                      ? () => Navigator.of(context).pop(_stake)
                      : null,
                  child: Text(
                    'Bet ${ChannelPointsSheet.formatPoints(_stake)}',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final PointsReward reward;
  final int? balance;

  /// Null when redeeming is not on offer.
  final ChannelEventsStore? store;

  const _RewardTile({
    required this.reward,
    required this.balance,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final affordable = reward.affordableWith(balance);
    final events = store;

    return ListTile(
      // Out of reach means no tap target: offering one that can only fail is
      // worse than offering none.
      onTap: events == null || !affordable || !reward.isRedeemable
          ? null
          : () => _confirmAndRedeem(context, events),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: reward.backgroundColor ?? context.frostyColors.hairline,
          borderRadius: const BorderRadius.all(
            Radius.circular(FrostyTokens.radiusSmall),
          ),
        ),
        child: reward.imageUrl == null
            ? null
            : ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(FrostyTokens.radiusSmall),
                ),
                child: Image.network(
                  reward.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
      ),
      title: Text(
        reward.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        ChannelPointsSheet.formatPoints(reward.cost),
        // Dimmed when out of reach, so the list reads at a glance rather than
        // needing the numbers compared one by one.
        style: context.frostyText.metadata.copyWith(
          color: affordable
              ? context.frostyColors.live
              : context.frostyColors.metadata,
        ),
      ),
      trailing: events == null || !affordable || !reward.isRedeemable
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.frostyColors.metadata,
            ),
    );
  }

  Future<void> _confirmAndRedeem(
    BuildContext context,
    ChannelEventsStore events,
  ) async {
    final messengerContext = context;

    final input = await showDialog<String?>(
      context: context,
      builder: (_) => _RedeemDialog(reward: reward),
    );

    // Null means dismissed. The dialog returns an empty string for a reward
    // that takes no text, which is a confirmation, not a cancellation.
    if (input == null) return;

    final result = await events.redeemReward(
      reward,
      userInput: input.isEmpty ? null : input,
    );

    if (!messengerContext.mounted) return;
    _report(messengerContext, result);
  }
}

/// Confirms a redemption, and collects the viewer's text when the reward asks
/// for one.
///
/// A confirmation step rather than a bare tap because this spends a real
/// balance and there is no undo on Twitch's side.
class _RedeemDialog extends StatefulWidget {
  final PointsReward reward;

  const _RedeemDialog({required this.reward});

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsInput = widget.reward.requiresInput;

    return AlertDialog(
      title: Text(widget.reward.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend ${ChannelPointsSheet.formatPoints(widget.reward.cost)} '
            'points?',
          ),
          if (needsInput) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your message',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Twitch rejects an empty prompt on a reward that requires one, so
          // the button waits rather than sending a request that cannot work.
          onPressed: needsInput && _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
