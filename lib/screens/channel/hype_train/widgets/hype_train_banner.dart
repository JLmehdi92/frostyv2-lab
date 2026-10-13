import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
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

/// The running train: level, the active step (or title and level target),
/// percent, countdown and the level bar. Tap for details; swipe up or the
/// chevron to collapse it into a pill.
class HypeTrainBanner extends StatelessWidget {
  const HypeTrainBanner({super.key, required this.store, this.compact = false});

  final HypeTrainStore store;

  /// Landscape: one line, no subtitle.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          if (store.train == null) return const SizedBox.shrink();
          final palette = htPaletteOf(context, store);
          final textTheme = Theme.of(context).textTheme;
          final on = palette.onBackground;
          final flashing = store.step?.kind == HtStepKind.flash100;
          return RepaintBoundary(
            child: Semantics(
              container: true,
              button: true,
              label: store.semanticsSummary,
              hint: HtCopy.detailsHint,
              child: Material(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: store.toggleExpanded,
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -200) {
                        store.setCollapsed(true);
                      }
                    },
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        12,
                        compact ? 6 : 10,
                        4,
                        compact ? 6 : 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  palette.icon,
                                  color: palette.iconColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ExcludeSemantics(
                                child: HypeTrainLevelPill(
                                  level: store.shownLevel,
                                  background: on.withValues(alpha: 0.12),
                                  foreground: on,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: HypeTrainStepContent(
                                  store: store,
                                  palette: palette,
                                  compact: compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ExcludeSemantics(
                                child: AnimatedScale(
                                  scale: flashing ? 1.25 : 1,
                                  duration: HtTimings.extraShort,
                                  child: Text(
                                    '${store.shownPercent}%',
                                    key: const ValueKey('ht-percent'),
                                    style: textTheme.titleMedium?.copyWith(
                                      color: on,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              HypeTrainCountdown(
                                store: store,
                                style: textTheme.labelLarge?.copyWith(
                                  color: on.withValues(alpha: 0.8),
                                ),
                              ),
                              IconButton(
                                tooltip: HtCopy.collapse,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.expand_less_rounded,
                                  color: on,
                                ),
                                onPressed: () => store.setCollapsed(true),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 4 : 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ExcludeSemantics(
                              child: HypeTrainProgressBar(
                                percent: store.shownPercent,
                                palette: palette,
                              ),
                            ),
                          ),
                        ],
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
                            Text('LVL ${store.shownLevel}', style: style),
                            const SizedBox(width: 8),
                            Text('${store.shownPercent}%', style: style),
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
        return AnimatedSwitcher(
          duration: HtTimings.short,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey('ht-step-${keyFor(step)}'),
            child: _content(context, step),
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
    final target = store.levelTarget;
    final subtitle = store.isFinalLevel
        ? HtCopy.finalLevel
        : HtCopy.levelTarget(target.subs, target.bits);
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            palette.a11yName,
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
        final String text;
        if (data.containsKey('fromLevel')) {
          text = HtCopy.merged(data['fromLevel'], data['toLevel']);
        } else if (data.containsKey('treasure')) {
          text = HtCopy.treasureDiscount(data['treasure']);
        } else if (data.containsKey('community')) {
          text = HtCopy.communityAmount(data['community']);
        } else if (data['level'] case final int level) {
          text = HtCopy.levelRewards(level);
        } else if (store.phase == HtPhase.ending) {
          text = 'Rewards earned';
        } else {
          text = '${palette.a11yName}!';
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
        return _text(
          context,
          HtCopy.instruction(key, data),
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
        return _text(context, HtCopy.totals(totals.bits, totals.subs));
      case HtStepKind.summary:
        return _text(
          context,
          HtCopy.summary(
            data['level'] as int? ?? store.shownLevel,
            ath: data['ath'] == true,
          ),
          live: true,
        );
      case HtStepKind.sharedAvatars:
        final channels = data['channels'];
        final users = channels is List<HtUser> ? channels : const <HtUser>[];
        return Row(
          children: [
            for (final user in users.take(4))
              if (user.profileImageUrl case final url?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: ClipOval(
                    child: FrostyCachedNetworkImage(
                      imageUrl: url,
                      width: 22,
                      height: 22,
                    ),
                  ),
                ),
            Expanded(
              child: _text(
                context,
                'Shared Hype Train with ${users.length} channels',
                live: true,
              ),
            ),
          ],
        );
      case HtStepKind.sharedTop3:
        final shares = data['shares'];
        final list = shares is List<(HtSharedChannel, int)>
            ? shares
            : const <(HtSharedChannel, int)>[];
        return _text(
          context,
          list.map((s) => '${s.$1.user.displayName} ${s.$2}%').join(' · '),
        );
      case HtStepKind.coinUnlock || HtStepKind.rocketLaunch:
        final coin = step.kind == HtStepKind.coinUnlock;
        return Row(
          children: [
            Icon(
              coin ? Icons.savings_rounded : Icons.rocket_launch_rounded,
              color: palette.iconColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _text(
                context,
                coin ? 'Treasure unlocked!' : 'Community emotes unlocked!',
              ),
            ),
          ],
        );
      case HtStepKind.unlockIcon:
        return Icon(
          data['icon'] == 'rocket'
              ? Icons.rocket_launch_rounded
              : Icons.savings_rounded,
          color: palette.iconColor,
        );
      case HtStepKind.mythicPool || HtStepKind.mythicSelect:
        return ExcludeSemantics(
          child: HypeTrainMarquee(
            text: step.kind == HtStepKind.mythicPool
                ? 'Mythic emote pool'
                : 'Choosing the Mythic emote…',
            emotes: _emotes(data['emotes']),
            duration: step.duration,
            reduceMotion: true,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case HtStepKind.mythicReveal:
        final emote = data['emote'];
        return ExcludeSemantics(
          child: HypeTrainMarquee(
            text: 'Mythic emote unlocked!',
            emotes: emote is HtReward ? [emote] : const [],
            duration: step.duration,
            reduceMotion: true,
          ),
        );
      case HtStepKind.athReached:
        return _text(context, 'New all-time high!', live: true);
      case HtStepKind.athOtherChannel:
        final channel = data['channel'];
        return _text(
          context,
          '${channel is HtUser ? channel.displayName : 'A channel'} '
          'reached its record too!',
        );
      case HtStepKind.mergeAura:
        return _text(context, 'Hype Trains are merging!', live: true);
      case HtStepKind.channelLeftSummary:
        return _text(context, 'A channel left the shared train');
      case HtStepKind.continuesIn:
        final channel = data['channel'];
        return _text(
          context,
          'The train continues with '
          '${channel is HtUser ? channel.displayName : 'another channel'}',
          live: true,
        );
      case HtStepKind.rewardsStrip || HtStepKind.expiredStrip:
        return const SizedBox.shrink();
    }
  }
}
