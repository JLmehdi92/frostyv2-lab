import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/hype_train_math.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// Twitch's guide to hype trains.
const htHelpUrl = 'https://help.twitch.tv/s/article/hype-train-guide';

/// The train's details, laid out like Twitch's expanded hype train: the
/// variant card, the level target, the shared contributions, the
/// conductors, the rewards, the record and "More Info". It follows the
/// store live. There is nothing to buy here (D4).
class HypeTrainSheet extends StatelessWidget {
  const HypeTrainSheet({
    super.key,
    required this.store,
    required this.onLearnMore,
  });

  final HypeTrainStore store;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final train = store.train;
        final approaching = store.approaching;
        final neutrals = HtNeutrals.of(Theme.of(context).brightness);
        if (store.phase == HtPhase.approaching && approaching != null) {
          return _ApproachingDetails(
            store: store,
            approaching: approaching,
            neutrals: neutrals,
          );
        }
        if (train == null) return const SizedBox(width: double.infinity);
        final palette = htPaletteOf(context, store);
        final footnote = HtType.footnote.copyWith(color: neutrals.textBase);
        return Padding(
          padding: const EdgeInsets.only(bottom: HtDims.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_variantLine(train) case final line?)
                _VariantCard(
                  train: train,
                  line: line,
                  palette: palette,
                  neutrals: neutrals,
                  onLearnMore: onLearnMore,
                ),
              _padded(
                top: 16,
                child: Text(
                  isFinalLevel(train)
                      ? HtCopy.finalLevel
                      : HtCopy.levelTarget(
                          train.level,
                          store.levelTarget.subs,
                          store.levelTarget.bits,
                        ),
                  style: footnote,
                ),
              ),
              if (train.shared case final shared?) ...[
                _Header(HtCopy.contributionsHeader, neutrals: neutrals),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    height: HtDims.avatar,
                    child: HypeTrainContributions(
                      shares: topShares(shared),
                      color: neutrals.textBase,
                    ),
                  ),
                ),
              ],
              _Header(HtCopy.conductorsHeader, neutrals: neutrals),
              _padded(
                top: HtDims.marginHalf,
                child: Text(HtCopy.conductorsDescription, style: footnote),
              ),
              _padded(
                top: HtDims.margin,
                child: Row(
                  key: const ValueKey('ht-conductors'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final source in const [HtSource.subs, HtSource.bits])
                      Expanded(
                        key: ValueKey('ht-conductor-${source.name}'),
                        child: _ConductorCell(
                          source: source,
                          conductor: train.conductors
                              .where((c) => c.source == source)
                              .firstOrNull,
                          badgeUrl: train.config.conductorBadges[source],
                          style: footnote,
                        ),
                      ),
                  ],
                ),
              ),
              _Header(HtCopy.rewardsHeader, neutrals: neutrals),
              _padded(
                top: HtDims.marginHalf,
                child: Text(
                  train.variant == HtVariant.goldenKappa
                      ? HtCopy.goldenRewardsDescription
                      : HtCopy.rewardsDescription,
                  style: footnote,
                ),
              ),
              _padded(
                top: HtDims.margin,
                child: Text(
                  HtCopy.levelEmotes(train.level),
                  textAlign: TextAlign.center,
                  style: HtType.bodySmall.copyWith(color: neutrals.textBase),
                ),
              ),
              _padded(
                top: HtDims.margin,
                child: _RewardRow(
                  rewards: train.progress.level.rewards,
                  locked: true,
                ),
              ),
              if (store.unlockedRewards.isNotEmpty) ...[
                _Header(HtCopy.unlockedSoFar, neutrals: neutrals),
                _padded(
                  top: HtDims.margin,
                  child: _RewardRow(
                    rewards: store.unlockedRewards,
                    locked: false,
                  ),
                ),
              ],
              _padded(
                top: HtDims.margin,
                child: _UpcomingRewards(
                  key: ValueKey('ht-upcoming-${train.id}'),
                  store: store,
                  trainId: train.id,
                  neutrals: neutrals,
                ),
              ),
              if (train.ath case final ath?)
                _padded(
                  top: HtDims.margin,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: HtDims.marginHalf,
                            ),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: neutrals.textBase,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: HtCopy.channelRecord(
                            athPercent(train.progress.total, ath),
                            ath.level,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: HtType.footnoteSemibold.copyWith(
                      color: neutrals.textBase,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: HtDims.marginHalf),
                child: Center(
                  child: TextButton(
                    onPressed: onLearnMore,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.link,
                      visualDensity: VisualDensity.compact,
                      textStyle: HtType.titleExtraSmall,
                    ),
                    child: const Text(HtCopy.moreInfo),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _padded({required double top, required Widget child}) =>
      Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);

  static String? _variantLine(HypeTrainExecution train) {
    switch (train.variant) {
      case HtVariant.treasure:
        final treasure = train.treasure;
        if (treasure == null) return null;
        return HtCopy.treasureCard(
          treasure.threshold,
          treasure.discountPercentage,
          unlocked: train.level >= treasure.threshold,
        );
      case HtVariant.community:
        final community = train.community;
        if (community == null) return null;
        return HtCopy.communityCard(
          community.threshold,
          community.current,
          unlocked: train.level >= community.threshold,
        );
      case HtVariant.mythic:
        return HtCopy.mythicCard(train.mythic?.pool.length ?? 0);
      case HtVariant.goldenKappa:
        return HtCopy.goldenCard;
      case HtVariant.regular:
        return null;
    }
  }
}

/// A section title, 16 dp below the previous one: board ChaineHypeDetail's
/// label (11 / 700, wide tracking, upper case) in the community green.
class _Header extends StatelessWidget {
  const _Header(this.title, {required this.neutrals});

  final String title;
  final HtNeutrals neutrals;

  /// The board's section label.
  static const style = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.54,
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: style.copyWith(
            color: dark ? OnsetTokens.hypeText : OnsetTokens.hypeTextLight,
          ),
        ),
      ),
    );
  }
}

/// What the variant adds, on Twitch's bordered card: its icon, its name
/// and a line with a "learn more" link.
class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.train,
    required this.line,
    required this.palette,
    required this.neutrals,
    required this.onLearnMore,
  });

  final HypeTrainExecution train;
  final String line;
  final HtPalette palette;
  final HtNeutrals neutrals;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final mythic = train.variant == HtVariant.mythic ? train.mythic : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HtDims.margin,
        HtDims.margin,
        HtDims.margin,
        0,
      ),
      child: DecoratedBox(
        key: const ValueKey('ht-variant-card'),
        decoration: BoxDecoration(
          color: neutrals.backgroundAlt,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: neutrals.borderBase),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            HtDims.margin,
            HtDims.marginQuarter,
            HtDims.margin,
            HtDims.margin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      palette.icon,
                      size: 32,
                      color: palette.checkPill,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      HtCopy.trainTitle(
                        train.variant,
                        shared: train.shared != null,
                      ),
                      style: HtType.bodySemibold.copyWith(
                        color: neutrals.textAlt2,
                      ),
                    ),
                  ),
                ],
              ),
              _LinkedLine(
                line: line,
                link: palette.link,
                style: HtType.bodySmall.copyWith(
                  fontSize: 13,
                  height: 1.2,
                  color: neutrals.textAlt,
                ),
                onLearnMore: onLearnMore,
              ),
              if (mythic != null && mythic.pool.isNotEmpty) ...[
                const SizedBox(height: HtDims.margin),
                _RewardRow(rewards: mythic.pool, locked: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The variant line, then a "learn more" link in the link colour.
class _LinkedLine extends StatefulWidget {
  const _LinkedLine({
    required this.line,
    required this.link,
    required this.style,
    required this.onLearnMore,
  });

  final String line;
  final Color link;
  final TextStyle style;
  final VoidCallback onLearnMore;

  @override
  State<_LinkedLine> createState() => _LinkedLineState();
}

class _LinkedLineState extends State<_LinkedLine> {
  late final _recognizer = TapGestureRecognizer()
    ..onTap = () => widget.onLearnMore();

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '${widget.line} '),
        TextSpan(
          text: HtCopy.learnMore,
          recognizer: _recognizer,
          style: TextStyle(
            color: widget.link,
            decoration: TextDecoration.underline,
            decorationColor: widget.link,
          ),
        ),
      ],
    ),
    style: widget.style,
  );
}

/// One conductor: the badge, then "**name** has contributed n Subs!" or
/// the invitation to take the spot.
class _ConductorCell extends StatelessWidget {
  const _ConductorCell({
    required this.source,
    required this.conductor,
    required this.badgeUrl,
    required this.style,
  });

  final HtSource source;
  final HtConductor? conductor;
  final String? badgeUrl;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final conductor = this.conductor;
    final bits = source == HtSource.bits;
    final amount = conductor == null
        ? ''
        : bits
        ? HtCopy.bitsConductor(conductor.amount)
        : HtCopy.subsConductor(conductor.amount);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: HtDims.margin),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            key: const ValueKey('ht-conductor-badge'),
            dimension: HtDims.reward,
            child: badgeUrl != null
                ? OnsetCachedNetworkImage(imageUrl: badgeUrl!)
                : Icon(
                    bits ? Icons.diamond_rounded : Icons.star_rounded,
                    size: 20,
                    color: style.color,
                  ),
          ),
          const SizedBox(width: HtDims.marginHalf),
          Expanded(
            child: conductor == null
                ? Text(
                    bits ? HtCopy.noBitsConductor : HtCopy.noSubsConductor,
                    style: style,
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: conductor.user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' $amount'),
                      ],
                    ),
                    style: style,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Emotes centred 16 dp apart, 28 dp each; a locked one carries a 9 dp
/// padlock at its bottom end.
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.rewards, required this.locked});

  final List<HtReward> rewards;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final emotes = [
      for (final reward in rewards)
        if (reward.emoteUrl != null) reward,
    ];
    if (emotes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: HtDims.margin,
      children: [
        for (final reward in emotes)
          Semantics(
            label:
                '${locked ? 'Locked' : 'Unlocked'} reward '
                '${reward.token ?? reward.id}',
            excludeSemantics: true,
            child: SizedBox.square(
              key: const ValueKey('ht-reward'),
              dimension: HtDims.reward,
              child: Stack(
                children: [
                  OnsetCachedNetworkImage(
                    imageUrl: reward.emoteUrl.toString(),
                    width: HtDims.reward,
                    height: HtDims.reward,
                  ),
                  if (locked)
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Container(
                        key: const ValueKey('ht-reward-lock'),
                        width: HtDims.lock,
                        height: HtDims.lock,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Coming up": fetched on first expand only.
class _UpcomingRewards extends StatefulWidget {
  const _UpcomingRewards({
    super.key,
    required this.store,
    required this.trainId,
    required this.neutrals,
  });

  final HypeTrainStore store;
  final String trainId;
  final HtNeutrals neutrals;

  @override
  State<_UpcomingRewards> createState() => _UpcomingRewardsState();
}

class _UpcomingRewardsState extends State<_UpcomingRewards> {
  var _requested = false;

  /// Null while loading.
  List<(int, List<HtReward>)>? _levels;

  void _load() {
    if (_requested) return;
    _requested = true;
    widget.store.loadUpcomingRewards().then((levels) {
      if (mounted) setState(() => _levels = levels);
    });
  }

  Widget _body() {
    final style = HtType.bodySmall.copyWith(color: widget.neutrals.textBase);
    final loaded = _levels;
    if (loaded == null) {
      return const Padding(
        padding: EdgeInsets.all(HtDims.margin),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final current = widget.store.train?.level ?? 0;
    final levels = loaded.where((l) => l.$1 > current).toList();
    if (levels.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(HtCopy.nothingMore, style: style),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (level, rewards) in levels.take(10)) ...[
          Text(
            HtCopy.levelEmotes(level),
            textAlign: TextAlign.center,
            style: style,
          ),
          const SizedBox(height: HtDims.marginHalf),
          _RewardRow(rewards: rewards, locked: true),
          const SizedBox(height: HtDims.margin),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('ht-upcoming-${widget.trainId}'),
        tilePadding: EdgeInsets.zero,
        dense: true,
        iconColor: widget.neutrals.textBase,
        collapsedIconColor: widget.neutrals.textBase,
        title: Semantics(
          header: true,
          child: Text(
            HtCopy.comingUp,
            style: HtType.header.copyWith(color: widget.neutrals.textBase),
          ),
        ),
        onExpansionChanged: (open) {
          if (open) _load();
        },
        children: [_body()],
      ),
    );
  }
}

/// Before the train: what a hype train is, the level 1 emotes and the
/// time window on a 3 dp bar.
class _ApproachingDetails extends StatelessWidget {
  const _ApproachingDetails({
    required this.store,
    required this.approaching,
    required this.neutrals,
  });

  final HypeTrainStore store;
  final HypeTrainApproaching approaching;
  final HtNeutrals neutrals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = approaching.variant == HtVariant.goldenKappa
        ? HtPalette.of(HtStyle.goldenKappa, scheme)
        : HtPalette.approaching(scheme);
    final body = HtType.bodySmall.copyWith(
      color: neutrals.textBase,
      height: 1.3,
    );
    final variant = approaching.variant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              HtCopy.approachingQuestion(variant),
              style: HtType.header.copyWith(color: neutrals.textBase),
            ),
          ),
          const SizedBox(height: 6),
          Text(HtCopy.approachingExplanationFirst(variant), style: body),
          const SizedBox(height: HtDims.margin),
          Text(HtCopy.approachingExplanationSecond(variant), style: body),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              HtCopy.levelEmotes(1),
              style: HtType.header.copyWith(color: neutrals.textBase),
            ),
          ),
          const SizedBox(height: HtDims.margin),
          Center(
            child: _RewardRow(
              rewards: approaching.levelOneRewards,
              locked: true,
            ),
          ),
          const SizedBox(height: 16),
          Observer(
            builder: (context) => LinearProgressIndicator(
              key: const ValueKey('ht-approaching-details-bar'),
              minHeight: HtDims.bar,
              value: store.approachingCompleted ? 1 : store.approachingFraction,
              color: palette.fill,
              backgroundColor: palette.barTrack,
            ),
          ),
        ],
      ),
    );
  }
}
