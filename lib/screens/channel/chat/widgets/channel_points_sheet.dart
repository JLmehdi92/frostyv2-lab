import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

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

  /// The tablet panel above the points pill (board ChaineOutilsTablette).
  static const panelSize = Size(384, 562);

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
    return Observer(
      builder: (_) => _Panel(
        points: events.points,
        store: events,
        watchStreak: events.watchStreak,
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  final CommunityPointsContext points;
  final ChannelEventsStore? store;

  /// The viewer's watch streak here, which Twitch shows atop this panel.
  final WatchStreak? watchStreak;

  const _Panel({required this.points, required this.store, this.watchStreak});

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  /// The outcome being bet on inside a tablet panel (board
  /// ChaineOutilsTablette: the bet replaces the list in the same panel).
  PredictionOutcome? _betOn;

  /// The prediction [_betOn] belongs to: a bet view left open across a new
  /// prediction must not send the old outcome against the new event.
  String? _betPrediction;

  Future<void> _bet(
    BuildContext context,
    ChannelEventsStore events,
    Prediction prediction,
    PredictionOutcome outcome,
  ) async {
    final balance = widget.points.balance ?? 0;
    if (SheetPresentation.isPanel(context)) {
      setState(() {
        _betOn = outcome;
        _betPrediction = prediction.id;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final stake = await showOnsetSheet<int>(
      context: context,
      panel: true,
      builder: (context) => BetSheet(
        prediction: prediction,
        outcome: outcome,
        balance: balance,
        onBet: (stake) => Navigator.of(context).pop(stake),
      ),
    );
    if (stake == null) return;
    final result = await events.placePrediction(
      eventId: prediction.id,
      outcomeId: outcome.id,
      points: stake,
    );
    _report(messenger, result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final points = widget.points;
    final prediction = points.activePrediction;
    final events = widget.store;
    final canSpend = events != null && points.balance != null;
    final panel = SheetPresentation.isPanel(context);

    // The outcome as it stands now (its pot moves with every bet), and only
    // while the prediction it was picked from is still open.
    final picked = _betOn;
    final betOn = picked == null || prediction?.id != _betPrediction
        ? null
        : prediction?.outcomes
              .where((outcome) => outcome.id == picked.id)
              .firstOrNull;
    if (betOn != null &&
        events != null &&
        prediction != null &&
        prediction.isOpen) {
      return BetSheet(
        prediction: prediction,
        outcome: betOn,
        balance: points.balance ?? 0,
        onBack: () => setState(() {
          _betOn = null;
          _betPrediction = null;
        }),
        onBet: (stake) {
          // The panel closes with the bet, as the board's does.
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          navigator.pop();
          unawaited(
            events
                .placePrediction(
                  eventId: prediction.id,
                  outcomeId: betOn.id,
                  points: stake,
                )
                .then((result) {
                  _report(messenger, result);
                }),
          );
        },
      );
    }

    final balanceText = points.balance == null
        ? null
        : ChannelPointsSheet.formatPoints(points.balance!);

    return ConstrainedBox(
      // Landscape leaves very little height. Without a cap the sheet grows
      // past the screen on a channel with a long reward list; with one it
      // scrolls, which is the behaviour that survives both orientations.
      constraints: BoxConstraints(
        maxHeight: panel
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Board ChainePoints: the points mark, the name, the balance.
          Padding(
            padding: EdgeInsets.fromLTRB(16, panel ? 14 : 6, 16, 12),
            child: Row(
              spacing: 10,
              children: [
                if (points.pointsImageUrl != null)
                  Image.network(
                    // 4x: this one is larger than the bar's copy.
                    points.pointsImageUrlAt(4)!,
                    width: 20,
                    height: 20,
                    errorBuilder: (_, _, _) => _PointsRing(size: 20),
                  )
                else
                  const _PointsRing(size: 20),
                Expanded(
                  child: Text(
                    points.pointsName?.toUpperCase() ?? 'CHANNEL POINTS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetText.section.copyWith(color: colors.secondary),
                  ),
                ),
                if (balanceText != null)
                  Text(
                    balanceText,
                    style: SheetText.tabular(
                      TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.44,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: !panel,
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                if (widget.watchStreak case final streak?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: WatchStreakCard(
                      streak: streak,
                      live: events?.isChannelLive?.call() ?? true,
                      channelName:
                          events?.channelName ?? events?.channelLogin ?? '',
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
                      style: SheetText.body.copyWith(color: colors.secondary),
                    ),
                  ),

                if (prediction != null) ...[
                  SheetSectionLabel(
                    prediction.isOpen
                        ? 'Prediction — open'
                        : 'Prediction — locked',
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  ),
                  _PredictionCard(
                    prediction: prediction,
                    // Only an open prediction takes bets. A locked one still
                    // shows its odds, which is why it is rendered at all.
                    onBet: prediction.isOpen && canSpend
                        ? (outcome) =>
                              _bet(context, events, prediction, outcome)
                        : null,
                  ),
                ],

                if (points.rewards.isNotEmpty) ...[
                  const SheetSectionLabel('Rewards'),
                  ...points.rewards.map(
                    (reward) => RewardRow(
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
                      style: SheetText.body.copyWith(color: colors.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The boards' generic points mark: a ring in the signal colour.
class _PointsRing extends StatelessWidget {
  const _PointsRing({required this.size, this.stroke = 2.5, this.color});

  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: color ?? SheetColors.accentOf(context),
        width: stroke,
      ),
    ),
  );
}

/// The viewer's watch streak, worded like Twitch's channel points panel.
/// Read from Twitch, never advanced here.
class WatchStreakCard extends StatelessWidget {
  const WatchStreakCard({
    super.key,
    required this.streak,
    required this.live,
    required this.channelName,
  });

  final WatchStreak streak;
  final bool live;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final copy = streak.copy(
      live: live,
      channelName: channelName,
      now: DateTime.now(),
    );
    final next = streak.threshold;
    final showProgress =
        next != null && streak.state != WatchStreakState.suspended;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green = dark ? OnsetTokens.hypeText : OnsetTokens.hypeTextLight;

    // Board ChainePoints: a #1A1A1A card, the green flame, the community
    // green bar towards the next milestone.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SheetPresentation.isPanel(context)
            ? (dark ? const Color(0xFF202020) : colors.well)
            : colors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Row(
              spacing: 8,
              children: [
                SheetGlyph(
                  SheetGlyphKind.flame,
                  strokeWidth: 1.9,
                  color: green,
                ),
                Expanded(
                  child: Text(
                    copy.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
                if (showProgress)
                  Text(
                    '${streak.value}/$next',
                    style: SheetText.tabular(
                      TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (showProgress)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (streak.value / next).clamp(0.0, 1.0),
                    minHeight: 4,
                    color: OnsetTokens.hype,
                    backgroundColor: OnsetTokens.hype.withValues(alpha: 0.2),
                  ),
                ),
              ),
            if (copy.subtitle case final subtitle?)
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 13,
                  height: 1.35,
                  color: colors.body,
                ),
              ),
            Text(
              'Twitch counts streaks. Watching in this app may not count '
              'toward them.',
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 12,
                height: 1.45,
                color: colors.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
/// Says how a points action went. [messenger] is taken before the wait:
/// the sheet or panel that started it may be gone by the answer (a tablet
/// panel closes on a rotation, even under its confirm dialog), the app's
/// messenger is not.
void _report(ScaffoldMessengerState messenger, PointsActionResult result) {
  if (!messenger.mounted) return;
  messenger
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
      final colors = SheetColors.of(context);

      if (blocked) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SheetGlyph(
                SheetGlyphKind.block,
                size: 15,
                color: colors.tertiary,
              ),
            ),
            Expanded(
              child: Text(
                'Twitch blocks collecting the bonus from here — its anti-bot '
                'check. Collect it on twitch.tv and the balance follows.',
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 12,
                  height: 1.45,
                  color: colors.secondary,
                ),
              ),
            ),
          ],
        );
      }

      return SheetButton(
        label: 'Collect bonus',
        expand: true,
        icon: SheetGlyph(
          SheetGlyphKind.gift,
          size: 18,
          strokeWidth: 2,
          color: store.pointsActionInFlight
              ? colors.disabledText
              : SheetColors.onAccentOf(context),
        ),
        onPressed: store.pointsActionInFlight ? null : () => _claim(context),
      );
    },
  );

  Future<void> _claim(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await store.claimBonus();
    _report(messenger, result);
  }
}

/// Twitch's prediction colours, for an outcome.
Color _outcomeColor(
  BuildContext context,
  PredictionOutcome outcome,
  int index,
) => switch (outcome.color.toUpperCase()) {
  'BLUE' => const Color(0xFF387AFF),
  'PINK' => const Color(0xFFF5009B),
  _ => index.isEven ? const Color(0xFF387AFF) : const Color(0xFFF5009B),
};

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;

  /// Null when betting is not on offer — locked, signed out, or no store.
  final ValueChanged<PredictionOutcome>? onBet;

  const _PredictionCard({required this.prediction, required this.onBet});

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final total = prediction.totalPoints;
    final onBet = this.onBet;
    final duration = motionDuration(context, const Duration(milliseconds: 420));

    // The outcomes reach 8 dp past the text on each side (board: the tap
    // area is wider than the column, the text lines up with it).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              prediction.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: colors.text,
              ),
            ),
          ),
          for (final (index, outcome) in prediction.outcomes.indexed)
            Builder(
              builder: (context) {
                final odds = outcome.odds(total);
                final share = total <= 0 ? 0.0 : outcome.totalPoints / total;
                final color = _outcomeColor(context, outcome, index);
                final body = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              outcome.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ),
                          Text(
                            odds == null ? '—' : '${odds.toStringAsFixed(2)} ×',
                            style: SheetText.tabular(
                              TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.body,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(color: colors.hairline),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: share.clamp(0.0, 1.0)),
                                duration: duration,
                                curve: OnsetMotion.standard,
                                builder: (context, value, _) =>
                                    FractionallySizedBox(
                                      widthFactor: value,
                                      heightFactor: 1,
                                      child: ColoredBox(color: color),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '${ChannelPointsSheet.formatPoints(outcome.totalPoints)}'
                        '  ·  ${outcome.totalUsers} '
                        '${outcome.totalUsers == 1 ? 'viewer' : 'viewers'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SheetText.tabular(
                          TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: onBet == null
                      ? body
                      : Semantics(
                          button: true,
                          label:
                              'Bet on ${outcome.title}, pays '
                              '${odds == null ? 'unknown' : '${odds.toStringAsFixed(2)} times'}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onBet(outcome),
                              child: ExcludeSemantics(child: body),
                            ),
                          ),
                        ),
                );
              },
            ),
          if (onBet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Text(
                'Tap an outcome to bet.',
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 11.5,
                  color: colors.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks a stake for one outcome (board ChainePoints' bet sheet; inside the
/// panel on a tablet, with a way back to the list).
///
/// Presets rather than a free slider: this opens over a narrow landscape chat
/// column where a drag target would be both cramped and easy to misfire, and
/// the amounts people actually bet cluster on round numbers anyway. The exact
/// field is there for everything else.
class BetSheet extends StatefulWidget {
  final Prediction prediction;
  final PredictionOutcome outcome;
  final int balance;

  /// Called with the stake when the viewer bets.
  final ValueChanged<int> onBet;

  /// Back to the list (a tablet's panel); null in a sheet.
  final VoidCallback? onBack;

  const BetSheet({
    super.key,
    required this.prediction,
    required this.outcome,
    required this.balance,
    required this.onBet,
    this.onBack,
  });

  @override
  State<BetSheet> createState() => _BetSheetState();
}

class _BetSheetState extends State<BetSheet> {
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
    final colors = SheetColors.of(context);
    final affordable = widget.balance >= _minimumStake;
    final index = widget.prediction.outcomes.indexOf(widget.outcome);
    final color = _outcomeColor(context, widget.outcome, index);
    final panel = widget.onBack != null;

    // Payout is quoted against the pot as it stands, which is what Twitch
    // shows too — it moves with every other bet, so this is an indication and
    // labelled as one rather than a promise.
    final projectedPot = widget.prediction.totalPoints + _stake;
    final projectedOutcome = widget.outcome.totalPoints + _stake;
    final odds = projectedOutcome <= 0 ? null : projectedPot / projectedOutcome;
    final canBet = _stake >= _minimumStake && _stake <= widget.balance;

    final label = Text(
      'BET ON',
      style: SheetText.section.copyWith(color: colors.secondary),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: panel ? 0 : MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: panel
              ? double.infinity
              : MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: ListView(
          shrinkWrap: !panel,
          padding: EdgeInsets.fromLTRB(16, panel ? 6 : 8, 16, 18),
          children: [
            if (widget.onBack case final back?)
              Row(
                children: [
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: back,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                      icon: SheetGlyph(
                        SheetGlyphKind.chevronLeft,
                        size: 22,
                        strokeWidth: 2,
                        color: colors.text,
                      ),
                    ),
                  ),
                  label,
                ],
              )
            else
              label,
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                spacing: 8,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.outcome.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SheetText.title.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Balance ${ChannelPointsSheet.formatPoints(widget.balance)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 13,
                    color: colors.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!affordable)
              Text(
                'You need at least $_minimumStake points to bet.',
                style: SheetText.body.copyWith(color: colors.secondary),
              )
            else ...[
              Semantics(
                container: true,
                label: 'Stake',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _presets)
                      if (preset <= widget.balance)
                        SheetChoicePill(
                          label: ChannelPointsSheet.formatPoints(preset),
                          large: true,
                          tabular: true,
                          selected: _stake == preset,
                          onSelected: () => _setStake(preset),
                        ),
                    SheetChoicePill(
                      label: 'Max',
                      large: true,
                      selected: _stake == widget.balance,
                      onSelected: () => _setStake(widget.balance),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SheetTextField(
                controller: _controller,
                label: 'Points',
                keyboardType: TextInputType.number,
                // A pasted "1,500" or "2e3" is not a stake.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                fill: colors.field,
                textStyle: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                // An empty or unreadable field is no stake: keeping the
                // last one would leave "Bet 500" armed over a blank field.
                onChanged: (value) =>
                    setState(() => _stake = int.tryParse(value.trim()) ?? 0),
              ),
              const SizedBox(height: 10),
              Text(
                odds == null
                    ? 'No odds yet.'
                    : 'Pays about ${odds.toStringAsFixed(2)} × '
                          'if this wins — moves with every other bet.',
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 12,
                  height: 1.45,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              SheetButton(
                label: _stake > 0
                    ? 'Bet ${ChannelPointsSheet.formatPoints(_stake)}'
                    : 'Bet',
                large: true,
                expand: true,
                onPressed: canBet ? () => widget.onBet(_stake) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A reward: its tile, title and cost (board ChainePoints); dimmed and not
/// tappable when out of reach.
class RewardRow extends StatelessWidget {
  final PointsReward reward;
  final int? balance;

  /// Null when redeeming is not on offer.
  final ChannelEventsStore? store;

  const RewardRow({
    super.key,
    required this.reward,
    required this.balance,
    required this.store,
  });

  /// What a tap does; null when the reward cannot be redeemed from here.
  VoidCallback? onTapFor(BuildContext context) {
    final events = store;
    // Out of reach means no tap target: offering one that can only fail is
    // worse than offering none.
    if (events == null ||
        !reward.affordableWith(balance) ||
        !reward.isRedeemable) {
      return null;
    }
    return () => _confirmAndRedeem(context, events);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final affordable = reward.affordableWith(balance);
    final onTap = onTapFor(context);
    final panel = SheetPresentation.isPanel(context);
    // Dimmed when out of reach, so the list reads at a glance rather than
    // needing the numbers compared one by one.
    final costColor = affordable ? colors.text : colors.tertiary;

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: Opacity(
        opacity: affordable ? 1 : 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: panel ? 56 : 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: panel ? 34 : 36,
                      height: panel ? 34 : 36,
                      decoration: BoxDecoration(
                        color: reward.backgroundColor ?? colors.raised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: reward.imageUrl == null
                          ? null
                          : Image.network(
                              reward.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [
                          Text(
                            reward.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: panel ? 14 : 14.5,
                              fontWeight: FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              _PointsRing(
                                size: panel ? 10 : 11,
                                stroke: 1.8,
                                color: costColor,
                              ),
                              Text(
                                ChannelPointsSheet.formatPoints(reward.cost),
                                style: SheetText.tabular(
                                  TextStyle(
                                    fontFamily: OnsetTokens.bodyFamily,
                                    fontSize: panel ? 12 : 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: costColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      SheetGlyph(
                        SheetGlyphKind.chevronRight,
                        size: 18,
                        strokeWidth: 2,
                        color: colors.tertiary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRedeem(
    BuildContext context,
    ChannelEventsStore events,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

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
    _report(messenger, result);
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

  /// The longest reward message sent: past it a chat line is unreadable.
  static const maxMessageLength = 200;

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
    final colors = SheetColors.of(context);

    return OnsetDialog(
      title: widget.reward.title,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.reward.backgroundColor ?? colors.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.reward.imageUrl == null
            ? null
            : Image.network(
                widget.reward.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      ),
      message:
          'Spend ${ChannelPointsSheet.formatPoints(widget.reward.cost)} '
          'points?',
      content: needsInput
          ? SheetTextField(
              controller: _controller,
              label: 'Your message',
              autofocus: true,
              maxLength: _RedeemDialog.maxMessageLength,
              counter: true,
              onChanged: (_) => setState(() {}),
            )
          : null,
      actions: [
        SheetButton(
          label: 'Cancel',
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SheetButton(
          label: 'Redeem',
          // Twitch rejects an empty prompt on a reward that requires one, so
          // the button waits rather than sending a request that cannot work.
          onPressed: needsInput && _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
