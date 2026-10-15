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
import 'package:frosty/screens/channel/hype_train/widgets/effects/speedlines.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/trophy_burst.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_countdown.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_marquee.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_pill_shell.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

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
class HypeTrainBanner extends StatefulWidget {
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
  State<HypeTrainBanner> createState() => _HypeTrainBannerState();
}

class _HypeTrainBannerState extends State<HypeTrainBanner> {
  /// The level shown before the running merge, frozen while it plays:
  /// where the merge's pill counts up from.
  int? _levelBeforeMerge;

  @override
  void didUpdateWidget(HypeTrainBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) _levelBeforeMerge = null;
  }

  /// Avatar and icon rows fade the resting content out more slowly.
  static const _slowFades = {
    HtStepKind.sharedAvatars,
    HtStepKind.mergeAura,
    HtStepKind.athOtherChannel,
    HtStepKind.continuesIn,
    HtStepKind.channelLeftSummary,
  };

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final compact = widget.compact;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: compact ? 1.3 : 2.0,
      child: Observer(
        builder: (context) {
          final train = store.train;
          if (train == null) return const SizedBox.shrink();
          final level = store.shownLevel;
          final palette = htPaletteOf(context, store);
          final height = compact
              ? null
              : htBannerHeight(MediaQuery.textScalerOf(context));
          final step = store.step;
          if (step?.kind != HtStepKind.mergeAura) _levelBeforeMerge = level;
          final resting = HypeTrainStepContent.isResting(step);
          final fade = store.reduceMotion
              ? Duration.zero
              : _slowFades.contains(step?.kind)
              ? HtTimings.fade
              : HtTimings.short;
          final rest = LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: _restColumn(
                    store,
                    palette,
                    compact,
                    // An announced level change counts up on its own pill.
                    animatePill: resting && !store.reduceMotion,
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
                      // The fill is the banner's background; it stays
                      // through the announcements.
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
                      if (palette.speedlines)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.7,
                              child: CustomPaint(
                                key: const ValueKey('ht-speedlines'),
                                painter: HtSpeedlinesPainter(
                                  color: palette.fill,
                                  rtl:
                                      Directionality.of(context) ==
                                      TextDirection.rtl,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: widget.onTap ?? store.toggleExpanded,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) < -200) {
                                store.setCollapsed(true);
                              }
                            },
                            child: Stack(
                              fit: StackFit.passthrough,
                              children: [
                                AnimatedOpacity(
                                  opacity: resting ? 1 : 0,
                                  duration: fade,
                                  child: rest,
                                ),
                                // Announcements take the whole banner.
                                Positioned.fill(
                                  child: HypeTrainStepContent(
                                    store: store,
                                    palette: palette,
                                    compact: compact,
                                    previousLevel: _levelBeforeMerge == level
                                        ? null
                                        : _levelBeforeMerge,
                                  ),
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

/// The resting content at the start of the banner: the level pill and the
/// title over the subtitle (compact: the train's name as the subtitle).
Widget _restColumn(
  HypeTrainStore store,
  HtPalette palette,
  bool compact, {
  bool animatePill = true,
}) {
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
    animate: animatePill,
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
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (compact)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: HtDims.margin),
              child: trophy,
            )
          else
            // Up to half a narrow banner; the 100 dp trophy is cropped.
            SizedBox(
              width: min(HtDims.trophy, constraints.maxWidth / 2),
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: HtDims.trophy,
                  maxHeight: HtDims.trophy,
                  child: trophy,
                ),
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

/// The collapsed train: Twitch's 32 dp landscape pill with the icon,
/// level and percentage over the sweeping fill. Tap to expand it again.
class HypeTrainPill extends StatelessWidget {
  const HypeTrainPill({super.key, required this.store});

  final HypeTrainStore store;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          final palette = htPaletteOf(context, store);
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: HtPillShell(
              pillKey: const ValueKey('ht-pill'),
              fraction: store.shownPercent / 100,
              label: store.semanticsSummary,
              hint: HtCopy.expand,
              onTap: () => store.setCollapsed(false),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(palette.icon),
                  const SizedBox(width: HtDims.marginHalf),
                  Text(HtCopy.level(store.shownLevel)),
                  const SizedBox(width: HtDims.margin),
                  Text(HtCopy.percent(store.shownPercent)),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What the banner announces right now, across the whole banner: the
/// active step over the resting content, which fades out meanwhile (the
/// fill stays). Empty at rest. Steps cross-fade.
class HypeTrainStepContent extends StatelessWidget {
  const HypeTrainStepContent({
    super.key,
    required this.store,
    required this.palette,
    this.compact = false,
    this.previousLevel,
  });

  final HypeTrainStore store;
  final HtPalette palette;
  final bool compact;

  /// Where a merge's pill counts up from.
  final int? previousLevel;

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
        final rainbow = step != null && step.rainbow && !store.reduceMotion;
        var content = _content(context, step, rainbow: rainbow);
        if (step != null && rainbow) {
          content = RainbowSweep(
            cycleDuration: step.duration ~/ HtTimings.rainbowCycles,
            child: content,
          );
        }
        return AnimatedSwitcher(
          duration: store.reduceMotion ? Duration.zero : HtTimings.short,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: KeyedSubtree(
            key: ValueKey('ht-step-${keyFor(step)}'),
            child: content,
          ),
        );
      },
    );
  }

  /// Twitch's TitleLarge announcements: 24 sp, 18 sp compact.
  TextStyle get _large => palette.textStyle(
    HtType.titleLarge.copyWith(fontSize: compact ? 18 : 24),
  );

  /// Twitch's small announcements: 13 sp, 12 sp compact.
  TextStyle get _small => palette.textStyle(
    HtType.titleExtraSmall.copyWith(fontSize: compact ? 12 : 13, height: 1.2),
  );

  Widget _live(Widget child, {bool live = true}) => live
      ? Semantics(container: true, liveRegion: true, child: child)
      : ExcludeSemantics(child: child);

  /// One line in the middle of the banner ("Level n Complete!").
  Widget _centred(String text) => _live(
    Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: _large),
        ),
      ),
    ),
  );

  /// One or two short lines, optionally after an icon in the fill colour.
  Widget _smallAnnouncement(
    String primary, {
    String? secondary,
    IconData? icon,
    bool live = false,
  }) {
    final lines = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: icon == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: secondary == null && !compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: icon == null ? TextAlign.center : TextAlign.start,
          style: _small,
        ),
        if (secondary != null)
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: icon == null ? TextAlign.center : TextAlign.start,
            style: _small,
          ),
      ],
    );
    return _live(
      Padding(
        key: const ValueKey('ht-small-announcement'),
        padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: HtDims.icon, color: palette.checkPill),
                const SizedBox(width: HtDims.margin),
              ],
              Flexible(child: lines),
            ],
          ),
        ),
      ),
      live: live,
    );
  }

  /// An effect beside its text, centred; the effect shrinks when space is
  /// short.
  Widget _effectRow(Widget effect, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: effect),
        ),
        const SizedBox(width: HtDims.margin),
        Flexible(
          flex: 2,
          child: _live(
            Text(
              text,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: palette.textStyle(HtType.titleDefault),
            ),
          ),
        ),
      ],
    ),
  );

  List<HtReward> _emotes(Object? value) =>
      value is List<HtReward> ? value : const [];

  /// [rainbow]: Twitch's rainbow fills the banner and text turns black.
  Widget _content(BuildContext context, HtStep? step, {bool rainbow = false}) {
    if (step == null) return const SizedBox.shrink();
    final data = step.data;
    final train = store.train;
    switch (step.kind) {
      case HtStepKind.fillTo ||
          HtStepKind.progress ||
          HtStepKind.fadeIn ||
          HtStepKind.flash100 ||
          HtStepKind.fadeOut ||
          HtStepKind.rewardsStrip ||
          HtStepKind.expiredStrip:
        // The banner's own content, or nothing while it fades.
        return const SizedBox.shrink();
      case HtStepKind.marquee:
        final variant = train?.variant ?? HtVariant.regular;
        final shared = train?.shared != null;
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
            emoteSize: compact ? 20 : HtDims.icon,
            style: rainbow
                ? _large.copyWith(color: Colors.black, shadows: const [])
                : _large,
          ),
        );
      case HtStepKind.instruction:
        final key = data['text'] as String? ?? '';
        return _smallAnnouncement(
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
        );
      case HtStepKind.levelComplete:
        return _centred(
          HtCopy.levelComplete(data['level'] as int? ?? store.shownLevel),
        );
      case HtStepKind.largeContribution:
        final event = data['event'];
        if (event is! HtProgressionEvent) return const SizedBox.shrink();
        final action = event.action;
        return _smallAnnouncement(
          HtCopy.contribution(event.displayName, action, event.quantity),
          icon: action.isCheer
              ? Icons.diamond_rounded
              : action.isGift
              ? Icons.card_giftcard_rounded
              : Icons.star_rounded,
          live: true,
        );
      case HtStepKind.totals:
        final totals = data['totals'];
        if (totals is! ({int bits, int subs})) return const SizedBox.shrink();
        return _Totals(subs: totals.subs, bits: totals.bits, style: _small);
      case HtStepKind.summary:
        final lines = HtCopy.summary(
          data['level'] as int? ?? store.shownLevel,
          ath: data['ath'] == true,
          variant: train?.variant ?? HtVariant.regular,
        ).split('\n');
        return _smallAnnouncement(
          lines.first,
          secondary: lines.length > 1 ? lines.last : null,
          live: true,
        );
      case HtStepKind.sharedAvatars:
        final channels = data['channels'];
        final users = channels is List<HtUser> ? channels : const <HtUser>[];
        return _live(
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HypeTrainAvatarStack(users: users, plusColor: palette.text),
                  const SizedBox(width: HtDims.margin),
                  Text(
                    HtCopy.sharedNew,
                    maxLines: 1,
                    style: palette.textStyle(HtType.titleDefault),
                  ),
                ],
              ),
            ),
          ),
        );
      case HtStepKind.sharedTop3:
        final shares = data['shares'];
        return ExcludeSemantics(
          child: HypeTrainContributions(
            shares: shares is List<(HtSharedChannel, int)> ? shares : const [],
            color: palette.text,
            compact: compact,
          ),
        );
      case HtStepKind.coinUnlock:
        // The coin as tall as the banner, the line beside it.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoinUnlock(
                duration: step.duration,
                discount: train?.treasure?.discountPercentage,
                reduceMotion: store.reduceMotion,
              ),
              const SizedBox(width: HtDims.margin),
              Expanded(
                child: Center(
                  child: _live(
                    Text(
                      HtCopy.treasureUnlockedMarquee,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: palette.textStyle(HtType.titleDefault),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case HtStepKind.rocketLaunch:
        // The rocket climbs across the whole banner behind the line.
        return Stack(
          fit: StackFit.expand,
          children: [
            RocketLaunch(
              duration: step.duration,
              reduceMotion: store.reduceMotion,
              color: palette.text,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
                child: _live(
                  Text(
                    HtCopy.communityUnlockedMarquee,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: palette.textStyle(HtType.titleDefault),
                  ),
                ),
              ),
            ),
          ],
        );
      case HtStepKind.unlockIcon:
        return Center(
          child: Icon(
            data['icon'] == 'rocket'
                ? Icons.rocket_launch_rounded
                : Icons.savings_rounded,
            size: HtDims.iconLarge,
            color: palette.text,
          ),
        );
      case HtStepKind.mythicPool:
        return Center(
          child: MythicPool(
            duration: step.duration,
            pool: _emotes(data['emotes']),
            reduceMotion: store.reduceMotion,
          ),
        );
      case HtStepKind.mythicSelect:
        final selected = data['selected'];
        return Center(
          child: MythicSelect(
            duration: step.duration,
            pool: _emotes(data['emotes']),
            selected: selected is HtReward ? selected : null,
            reduceMotion: store.reduceMotion,
          ),
        );
      case HtStepKind.mythicReveal:
        final emote = data['emote'];
        return _effectRow(
          MythicReveal(
            duration: step.duration,
            emote: emote is HtReward ? emote : null,
            reduceMotion: store.reduceMotion,
          ),
          HtCopy.completed(HtVariant.mythic),
        );
      case HtStepKind.athReached:
        return _effectRow(
          TrophyBurst(
            duration: step.duration,
            reduceMotion: store.reduceMotion,
          ),
          train?.shared != null
              ? HtCopy.sharedRecordReached
              : HtCopy.athReachedTitle,
        );
      case HtStepKind.athOtherChannel:
        final channel = data['channel'];
        return _OtherChannelRecord(
          channel: channel is HtUser ? channel : null,
          style: palette.textStyle(HtType.bodySemibold),
          compact: compact,
        );
      case HtStepKind.mergeAura:
        final previous = data['previous'];
        final joining = data['joining'];
        return ExcludeSemantics(
          child: MergeAura(
            duration: step.duration,
            previous: previous is List<HtUser> ? previous : const [],
            joining: joining is List<HtUser> ? joining : const [],
            fromLevel: previousLevel,
            level: store.shownLevel,
            pill: palette.pill,
            pillText: palette.pillText,
            reduceMotion: store.reduceMotion,
          ),
        );
      case HtStepKind.channelLeftSummary:
        return _LeavingCollaborator(
          channels: [
            for (final channel in train?.shared?.channels ?? const [])
              channel.user,
          ],
          level: store.shownLevel,
          percent: store.shownPercent,
          palette: palette,
        );
      case HtStepKind.continuesIn:
        final channel = data['channel'];
        return _live(
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    HtCopy.continuesIn(store.shownLevel),
                    maxLines: 1,
                    style: palette.textStyle(HtType.titleDefault),
                  ),
                  if (channel is HtUser) ...[
                    const SizedBox(width: HtDims.marginHalf),
                    HtAvatar(user: channel, size: HtDims.avatar),
                  ],
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// The totals at the end: "[★] n Subs" over "[◆] n Bits".
class _Totals extends StatelessWidget {
  const _Totals({required this.subs, required this.bits, required this.style});

  final int subs;
  final int bits;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: (style.fontSize ?? 13) + 3, color: style.color),
        const SizedBox(width: HtDims.marginHalf),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: '${HtCopy.subsTotal(subs)}, ${HtCopy.bitsTotal(bits)}',
      excludeSemantics: true,
      child: Center(
        child: Column(
          key: const ValueKey('ht-small-announcement'),
          mainAxisSize: MainAxisSize.min,
          children: [
            line(Icons.star_rounded, HtCopy.subsTotal(subs)),
            line(Icons.diamond_rounded, HtCopy.bitsTotal(bits)),
          ],
        ),
      ),
    );
  }
}

/// The shared train's top channels: avatar and share, the first larger,
/// 30 dp apart.
class HypeTrainContributions extends StatelessWidget {
  const HypeTrainContributions({
    super.key,
    required this.shares,
    required this.color,
    this.compact = false,
  });

  final List<(HtSharedChannel, int)> shares;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (channel, share)) in shares.indexed) ...[
              if (i > 0) const SizedBox(width: 30),
              HtAvatar(user: channel.user, size: HtDims.avatar),
              const SizedBox(width: HtDims.marginHalf),
              Text(
                HtCopy.percent(share),
                maxLines: 1,
                style: i == 0
                    ? HtType.titleLarge.copyWith(
                        color: color,
                        fontSize: compact ? 18 : 24,
                      )
                    : HtType.bodySmall.copyWith(
                        color: color,
                        fontSize: compact ? 14 : 18,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Another channel of the shared train broke its record: its avatar with
/// a trophy badge, the line, and two tilted trophies at the end.
class _OtherChannelRecord extends StatelessWidget {
  const _OtherChannelRecord({
    required this.channel,
    required this.style,
    required this.compact,
  });

  final HtUser? channel;
  final TextStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final channel = this.channel;
    Widget trophy(double dx) => PositionedDirectional(
      end: dx,
      top: 0,
      bottom: 0,
      child: OverflowBox(
        maxWidth: HtDims.trophyOther,
        maxHeight: HtDims.trophyOther,
        child: Transform.rotate(
          angle: 300 * pi / 180,
          child: const Icon(
            Icons.emoji_events_rounded,
            size: HtDims.trophyOther,
            color: htTrophyGold,
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: HtCopy.otherChannelRecord(channel?.displayName ?? ''),
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!compact) ...[trophy(-8), trophy(40)],
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: HtDims.margin,
            ),
            child: Row(
              children: [
                if (channel != null)
                  SizedBox.square(
                    dimension: HtDims.icon * 2,
                    child: Stack(
                      children: [
                        HtAvatar(user: channel, size: HtDims.avatar),
                        PositionedDirectional(
                          start: HtDims.icon,
                          top: HtDims.icon,
                          child: Container(
                            key: const ValueKey('ht-trophy-badge'),
                            width: HtDims.icon,
                            height: HtDims.icon,
                            decoration: const BoxDecoration(
                              color: HtNeutrals.pill,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: HtDims.margin),
                Flexible(
                  child: Text(
                    HtCopy.otherChannelRecord(channel?.displayName ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                if (!compact) const SizedBox(width: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A channel left the shared train: "Shared Train level reached" over the
/// channels, and the level and percentage it reached.
class _LeavingCollaborator extends StatelessWidget {
  const _LeavingCollaborator({
    required this.channels,
    required this.level,
    required this.percent,
    required this.palette,
  });

  final List<HtUser> channels;
  final int level;
  final int percent;
  final HtPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '${HtCopy.sharedLevelReached}. '
          '${HtCopy.sharedLevel(level, percent)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: HtDims.margin,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HtCopy.sharedLevelReached,
                      style: palette.textStyle(HtType.titleExtraSmall),
                    ),
                    if (channels.isNotEmpty) ...[
                      const SizedBox(height: HtDims.marginHalf),
                      HypeTrainAvatarStack(
                        users: channels,
                        plusColor: palette.text,
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: HtDims.margin),
                Text(
                  HtCopy.sharedLevel(level, percent),
                  style: palette.textStyle(HtType.titleDefault),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
