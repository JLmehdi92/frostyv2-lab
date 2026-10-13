import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_reducer.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';

import 'hype_train_test_data.dart';

const _k = HtStepKind.values;

List<HtStep> plan(
  HypeTrainEvent event, {
  HypeTrainExecution? before,
  required HypeTrainExecution after,
  HtApplyResult? result,
  bool compact = false,
  bool reduceMotion = false,
  bool presenterVisible = true,
}) => planSequence(
  HtPlanInput(
    event: event,
    before: before,
    after: after,
    result: result ?? HtApplyResult(after),
    compact: compact,
    reduceMotion: reduceMotion,
    presenterVisible: presenterVisible,
  ),
);

List<HtStepKind> kinds(List<HtStep> steps) => [for (final s in steps) s.kind];

List<int> ms(List<HtStep> steps) => [
  for (final s in steps) s.duration.inMilliseconds,
];

HtProgressionEvent progressionEvent({bool isLarge = false}) =>
    HtProgressionEvent(
      sequenceId: 10,
      action: const HtAction('CHEER'),
      source: HtSource.bits,
      quantity: 100,
      isLarge: isLarge,
      progress: progress(value: 50, total: 10),
    );

HtLevelUpEvent levelUpEvent(int level) => HtLevelUpEvent(
  timeToExpire: DateTime.utc(2026, 10, 13, 16),
  progress: progress(level: level, value: 20),
);

HtShared sharedOf(Map<String, HtAthState> states) => HtShared(
  id: 's',
  channels: [
    for (final MapEntry(:key, :value) in states.entries)
      HtSharedChannel(
        user: user(key),
        progress: progress(total: 100, athState: value),
      ),
  ],
);

const _treasure = HtTreasure(
  discountPercentage: 50,
  threshold: 3,
  status: HtUnlockStatus.none,
);

void main() {
  test('timings match the reverse-engineered constants', () {
    expect(HtTimings.textLong.inMilliseconds, 6000);
    expect(HtTimings.scrollLong.inMilliseconds, 3000);
    expect(HtTimings.scrollDefault.inMilliseconds, 2500);
    expect(HtTimings.textShort.inMilliseconds, 2000);
    expect(HtTimings.fade.inMilliseconds, 1000);
    expect(HtTimings.short.inMilliseconds, 500);
    expect(HtTimings.extraShort.inMilliseconds, 200);
    expect(HtTimings.endStrip.inMilliseconds, 20000);
    expect(HtTimings.rainbowCycles, 3);
    expect(HtTimings.expiryGrace, const Duration(seconds: 10));
  });

  group('start', () {
    test('a regular start', () {
      final after = train();
      final steps = plan(HtStartEvent(after), after: after);

      expect(kinds(steps), [
        HtStepKind.fadeIn,
        HtStepKind.marquee,
        HtStepKind.instruction,
        HtStepKind.progress,
      ]);
      expect(ms(steps), [500, 3000, 2000, 0]);
      expect(total(steps), const Duration(milliseconds: 5500));
    });

    test('a treasure start announces the level to reach', () {
      final after = train(treasure: _treasure);
      final steps = plan(HtStartEvent(after), after: after);

      expect(kinds(steps), [
        HtStepKind.fadeIn,
        HtStepKind.marquee,
        HtStepKind.instruction,
        HtStepKind.instruction,
        HtStepKind.progress,
      ]);
      expect(steps[3].data['text'], 'treasureReachLevel');
      expect(steps[3].data['level'], 3);
    });

    test('a shared start shows the channels', () {
      final after = train(shared: sharedOf({'a': HtAthState.none}));
      final steps = plan(HtStartEvent(after), after: after);

      expect(kinds(steps), [
        HtStepKind.fadeIn,
        HtStepKind.sharedAvatars,
        HtStepKind.instruction,
      ]);
      expect(ms(steps), [500, 6000, 2000]);
    });
  });

  group('progression', () {
    test('a small one fills the bar', () {
      final after = train(value: 50);
      final steps = plan(progressionEvent(), after: after);

      expect(kinds(steps), [HtStepKind.fillTo]);
      expect(ms(steps), [200]);
      expect(steps.single.data['percent'], 50);
    });

    test('a large one is announced (7200 ms)', () {
      final after = train(value: 50);
      final steps = plan(progressionEvent(isLarge: true), after: after);

      expect(kinds(steps), [
        HtStepKind.fadeOut,
        HtStepKind.largeContribution,
        HtStepKind.fadeIn,
        HtStepKind.fillTo,
      ]);
      expect(total(steps), const Duration(milliseconds: 7200));
    });
  });

  group('level-up', () {
    List<HtStep> levelTo(
      int level, {
      HtTreasure? treasure,
      HtCommunity? community,
      HtShared? shared,
      HtVariant? variant,
      bool treasureNow = false,
      bool communityNow = false,
    }) {
      final before = train(
        level: level - 1,
        treasure: treasure,
        community: community,
        shared: shared,
        variant: variant,
      );
      final after = train(
        level: level,
        value: 20,
        treasure: treasure,
        community: community,
        shared: shared,
        variant: variant,
      );
      return plan(
        levelUpEvent(level),
        before: before,
        after: after,
        result: HtApplyResult(
          after,
          levelChangedFrom: level - 1,
          treasureUnlockedNow: treasureNow,
          communityUnlockedNow: communityNow,
        ),
      );
    }

    test('to level 2 plays the full sequence', () {
      final steps = levelTo(2);

      expect(kinds(steps), [
        HtStepKind.fillTo,
        HtStepKind.flash100,
        HtStepKind.marquee,
        HtStepKind.levelComplete,
        HtStepKind.fillTo,
      ]);
      expect(ms(steps), [200, 500, 2500, 500, 200]);
      expect(steps.first.data['percent'], 100);
      expect(steps[3].data['level'], 1);
      expect(steps.last.data['percent'], 20);
    });

    test('level 1 has no animation', () {
      final after = train();
      final steps = plan(
        levelUpEvent(1),
        after: after,
        result: HtApplyResult(after),
      );

      expect(steps, isEmpty);
    });

    test('the same level only refreshes the bar', () {
      final after = train(level: 4, value: 20);
      final steps = plan(
        levelUpEvent(4),
        before: train(level: 4),
        after: after,
      );

      expect(kinds(steps), [HtStepKind.fillTo]);
    });

    test('treasure: one level before, at and after the threshold', () {
      expect(
        kinds(levelTo(2, treasure: _treasure)),
        containsAllInOrder([HtStepKind.levelComplete, HtStepKind.instruction]),
      );
      expect(
        levelTo(
          2,
          treasure: _treasure,
        ).firstWhere((s) => s.kind == HtStepKind.instruction).data['text'],
        'treasureOneAway',
      );

      final unlock = levelTo(3, treasure: _treasure, treasureNow: true);
      expect(
        kinds(unlock),
        containsAllInOrder([
          HtStepKind.levelComplete,
          HtStepKind.coinUnlock,
          HtStepKind.marquee,
          HtStepKind.instruction,
          HtStepKind.fillTo,
        ]),
      );
      expect(ms(unlock).sublist(4, 7), [1600, 3000, 2000]);

      expect(
        kinds(levelTo(4, treasure: _treasure)),
        isNot(contains(HtStepKind.coinUnlock)),
      );
      expect(
        kinds(levelTo(4, treasure: _treasure)),
        isNot(contains(HtStepKind.instruction)),
      );
    });

    test('community unlocks with the rocket', () {
      final community = HtCommunity.parse(const {});

      final steps = levelTo(5, community: community, communityNow: true);

      expect(
        kinds(steps),
        containsAllInOrder([
          HtStepKind.levelComplete,
          HtStepKind.rocketLaunch,
          HtStepKind.marquee,
          HtStepKind.instruction,
        ]),
      );
    });

    test('mythic shows the emote pool', () {
      final steps = levelTo(3, variant: HtVariant.mythic);

      expect(kinds(steps).sublist(4), [
        HtStepKind.mythicPool,
        HtStepKind.instruction,
        HtStepKind.fillTo,
      ]);
      expect(ms(steps).sublist(4, 6), [2500, 2000]);
    });

    test('a shared train goes rainbow and shows its top 3', () {
      final steps = levelTo(2, shared: sharedOf({'a': HtAthState.none}));

      final marquee = steps.firstWhere((s) => s.kind == HtStepKind.marquee);
      expect(marquee.rainbow, isTrue);
      expect(marquee.duration, const Duration(milliseconds: 6000));
      expect(
        kinds(steps),
        containsAllInOrder([HtStepKind.levelComplete, HtStepKind.sharedTop3]),
      );
      expect(
        steps.firstWhere((s) => s.kind == HtStepKind.sharedTop3).duration,
        const Duration(milliseconds: 3500),
      );
    });
  });

  group('record', () {
    test('reaching it adds a slide, and one per other channel', () {
      final before = train(
        shared: sharedOf({
          '1': HtAthState.none,
          '2': HtAthState.approaching,
          '3': HtAthState.reached,
        }),
      );
      final after = train(
        value: 50,
        athState: HtAthState.reached,
        shared: sharedOf({
          '1': HtAthState.reached,
          '2': HtAthState.justReached,
          '3': HtAthState.reached,
        }),
      );

      final steps = plan(
        progressionEvent(),
        before: before,
        after: after,
        result: HtApplyResult(after, athTransition: HtAthTransition.reached),
      );

      expect(kinds(steps), [
        HtStepKind.fillTo,
        HtStepKind.athReached,
        HtStepKind.athOtherChannel,
        HtStepKind.athOtherChannel,
      ]);
      expect(ms(steps).sublist(1), [6000, 6000, 6000]);
    });

    test('approaching it only switches the style', () {
      final after = train(value: 50, athState: HtAthState.approaching);

      final steps = plan(
        progressionEvent(),
        before: train(),
        after: after,
        result: HtApplyResult(
          after,
          athTransition: HtAthTransition.approaching,
        ),
      );

      expect(kinds(steps), [HtStepKind.fillTo, HtStepKind.fadeIn]);
    });
  });

  test('a merge counts the level up', () {
    final before = train(level: 3);
    final after = train(level: 9);

    final steps = plan(
      HtMergeEvent(train: after),
      before: before,
      after: after,
      result: HtApplyResult(
        after,
        levelChangedFrom: 3,
        mergedFrom: before.progress,
      ),
    );

    expect(kinds(steps), [
      HtStepKind.mergeAura,
      HtStepKind.marquee,
      HtStepKind.progress,
    ]);
    expect(ms(steps), [1000, 3000, 0]);
    expect(steps[1].data['fromLevel'], 3);
    expect(steps[1].data['toLevel'], 9);
  });

  test('a channel leaving names where the train goes on', () {
    final after = train();

    final goesOn = plan(
      HtChannelLeftEvent(shouldEnd: false, continuesIn: user('43')),
      after: after,
      result: HtApplyResult(after, continuesIn: user('43')),
    );
    expect(kinds(goesOn), [
      HtStepKind.channelLeftSummary,
      HtStepKind.continuesIn,
    ]);
    expect(ms(goesOn), [2000, 3000]);

    final done = plan(const HtChannelLeftEvent(shouldEnd: false), after: after);
    expect(kinds(done), [
      HtStepKind.channelLeftSummary,
      HtStepKind.instruction,
    ]);
    expect(done.last.data['text'], 'seeYouNextTime');
  });

  test('a conductor update takes no time', () {
    final after = train();

    expect(
      plan(
        HtConductorEvent(HtConductor(source: HtSource.bits, user: user('a'))),
        after: after,
      ),
      isEmpty,
    );
  });

  group('end', () {
    List<HtStep> end(
      HypeTrainExecution after, {
      HtEndReason reason = HtEndReason.completed,
    }) => plan(
      HtEndEvent(reason: reason),
      after: after.copyWith(endReason: reason),
    );

    test('completed', () {
      final steps = end(train());

      expect(kinds(steps), [
        HtStepKind.marquee,
        HtStepKind.totals,
        HtStepKind.summary,
        HtStepKind.rewardsStrip,
      ]);
      expect(ms(steps), [3000, 6000, 2000, 20000]);
    });

    test('our own end (no event from Twitch) skips the totals', () {
      final after = train().copyWith(endReason: HtEndReason.completed);
      final steps = plan(
        const HtEndEvent(reason: HtEndReason.completed, synthesized: true),
        after: after,
      );

      expect(kinds(steps), isNot(contains(HtStepKind.totals)));
      expect(kinds(steps), contains(HtStepKind.rewardsStrip));
    });

    test('completed mythic reveals the chosen emote', () {
      final steps = end(train(variant: HtVariant.mythic));

      expect(kinds(steps).sublist(0, 3), [
        HtStepKind.marquee,
        HtStepKind.mythicSelect,
        HtStepKind.mythicReveal,
      ]);
    });

    test('completed community explains the gifted emotes', () {
      final steps = end(train(community: HtCommunity.parse(const {})));

      expect(kinds(steps).sublist(0, 3), [
        HtStepKind.marquee,
        HtStepKind.instruction,
        HtStepKind.totals,
      ]);
    });

    test('completed shared goes rainbow with its top 3', () {
      final steps = end(train(shared: sharedOf({'a': HtAthState.none})));

      expect(steps.first.rainbow, isTrue);
      expect(steps.first.duration, const Duration(milliseconds: 13500));
      expect(
        kinds(steps),
        containsAllInOrder([HtStepKind.totals, HtStepKind.sharedTop3]),
      );
    });

    test('completed at a new record', () {
      final steps = end(train(athState: HtAthState.reached));

      expect(steps.first.rainbow, isTrue);
      expect(steps.first.duration, const Duration(milliseconds: 12600));
      expect(
        steps.firstWhere((s) => s.kind == HtStepKind.summary).data['ath'],
        isTrue,
      );
    });

    test('expired or unknown only shows the strip', () {
      for (final reason in [HtEndReason.expired, HtEndReason.unknown]) {
        final steps = end(train(), reason: reason);

        expect(kinds(steps), [HtStepKind.expiredStrip]);
        expect(ms(steps), [20000]);
      }
    });
  });

  group('modifiers', () {
    HtPlanInput sharedLevelUp({
      bool compact = false,
      bool reduceMotion = false,
      bool presenterVisible = true,
    }) {
      final before = train(
        level: 2,
        treasure: _treasure,
        shared: sharedOf({'a': HtAthState.none}),
      );
      final after = train(
        level: 3,
        treasure: _treasure,
        shared: sharedOf({'a': HtAthState.none}),
      );
      return HtPlanInput(
        event: levelUpEvent(3),
        before: before,
        after: after,
        result: HtApplyResult(
          after,
          levelChangedFrom: 2,
          treasureUnlockedNow: true,
        ),
        compact: compact,
        reduceMotion: reduceMotion,
        presenterVisible: presenterVisible,
      );
    }

    test('reduce motion: static text, no rainbow, a still icon', () {
      final normal = planSequence(sharedLevelUp());
      final still = planSequence(sharedLevelUp(reduceMotion: true));

      expect(still.any((s) => s.rainbow), isFalse);
      expect(kinds(still), isNot(contains(HtStepKind.coinUnlock)));
      expect(kinds(still), contains(HtStepKind.unlockIcon));
      expect(
        still.firstWhere((s) => s.kind == HtStepKind.unlockIcon).duration,
        const Duration(milliseconds: 1000),
      );
      expect(
        still
            .where((s) => s.kind == HtStepKind.marquee)
            .every((s) => s.data['static'] == true),
        isTrue,
      );
      Duration textHold(List<HtStep> steps) => total([
        for (final s in steps)
          if (s.kind == HtStepKind.marquee || s.kind == HtStepKind.instruction)
            s,
      ]);
      expect(textHold(still), textHold(normal));
    });

    test('compact: a level-up is only the level pill', () {
      final steps = planSequence(sharedLevelUp(compact: true));

      expect(kinds(steps), [HtStepKind.levelComplete]);
      expect(ms(steps), [2500]);
    });

    test('compact: progress is silent, strips stay', () {
      final after = train(value: 50);
      expect(
        plan(progressionEvent(isLarge: true), after: after, compact: true),
        isEmpty,
      );
      expect(
        kinds(
          plan(
            const HtEndEvent(reason: HtEndReason.completed),
            after: after.copyWith(endReason: HtEndReason.completed),
            compact: true,
          ),
        ),
        [HtStepKind.rewardsStrip],
      );
    });

    test('an invisible presenter takes no time and skips the strips', () {
      final steps = planSequence(sharedLevelUp(presenterVisible: false));
      final after = train();
      final ended = plan(
        const HtEndEvent(reason: HtEndReason.completed),
        after: after.copyWith(endReason: HtEndReason.completed),
        presenterVisible: false,
      );

      expect(steps, isNotEmpty);
      expect(total(steps), Duration.zero);
      expect(total(ended), Duration.zero);
      expect(kinds(ended), isNot(contains(HtStepKind.rewardsStrip)));
      expect(_k, contains(HtStepKind.expiredStrip));
    });
  });
}
