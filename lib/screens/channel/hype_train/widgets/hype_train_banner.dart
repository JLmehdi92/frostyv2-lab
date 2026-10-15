import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// The palette of the store's train in the current theme.
HtPalette htPaletteOf(BuildContext context, HypeTrainStore store) {
  final train = store.train;
  final treasure = train == null ? null : treasureState(train);
  return HtPalette.of(
    store.style,
    Theme.of(context).colorScheme,
    creatorColor: train?.config.creatorColor,
    treasureUnlocked:
        treasure == HtUnlockState.unlocked ||
        treasure == HtUnlockState.unlockNow,
  );
}

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

/// The running train, laid out like Twitch's default banner: the level's
/// progress fills it from behind; the level pill and title, the subtitle
/// below them; the countdown over the percentage, then a chevron at the
/// end. 74 dp tall, growing with the text. Tap (or the chevron) for
/// details; swipe up to collapse it into a pill.
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

  /// Landscape: Twitch's compact layout (no title, its natural height).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: compact ? 1.3 : 2.0,
      child: Observer(
        builder: (context) {
          final train = store.train;
          if (train == null) return const SizedBox.shrink();
          final palette = htPaletteOf(context, store);
          final height = compact
              ? null
              : htBannerHeight(MediaQuery.textScalerOf(context));
          final resting = HypeTrainStepContent.isResting(store.step);
          final fade = store.reduceMotion ? Duration.zero : HtTimings.short;
          final content = LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      AnimatedOpacity(
                        opacity: resting ? 1 : 0,
                        duration: fade,
                        child: _restColumn(store, palette, compact),
                      ),
                      Positioned.fill(
                        child: HypeTrainStepContent(
                          store: store,
                          palette: palette,
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ),
                // Natural size when there is room; scaled down when not.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                    maxHeight: height ?? double.infinity,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: _Numbers(
                      store: store,
                      percent: store.shownPercent,
                      palette: palette,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: HtDims.marginHalf,
                    end: HtDims.margin,
                  ),
                  child: ExcludeSemantics(
                    child: AnimatedRotation(
                      turns: store.expanded ? 0.5 : 0,
                      duration: store.reduceMotion
                          ? Duration.zero
                          : HtTimings.extraShort,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: HtDims.icon,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          return RepaintBoundary(
            child: _BannerSemantics(
              store: store,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HtDims.radius),
                child: SizedBox(
                  key: const ValueKey('ht-banner'),
                  height: height,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      // The fill is the banner's background.
                      Positioned.fill(
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
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onTap ?? store.toggleExpanded,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) < -200) {
                                store.setCollapsed(true);
                              }
                            },
                            child: content,
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

/// The resting content at the start of the banner: the level pill and the
/// title over the subtitle (compact: the train's name as the subtitle).
Widget _restColumn(HypeTrainStore store, HtPalette palette, bool compact) {
  final train = store.train;
  if (train == null) return const SizedBox.shrink();
  if (store.style == HtStyle.athApproaching) {
    return _athApproaching(palette, compact);
  }
  final title = HtCopy.trainTitle(train.variant, shared: train.shared != null);
  final subtitle = Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      HtDims.margin,
      HtDims.marginHalf,
      HtDims.margin,
      HtDims.margin,
    ),
    child: Text(
      compact ? title : htSubtitle(store, train),
      key: const ValueKey('ht-subtitle'),
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: palette.textStyle(HtType.bodySmall),
    ),
  );
  // Read here, in the banner's observer, not in the layout builder.
  final pill = HypeTrainLevelPill(
    level: store.shownLevel,
    background: palette.pill,
    foreground: palette.pillText,
    trophy: palette.trophy,
    animate: !store.reduceMotion,
  );
  return ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final top = Padding(
          padding: const EdgeInsetsDirectional.only(
            start: HtDims.margin,
            top: HtDims.margin,
          ),
          child: Row(
            children: [
              // A narrow banner shrinks the pill before the title.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: max(
                    0,
                    constraints.maxWidth * (compact ? 1 : 0.6) - HtDims.margin,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: pill,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: HtDims.margin),
                Flexible(
                  child: Text(
                    title,
                    key: const ValueKey('ht-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.textStyle(HtType.titleDefault),
                  ),
                ),
              ],
            ],
          ),
        );
        return Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            top,
            if (compact) subtitle else Flexible(child: subtitle),
          ],
        );
      },
    ),
  );
}

/// A record in sight: a large trophy (cropped by the banner) and the
/// subtitle, no pill or title.
Widget _athApproaching(HtPalette palette, bool compact) {
  final trophy = Icon(
    Icons.emoji_events_rounded,
    key: const ValueKey('ht-ath-trophy'),
    size: compact ? HtDims.iconLarge : HtDims.trophy,
    color: htTrophyGold,
  );
  return ExcludeSemantics(
    child: Row(
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: HtDims.margin),
            child: trophy,
          )
        else
          SizedBox(
            width: HtDims.trophy,
            child: OverflowBox(
              maxWidth: HtDims.trophy,
              maxHeight: HtDims.trophy,
              child: trophy,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(HtDims.margin),
            child: Text(
              compact ? HtCopy.athApproachingCompact : HtCopy.athApproaching,
              key: const ValueKey('ht-subtitle'),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: palette.textStyle(HtType.bodySmall),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The countdown over the percentage, end-aligned. The countdown has its
/// own observer: it ticks without rebuilding the banner.
class _Numbers extends StatelessWidget {
  const _Numbers({
    required this.store,
    required this.percent,
    required this.palette,
  });

  final HypeTrainStore store;
  final int percent;
  final HtPalette palette;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      HypeTrainCountdown(
        store: store,
        style: palette.textStyle(HtType.bodySmall),
      ),
      ExcludeSemantics(
        child: Text(
          HtCopy.percent(percent),
          key: const ValueKey('ht-percent'),
          maxLines: 1,
          style: palette
              .textStyle(HtType.titleLarge)
              .copyWith(fontFeatures: HtType.tabular),
        ),
      ),
    ],
  );
}

/// The banner's one screen-reader label, and the collapse action that
/// replaces Twitch's minimise button. Its own observer: the label changes
/// with the countdown, the banner does not.
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
      customSemanticsActions: {
        const CustomSemanticsAction(label: HtCopy.collapse): () =>
            store.setCollapsed(true),
      },
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
          final on = palette.text;
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
                color: palette.track,
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
                            Icon(palette.icon, size: 16, color: palette.text),
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

/// What the banner announces right now: the active step over the resting
/// content, which fades out meanwhile. Empty at rest. Steps cross-fade.
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

  /// The banner's own content shows (the flash at 100% included).
  static bool isResting(HtStep? step) =>
      keyFor(step) == 'rest' || step?.kind == HtStepKind.flash100;

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
      color: palette.text,
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

  /// At rest the banner's own content shows; this layer is empty.
  Widget _rest(BuildContext context) => const SizedBox.shrink();

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
              color: palette.text,
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
                              color: palette.text,
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
          color: palette.text,
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
