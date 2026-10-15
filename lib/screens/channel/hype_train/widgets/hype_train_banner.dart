import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_math.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/coin_unlock.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/merge_aura.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/mythic_reveal.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/rainbow_sweep.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/rocket_launch.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/trophy_burst.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_countdown.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_marquee.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// The palette of the store's train in the current theme.
HtPalette htPaletteOf(BuildContext context, HypeTrainStore store) =>
    HtPalette.of(
      store.style,
      Theme.of(context).colorScheme,
      creatorColor: store.train?.config.creatorColor,
    );

/// The resting subtitle: the record, the final level, the treasure or
/// community unlock, or the default prompt.
String htSubtitle(HypeTrainStore store, HypeTrainExecution train) {
  final shared = train.shared != null;
  switch (store.style) {
    case HtStyle.athApproaching:
      return HtCopy.athApproaching;
    case HtStyle.athReached:
      return HtCopy.athReached(shared: shared);
    case _:
  }
  if (store.isFinalLevel) return HtCopy.finalLevel;
  if (train.treasure case final treasure?) {
    return train.level >= treasure.threshold
        ? HtCopy.treasureUnlockedSubtitle(treasure.discountPercentage)
        : HtCopy.treasureLocked(
            treasure.threshold,
            treasure.discountPercentage,
          );
  }
  if (train.community case final community?) {
    return train.level >= community.threshold
        ? HtCopy.communityUnlockedSubtitle(community.current)
        : HtCopy.communityLocked(community.threshold);
  }
  return HtCopy.subtitle;
}

/// The running train: level, the active step (or title and level target),
/// then the bar with percent and countdown. Tap for details; swipe up or
/// the chevron to collapse it into a pill.
class HypeTrainBanner extends StatelessWidget {
  const HypeTrainBanner({
    super.key,
    required this.store,
    this.compact = false,
    this.onTap,
  });

  final HypeTrainStore store;

  /// Instead of expanding the details below (landscape opens a sheet).
  final VoidCallback? onTap;

  /// Landscape: one line, no subtitle.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          final train = store.train;
          if (train == null) return const SizedBox.shrink();
          final palette = htPaletteOf(context, store);
          final textTheme = Theme.of(context).textTheme;
          final on = palette.onBackground;
          final flashing = store.step?.kind == HtStepKind.flash100;
          final treasure = treasureState(train);
          final levelPill = ExcludeSemantics(
            child: HypeTrainLevelPill(
              level: store.shownLevel,
              background: on.withValues(alpha: 0.12),
              foreground: on,
              animate: !store.reduceMotion,
            ),
          );
          final header = Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  palette.icon,
                  color: palette.iconColor,
                  size: compact ? 18 : 22,
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
              // A narrow landscape chat shrinks the pill before the text.
              if (compact)
                Flexible(
                  flex: 2,
                  child: FittedBox(fit: BoxFit.scaleDown, child: levelPill),
                )
              else
                levelPill,
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                flex: 3,
                child: HypeTrainStepContent(
                  store: store,
                  palette: palette,
                  compact: compact,
                ),
              ),
              // Too narrow in compact form: swipe up collapses there.
              if (!compact)
                IconButton(
                  tooltip: HtCopy.collapse,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.expand_less_rounded, color: on),
                  onPressed: () => store.setCollapsed(true),
                ),
            ],
          );
          final progress = Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: HypeTrainProgressBar(
                    percent: store.shownPercent,
                    palette: palette,
                    duration: store.reduceMotion
                        ? Duration.zero
                        : HtTimings.extraShort,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Natural size when there is room; scaled down when not.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: AnimatedScale(
                          scale: flashing ? 1.25 : 1,
                          duration: HtTimings.extraShort,
                          child: Text(
                            '${store.shownPercent}%',
                            key: const ValueKey('ht-percent'),
                            style: textTheme.titleSmall?.copyWith(
                              color: on,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      HypeTrainCountdown(
                        store: store,
                        style: textTheme.labelLarge?.copyWith(
                          color: on.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          return RepaintBoundary(
            child: _BannerSemantics(
              store: store,
              child: AnimatedContainer(
                // The style changes (record, treasure) cross-fade.
                duration: HtTimings.short,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      if (treasure != null)
                        PositionedDirectional(
                          end: 48,
                          top: 0,
                          bottom: 0,
                          child: ExcludeSemantics(
                            child: Icon(
                              treasure == HtUnlockState.unlocked ||
                                      treasure == HtUnlockState.unlockNow
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                              key: const ValueKey('ht-treasure-watermark'),
                              size: 56,
                              color: on.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: onTap ?? store.toggleExpanded,
                        child: GestureDetector(
                          onVerticalDragEnd: (details) {
                            if ((details.primaryVelocity ?? 0) < -200) {
                              store.setCollapsed(true);
                            }
                          },
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              12,
                              compact ? 4 : 6,
                              4,
                              compact ? 6 : 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                header,
                                SizedBox(height: compact ? 2 : 4),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: progress,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The banner's one screen-reader label. Its own observer: the label
/// changes with the countdown, the banner does not.
class _BannerSemantics extends StatelessWidget {
  const _BannerSemantics({required this.store, required this.child});

  final HypeTrainStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) => Semantics(
      container: true,
      button: true,
      label: store.semanticsSummary,
      hint: HtCopy.detailsHint,
      child: child,
    ),
  );
}

/// The collapsed train: a 28 px pill with the icon, level and percent.
class HypeTrainPill extends StatelessWidget {
  const HypeTrainPill({super.key, required this.store});

  final HypeTrainStore store;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Observer(
        builder: (context) {
          final palette = htPaletteOf(context, store);
          final on = palette.onBackground;
          final style = Theme.of(context).textTheme.labelMedium?.copyWith(
            color: on,
            fontWeight: FontWeight.w700,
          );
          return Semantics(
            container: true,
            button: true,
            label: store.semanticsSummary,
            hint: HtCopy.expand,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Material(
                key: const ValueKey('ht-pill'),
                color: palette.background,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => store.setCollapsed(false),
                  child: SizedBox(
                    height: 28,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              palette.icon,
                              size: 16,
                              color: palette.iconColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'LVL ${store.shownLevel} · '
                                '${store.shownPercent}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: on,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What the banner says right now: the active step, or at rest the title
/// and how much completes the level. Steps cross-fade.
class HypeTrainStepContent extends StatelessWidget {
  const HypeTrainStepContent({
    super.key,
    required this.store,
    required this.palette,
    this.compact = false,
  });

  final HypeTrainStore store;
  final HtPalette palette;
  final bool compact;

  /// Steps that only move the bar keep the resting content.
  static String keyFor(HtStep? step) => switch (step?.kind) {
    null ||
    HtStepKind.fillTo ||
    HtStepKind.progress ||
    HtStepKind.fadeIn => 'rest',
    final kind => kind.name,
  };

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final step = store.step;
        var content = _content(context, step);
        if (step != null && step.rainbow && !store.reduceMotion) {
          content = RainbowSweep(
            cycleDuration: step.duration ~/ HtTimings.rainbowCycles,
            child: content,
          );
        }
        return AnimatedSwitcher(
          duration: HtTimings.short,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey('ht-step-${keyFor(step)}'),
            child: content,
          ),
        );
      },
    );
  }

  Widget _text(
    BuildContext context,
    String text, {
    bool live = false,
    bool strong = true,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.onBackground,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
    );
    final widget = Text(
      text,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return live
        ? Semantics(container: true, liveRegion: true, child: widget)
        : ExcludeSemantics(child: widget);
  }

  Widget _rest(BuildContext context) {
    final train = store.train;
    final textTheme = Theme.of(context).textTheme;
    final on = palette.onBackground;
    final subtitle = train == null ? '' : htSubtitle(store, train);
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            train == null
                ? HtCopy.title
                : HtCopy.trainTitle(
                    train.variant,
                    shared: train.shared != null,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: on,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!compact && train != null)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: on.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  /// An effect beside its text; the effect shrinks when space is short.
  Widget _effectRow(BuildContext context, Widget effect, String text) => Row(
    children: [
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: effect,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(flex: 2, child: _text(context, text, live: true)),
    ],
  );

  List<HtReward> _emotes(Object? value) =>
      value is List<HtReward> ? value : const [];

  Widget _content(BuildContext context, HtStep? step) {
    if (step == null) return _rest(context);
    final data = step.data;
    switch (step.kind) {
      case HtStepKind.fillTo ||
          HtStepKind.progress ||
          HtStepKind.fadeIn ||
          HtStepKind.flash100:
        return _rest(context);
      case HtStepKind.fadeOut:
        return const SizedBox.shrink();
      case HtStepKind.marquee:
        final variant = store.train?.variant ?? HtVariant.regular;
        final shared = store.train?.shared != null;
        final String text;
        if (data.containsKey('fromLevel')) {
          text = HtCopy.merging;
        } else if (data.containsKey('treasure')) {
          text = HtCopy.treasureUnlockedMarquee;
        } else if (data.containsKey('community')) {
          text = HtCopy.communityUnlockedMarquee;
        } else if (data.containsKey('level')) {
          text = HtCopy.levelUp;
        } else if (store.phase == HtPhase.ending) {
          text = HtCopy.completed(variant, shared: shared);
        } else {
          text = HtCopy.started(variant, shared: shared);
        }
        return ExcludeSemantics(
          child: HypeTrainMarquee(
            text: text,
            emotes: _emotes(data['emotes']),
            duration: step.duration,
            reduceMotion: data['static'] == true || store.reduceMotion,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case HtStepKind.instruction:
        final key = data['text'] as String? ?? '';
        final train = store.train;
        return _text(
          context,
          HtCopy.instruction(
            key,
            data,
            variant: train?.variant ?? HtVariant.regular,
            discount: train?.treasure?.discountPercentage ?? 35,
            amount: key == 'mythicPool'
                ? train?.mythic?.pool.length ?? 0
                : train?.community?.current ?? 0,
          ),
          live: key == 'start' || key.endsWith('Unlocked'),
          strong: false,
        );
      case HtStepKind.levelComplete:
        return _text(
          context,
          HtCopy.levelComplete(data['level'] as int? ?? store.shownLevel),
          live: true,
        );
      case HtStepKind.largeContribution:
        final event = data['event'];
        if (event is! HtProgressionEvent) return _rest(context);
        return Row(
          children: [
            if (event.profileImageUrl case final url?)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ClipOval(
                  child: FrostyCachedNetworkImage(
                    imageUrl: url,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            Expanded(
              child: _text(
                context,
                HtCopy.contribution(
                  event.displayName,
                  event.action,
                  event.quantity,
                ),
                live: true,
              ),
            ),
          ],
        );
      case HtStepKind.totals:
        final totals = data['totals'];
        if (totals is! ({int bits, int subs})) return _rest(context);
        return _text(
          context,
          '${HtCopy.subsTotal(totals.subs)}   ${HtCopy.bitsTotal(totals.bits)}',
        );
      case HtStepKind.summary:
        return _text(
          context,
          HtCopy.summary(
            data['level'] as int? ?? store.shownLevel,
            ath: data['ath'] == true,
            variant: store.train?.variant ?? HtVariant.regular,
          ),
          live: true,
        );
      case HtStepKind.sharedAvatars:
        final channels = data['channels'];
        final users = channels is List<HtUser> ? channels : const <HtUser>[];
        return Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: HypeTrainAvatarStack(users: users),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _text(context, HtCopy.sharedNew, live: true)),
          ],
        );
      case HtStepKind.sharedTop3:
        final shares = data['shares'];
        final list = shares is List<(HtSharedChannel, int)>
            ? shares
            : const <(HtSharedChannel, int)>[];
        return ExcludeSemantics(
          child: Row(
            children: [
              for (final (channel, share) in list)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HtAvatar(user: channel.user, size: 20),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$share%',
                            maxLines: 1,
                            style: TextStyle(
                              color: palette.onBackground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      case HtStepKind.coinUnlock:
        return _effectRow(
          context,
          CoinUnlock(
            duration: step.duration,
            discount: store.train?.treasure?.discountPercentage,
            reduceMotion: store.reduceMotion,
          ),
          HtCopy.treasureUnlockedMarquee,
        );
      case HtStepKind.rocketLaunch:
        return _effectRow(
          context,
          SizedBox(
            width: 72,
            height: 40,
            child: RocketLaunch(
              duration: step.duration,
              reduceMotion: store.reduceMotion,
            ),
          ),
          HtCopy.communityUnlockedMarquee,
        );
      case HtStepKind.unlockIcon:
        return Icon(
          data['icon'] == 'rocket'
              ? Icons.rocket_launch_rounded
              : Icons.savings_rounded,
          color: palette.iconColor,
        );
      case HtStepKind.mythicPool:
        return MythicPool(
          duration: step.duration,
          pool: _emotes(data['emotes']),
          reduceMotion: store.reduceMotion,
        );
      case HtStepKind.mythicSelect:
        final selected = data['selected'];
        return MythicSelect(
          duration: step.duration,
          pool: _emotes(data['emotes']),
          selected: selected is HtReward ? selected : null,
          reduceMotion: store.reduceMotion,
        );
      case HtStepKind.mythicReveal:
        final emote = data['emote'];
        return _effectRow(
          context,
          MythicReveal(
            duration: step.duration,
            emote: emote is HtReward ? emote : null,
            reduceMotion: store.reduceMotion,
          ),
          HtCopy.completed(HtVariant.mythic),
        );
      case HtStepKind.athReached:
        return _effectRow(
          context,
          TrophyBurst(
            duration: step.duration,
            reduceMotion: store.reduceMotion,
          ),
          store.train?.shared != null
              ? HtCopy.sharedRecordReached
              : HtCopy.athReachedTitle,
        );
      case HtStepKind.athOtherChannel:
        final channel = data['channel'];
        return Row(
          children: [
            if (channel is HtUser)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: HtAvatar(user: channel),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: _text(
                context,
                HtCopy.otherChannelRecord(
                  channel is HtUser ? channel.displayName : 'A channel',
                ),
              ),
            ),
          ],
        );
      case HtStepKind.mergeAura:
        final previous = data['previous'];
        final joining = data['joining'];
        return Row(
          children: [
            Flexible(
              child: MergeAura(
                duration: step.duration,
                previous: previous is List<HtUser> ? previous : const [],
                joining: joining is List<HtUser> ? joining : const [],
                reduceMotion: store.reduceMotion,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _text(context, HtCopy.merging, live: true)),
          ],
        );
      case HtStepKind.channelLeftSummary:
        return _text(
          context,
          '${HtCopy.sharedLevelReached}\n'
          '${HtCopy.sharedLevel(store.shownLevel, store.shownPercent)}',
        );
      case HtStepKind.continuesIn:
        final channel = data['channel'];
        return Row(
          children: [
            if (channel is HtUser)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: HtAvatar(user: channel),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: _text(
                context,
                HtCopy.continuesIn(store.shownLevel),
                live: true,
              ),
            ),
          ],
        );
      case HtStepKind.rewardsStrip || HtStepKind.expiredStrip:
        return const SizedBox.shrink();
    }
  }
}
