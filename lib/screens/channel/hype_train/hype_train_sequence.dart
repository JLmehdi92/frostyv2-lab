import 'package:flutter/foundation.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_math.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_reducer.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';

/// What the banner shows during one step of a sequence.
enum HtStepKind {
  fadeIn,
  fadeOut,

  /// The resting state: level, bar and timer.
  progress,
  fillTo,
  flash100,
  marquee,
  instruction,
  levelComplete,
  sharedAvatars,
  sharedTop3,
  largeContribution,
  coinUnlock,
  rocketLaunch,

  /// The coin or rocket as a still icon (reduced motion).
  unlockIcon,
  mythicPool,
  mythicSelect,
  mythicReveal,
  athReached,
  athOtherChannel,
  mergeAura,
  channelLeftSummary,
  continuesIn,
  totals,
  summary,
  rewardsStrip,
  expiredStrip,
}

@immutable
class HtStep {
  const HtStep(
    this.kind,
    this.duration, {
    this.data = const {},
    this.rainbow = false,
  });

  final HtStepKind kind;
  final Duration duration;

  /// What the step shows (`percent`, `level`, `emotes`, `text`, …).
  final Map<String, Object?> data;

  /// The shared / record rainbow sweep over the step.
  final bool rainbow;

  bool get isStrip =>
      kind == HtStepKind.rewardsStrip || kind == HtStepKind.expiredStrip;

  HtStep copyWith({
    HtStepKind? kind,
    Duration? duration,
    Map<String, Object?>? data,
    bool? rainbow,
  }) => HtStep(
    kind ?? this.kind,
    duration ?? this.duration,
    data: data ?? this.data,
    rainbow: rainbow ?? this.rainbow,
  );
}

Duration total(Iterable<HtStep> steps) =>
    steps.fold(Duration.zero, (sum, step) => sum + step.duration);

@immutable
class HtPlanInput {
  const HtPlanInput({
    required this.event,
    required this.after,
    required this.result,
    this.before,
    this.channelId,
    this.compact = false,
    this.reduceMotion = false,
    this.presenterVisible = true,
  });

  final HypeTrainEvent event;

  /// The train before the event; null when it starts the train.
  final HypeTrainExecution? before;
  final HypeTrainExecution after;
  final HtApplyResult result;

  /// This channel, left out of the other channels' record slides.
  final String? channelId;

  /// The collapsed pill or landscape: only the level pill and the strips.
  final bool compact;
  final bool reduceMotion;

  /// Off screen, steps take no time and strips are skipped.
  final bool presenterVisible;
}

/// The steps that animate one applied event (notes §3.2).
List<HtStep> planSequence(HtPlanInput input) {
  var steps = [..._eventSteps(input), ..._athSteps(input)];
  if (input.reduceMotion) steps = [for (final s in steps) _still(s)];
  if (input.compact) steps = _compact(input, steps);
  if (!input.presenterVisible) {
    steps = [
      for (final s in steps)
        if (!s.isStrip) s.copyWith(duration: Duration.zero),
    ];
  }
  return steps;
}

const _zero = Duration.zero;

HtStep _fillTo(int value) =>
    HtStep(HtStepKind.fillTo, HtTimings.extraShort, data: {'percent': value});

HtStep _instruction(String text, [Map<String, Object?> extra = const {}]) =>
    HtStep(
      HtStepKind.instruction,
      HtTimings.textShort,
      data: {'text': text, ...extra},
    );

/// One step for the whole rainbow (three sweeps of [cycle]).
HtStep _rainbowMarquee(Duration cycle, Map<String, Object?> data) => HtStep(
  HtStepKind.marquee,
  cycle * HtTimings.rainbowCycles,
  data: data,
  rainbow: true,
);

HtStep _sharedTop3(HypeTrainExecution train) => HtStep(
  HtStepKind.sharedTop3,
  HtTimings.fade + HtTimings.scrollDefault,
  data: {'shares': topShares(train.shared!)},
);

List<HtStep> _eventSteps(HtPlanInput input) {
  final after = input.after;
  final result = input.result;
  switch (input.event) {
    case HtStartEvent():
      if (after.shared != null) {
        return [
          const HtStep(HtStepKind.fadeIn, HtTimings.short),
          HtStep(
            HtStepKind.sharedAvatars,
            HtTimings.textLong,
            data: {
              'channels': [for (final c in after.shared!.channels) c.user],
            },
          ),
          _instruction('start'),
        ];
      }
      return [
        const HtStep(HtStepKind.fadeIn, HtTimings.short),
        HtStep(
          HtStepKind.marquee,
          HtTimings.scrollLong,
          data: {
            'emotes': after.variant == HtVariant.mythic
                ? after.mythic?.pool ?? const <HtReward>[]
                : [
                    ?after.config.calloutEmote,
                    ?after.config.calloutEmote,
                    ?after.config.calloutEmote,
                  ],
          },
        ),
        _instruction('start'),
        if (after.treasure case final treasure?)
          _instruction('treasureReachLevel', {'level': treasure.threshold})
        else if (after.community case final community?)
          _instruction('communityReachLevel', {'level': community.threshold}),
        const HtStep(HtStepKind.progress, _zero),
      ];
    case HtProgressionEvent(:final isLarge) && final event:
      return [
        if (isLarge) ...[
          const HtStep(HtStepKind.fadeOut, HtTimings.short),
          HtStep(
            HtStepKind.largeContribution,
            HtTimings.textLong,
            data: {'event': event},
          ),
          const HtStep(HtStepKind.fadeIn, HtTimings.short),
        ],
        _fillTo(percent(after.progress)),
      ];
    case HtLevelUpEvent():
      return _levelUp(input);
    case HtMergeEvent():
      return [
        HtStep(
          HtStepKind.mergeAura,
          HtTimings.fade,
          data: {
            'previous': result.previousChannels,
            'joining': result.joiningChannels,
          },
        ),
        HtStep(
          HtStepKind.marquee,
          HtTimings.scrollLong,
          data: {
            'fromLevel':
                result.mergedFrom?.level.value ??
                result.levelChangedFrom ??
                input.before?.level,
            'toLevel': after.level,
          },
        ),
        const HtStep(HtStepKind.progress, _zero),
      ];
    case HtChannelLeftEvent(:final continuesIn):
      final next = result.continuesIn ?? continuesIn;
      return [
        const HtStep(HtStepKind.channelLeftSummary, HtTimings.textShort),
        if (next != null)
          HtStep(
            HtStepKind.continuesIn,
            HtTimings.scrollLong,
            data: {'channel': next},
          )
        else
          const HtStep(
            HtStepKind.instruction,
            HtTimings.scrollLong,
            data: {'text': 'seeYouNextTime'},
          ),
      ];
    case HtEndEvent(:final reason):
      return reason == HtEndReason.completed
          ? _completed(input)
          : const [HtStep(HtStepKind.expiredStrip, HtTimings.endStrip)];
    case HtConductorEvent() ||
        HtApproachingEvent() ||
        HtIgnoredEvent() ||
        HtUnknownEvent():
      return const [];
  }
}

List<HtStep> _levelUp(HtPlanInput input) {
  final after = input.after;
  final result = input.result;
  final from = result.levelChangedFrom;
  if (after.level < 2) return const [];
  if (from == null) return [_fillTo(percent(after.progress))];
  final shared = after.shared != null;
  final completed = {
    'emotes': input.before?.progress.level.rewards ?? const <HtReward>[],
    'level': from,
  };
  final treasure = treasureState(after);
  return [
    _fillTo(100),
    const HtStep(HtStepKind.flash100, HtTimings.short),
    if (shared)
      _rainbowMarquee(HtTimings.rainbowLevelUp, completed)
    else
      HtStep(HtStepKind.marquee, HtTimings.scrollDefault, data: completed),
    HtStep(HtStepKind.levelComplete, HtTimings.short, data: {'level': from}),
    if (shared) _sharedTop3(after),
    if (result.treasureUnlockedNow) ...[
      const HtStep(HtStepKind.coinUnlock, HtTimings.unlockEffect),
      HtStep(
        HtStepKind.marquee,
        HtTimings.scrollLong,
        data: {'treasure': after.treasure!.discountPercentage},
      ),
      _instruction('treasureUnlocked'),
    ] else if (treasure == HtUnlockState.oneLevelAway)
      _instruction('treasureOneAway', {'level': after.treasure!.threshold}),
    if (result.communityUnlockedNow) ...[
      const HtStep(HtStepKind.rocketLaunch, HtTimings.unlockEffect),
      HtStep(
        HtStepKind.marquee,
        HtTimings.scrollLong,
        data: {'community': after.community!.current},
      ),
      _instruction('communityUnlocked'),
    ],
    if (after.variant == HtVariant.mythic) ...[
      HtStep(
        HtStepKind.mythicPool,
        HtTimings.scrollDefault,
        data: {'emotes': after.mythic?.pool ?? const <HtReward>[]},
      ),
      _instruction('mythicPool'),
    ],
    _fillTo(percent(after.progress)),
  ];
}

bool _reached(HtAthState? state) =>
    state == HtAthState.reached || state == HtAthState.justReached;

List<HtStep> _completed(HtPlanInput input) {
  final after = input.after;
  final result = input.result;
  final ath = _reached(after.progress.athState);
  final shared = after.shared != null;
  final rewards = {'emotes': result.endRewards};
  return [
    if (ath)
      _rainbowMarquee(HtTimings.rainbowAthComplete, rewards)
    else if (shared)
      _rainbowMarquee(HtTimings.rainbowComplete, rewards)
    else
      HtStep(HtStepKind.marquee, HtTimings.scrollLong, data: rewards),
    if (after.variant == HtVariant.mythic) ...[
      HtStep(
        HtStepKind.mythicSelect,
        HtTimings.textShort,
        data: {
          'emotes': after.mythic?.pool ?? const <HtReward>[],
          'selected': after.mythic?.selectedEmote,
        },
      ),
      HtStep(
        HtStepKind.mythicReveal,
        HtTimings.textShort,
        data: {'emote': after.mythic?.selectedEmote},
      ),
    ],
    if (after.community != null) _instruction('communityRewards'),
    // Our own end (Twitch sent none) has no totals to show.
    if (!(input.event as HtEndEvent).synthesized)
      HtStep(
        HtStepKind.totals,
        HtTimings.textLong,
        data: {'totals': endTotals(result.endTotals)},
      ),
    if (shared) _sharedTop3(after),
    HtStep(
      HtStepKind.summary,
      HtTimings.textShort,
      data: {'ath': ath, 'level': after.level},
    ),
    HtStep(
      HtStepKind.rewardsStrip,
      HtTimings.endStrip,
      data: {'emotes': result.endRewards},
    ),
  ];
}

List<HtStep> _athSteps(HtPlanInput input) {
  switch (input.result.athTransition) {
    case HtAthTransition.none:
      return const [];
    case HtAthTransition.approaching:
      return const [
        HtStep(HtStepKind.fadeIn, HtTimings.short, data: {'style': 'ath'}),
      ];
    case HtAthTransition.reached:
      final before = {
        for (final c in input.before?.shared?.channels ?? const [])
          c.user.id: c.progress?.athState,
      };
      return [
        const HtStep(HtStepKind.athReached, HtTimings.textLong),
        for (final channel in input.after.shared?.channels ?? const [])
          if (channel.user.id != input.channelId &&
              _reached(channel.progress?.athState) &&
              !_reached(before[channel.user.id]))
            HtStep(
              HtStepKind.athOtherChannel,
              HtTimings.textLong,
              data: {'channel': channel.user},
            ),
      ];
  }
}

HtStep _still(HtStep step) => switch (step.kind) {
  HtStepKind.marquee => step.copyWith(
    data: {...step.data, 'static': true},
    rainbow: false,
  ),
  HtStepKind.coinUnlock => const HtStep(
    HtStepKind.unlockIcon,
    HtTimings.unlockIcon,
    data: {'icon': 'coin'},
  ),
  HtStepKind.rocketLaunch => const HtStep(
    HtStepKind.unlockIcon,
    HtTimings.unlockIcon,
    data: {'icon': 'rocket'},
  ),
  _ => step.rainbow ? step.copyWith(rainbow: false) : step,
};

List<HtStep> _compact(HtPlanInput input, List<HtStep> steps) {
  if (input.event is HtLevelUpEvent) {
    final from = input.result.levelChangedFrom;
    if (from == null || input.after.level < 2) return const [];
    return [
      HtStep(
        HtStepKind.levelComplete,
        HtTimings.scrollDefault,
        data: {'level': from},
      ),
    ];
  }
  return [
    for (final s in steps)
      if (s.isStrip) s,
  ];
}
