import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/hype_train_event.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_slot.dart';

import '../helpers/l10n.dart';
import '../screens/channel/hype_train/hype_train_test_data.dart';
import '../screens/channel/hype_train/widgets/hype_train_widget_harness.dart';

/// The hype train in French: the banner through its steps (start, level up,
/// a large contribution, the end and its strip) and its sheet, in each
/// variant, in every window and at both text scales, with no overflow and
/// no English.
void main() {
  final french = lookupAppLocalizations(fr);
  final copy = HtCopy(french);

  const treasure = HtTreasure(
    discountPercentage: 50,
    threshold: 3,
    status: HtUnlockStatus.none,
  );
  final community = HtCommunity.parse(const {
    'rewardLevelThreshold': 5,
    'nextRewardAmount': 20,
    'currentRewardAmount': 30,
  });
  final shared = HtShared(
    id: 's',
    channels: [
      for (final id in ['alice', 'bob'])
        HtSharedChannel(user: user(id), progress: progress(total: 50)),
    ],
  );
  HtReward emote(String id) =>
      HtReward(type: HtRewardType.emote, id: id, token: id);

  // Each variant the banner and the sheet word differently.
  final variants = <String, HypeTrainExecution Function()>{
    'normal': () =>
        liveTrain(level: 2, expiresIn: const Duration(minutes: 5)).copyWith(
          conductors: [
            HtConductor(
              source: HtSource.subs,
              user: user('giver'),
              participations: const {'TIER_1_GIFTED_SUB': 5},
            ),
          ],
          ath: const HtAth(level: 9, goal: 0, progression: 0, total: 99999),
        ),
    'golden kappa': () => liveTrain(
      level: 2,
      variant: HtVariant.goldenKappa,
      expiresIn: const Duration(minutes: 5),
    ),
    'treasure, locked': () => liveTrain(
      level: 2,
      treasure: treasure,
      expiresIn: const Duration(minutes: 5),
    ),
    'treasure, unlocked': () => liveTrain(
      level: 4,
      treasure: treasure,
      expiresIn: const Duration(minutes: 5),
    ),
    'community': () => liveTrain(
      level: 6,
      community: community,
      expiresIn: const Duration(minutes: 5),
    ),
    'mythic': () => liveTrain(
      level: 2,
      variant: HtVariant.mythic,
      mythic: HtMythic(pool: [emote('a'), emote('b')]),
      expiresIn: const Duration(minutes: 5),
    ),
    'shared': () => liveTrain(
      level: 2,
      shared: shared,
      expiresIn: const Duration(minutes: 5),
    ),
  };

  /// [store]'s slot as the channel screen lays it: the chat's width (a
  /// tablet's side chat in landscape), compact on a landscape phone.
  Widget slot(HypeTrainStore store, Size size) {
    final landscapePhone = size.width > size.height && size.height < 500;
    final width = size.width >= 1000 ? 400.0 : size.width;
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: HypeTrainSlot(
            store: store,
            compact: landscapePhone,
            onLearnMore: () {},
          ),
        ),
      ),
    );
  }

  /// Steps [duration] in 250 ms frames, checking each one.
  Future<void> play(
    WidgetTester tester,
    Duration duration,
    String where,
  ) async {
    for (var t = 0; t < duration.inMilliseconds; t += 250) {
      await tester.pump(const Duration(milliseconds: 250));
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$where at $t ms: $exception');
      expect(englishLeaks(tester), isEmpty, reason: '$where at $t ms');
    }
  }

  for (final (sizeName, size) in frenchChannelScreenSizes) {
    for (final scale in frenchTextScales) {
      testWidgets('the banner in each variant, $sizeName, text ×$scale', (
        tester,
      ) async {
        for (final MapEntry(key: name, value: build) in variants.entries) {
          final train = build();
          final h = HtHarness(
            snapshot: HtOngoingSnapshot(train, fetchedAt: DateTime.utc(2026)),
          );
          await pumpLocalized(
            tester,
            slot(h.store, size),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          await tester.pump();
          final where = '$name, $sizeName, ×$scale';
          await expectFrenchThroughout(tester, where);
          // The start's steps, then a large gift and a level up.
          await play(tester, const Duration(seconds: 4), '$where, start');
          h.inject(htSmall(16500, level: train.level, isLarge: true));
          await play(tester, const Duration(seconds: 3), '$where, large gift');
          h.inject(htLevelUp(train.level + 1));
          await play(tester, const Duration(seconds: 6), '$where, level up');
          // The end: the summary, then the rewards strip.
          h.inject(
            HtEndEvent(
              reason: HtEndReason.completed,
              rewards: [emote('a'), emote('b')],
            ),
          );
          await play(tester, const Duration(seconds: 14), '$where, end');
          await h.close(tester);
        }
      });
    }
  }

  testWidgets('an expired train, and an approaching one', (tester) async {
    for (final (sizeName, size) in frenchChannelScreenSizes) {
      final expired = HtHarness(
        snapshot: HtOngoingSnapshot(
          liveTrain(expiresIn: const Duration(minutes: 5)),
          fetchedAt: DateTime.utc(2026),
        ),
      );
      await pumpLocalized(tester, slot(expired.store, size), size: size);
      await tester.pump();
      expired.inject(const HtEndEvent(reason: HtEndReason.expired));
      await play(tester, const Duration(seconds: 10), 'expired, $sizeName');
      expect(find.text(french.htExpired), findsOneWidget);
      await expired.close(tester);

      final approaching = HtHarness();
      await pumpLocalized(tester, slot(approaching.store, size), size: size);
      await tester.pump();
      approaching.inject(
        HtApproachingEvent(
          HypeTrainApproaching(
            id: 'a',
            goal: 3,
            deadlines: const {1: 60},
            levelOneRewards: [emote('first')],
          ),
        ),
      );
      await play(tester, const Duration(seconds: 2), 'approaching, $sizeName');
      await approaching.close(tester);
    }
  });

  for (final (sizeName, size) in frenchChannelScreenSizes) {
    for (final scale in frenchTextScales) {
      testWidgets('the sheet in each variant, $sizeName, text ×$scale', (
        tester,
      ) async {
        for (final MapEntry(key: name, value: build) in variants.entries) {
          final train = build();
          final h = HtHarness(
            snapshot: HtOngoingSnapshot(
              train.copyWith(
                progress: HtProgress(
                  level: HtLevel(
                    value: train.level,
                    cumulativeGoal: 20000,
                    rewards: [emote('level1'), emote('level2')],
                  ),
                  goal: train.progress.goal,
                  value: train.progress.value,
                  total: train.progress.total,
                ),
              ),
              fetchedAt: DateTime.utc(2026),
            ),
          );
          await pumpLocalized(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: math.min(size.width, 600),
                  child: HypeTrainSheet(store: h.store, onLearnMore: () {}),
                ),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          await tester.pump();
          await expectFrenchThroughout(tester, '$name, $sizeName, ×$scale');
          await h.close(tester);
        }
      });
    }
  }

  testWidgets('the sheet of an approaching train', (tester) async {
    for (final (sizeName, size) in frenchChannelScreenSizes) {
      final h = HtHarness();
      await pumpLocalized(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: HypeTrainSheet(store: h.store, onLearnMore: () {}),
          ),
        ),
        size: size,
        textScale: 1.3,
      );
      h.inject(
        HtApproachingEvent(
          HypeTrainApproaching(
            id: 'a',
            goal: 3,
            deadlines: const {1: 60},
            levelOneRewards: [emote('first')],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(copy.approachingQuestion(HtVariant.regular)), findsOne);
      await expectFrenchThroughout(tester, 'approaching sheet, $sizeName');
      await h.close(tester);
    }
  });

  group('French words', () {
    test('levels, percentages and counts', () {
      expect(copy.level(3), 'NIV. 3');
      expect(copy.percent(50), '50 %');
      expect(copy.sharedLevel(3, 40), 'NIV. 3, 40 %');
      expect(copy.subsTotal(0), '0 abonnement');
      expect(copy.subsTotal(1), '1 abonnement');
      expect(copy.subsTotal(2), '2 abonnements');
      expect(copy.bitsTotal(1200), '1 200 Bits');
      expect(copy.approachingMore(1), contains('1 personne doit'));
      expect(copy.approachingMore(3), contains('3 personnes doivent'));
      expect(
        copy.treasureLocked(3, 35),
        'Niveau 3\u00a0: −35\u202f% sur les abonnements offerts\u202f!',
      );
    });

    test('each variant has its name', () {
      final names = {
        for (final variant in HtVariant.values) copy.trainTitle(variant),
      };
      expect(names, {
        'Hype Train',
        'Hype Train Kappa doré',
        'Hype Train trésor',
        'Hype Train collectif',
        'Hype Train mythique',
      });
      expect(
        copy.trainTitle(HtVariant.goldenKappa, shared: true),
        'Hype Train Kappa doré partagé',
      );
      expect(copy.summary(4).split('\n'), hasLength(2));
      expect(copy.summary(4, ath: true).split('\n'), hasLength(2));
    });

    test('contributions name who gave, never eliding before the name', () {
      expect(
        copy.contribution(null, const HtAction('CHEER'), 1),
        'Quelqu’un vient d’utiliser 1 Bit !',
      );
      expect(
        copy.contribution('Alice', const HtAction('TIER_1_GIFTED_SUB'), 5),
        'Alice vient d’offrir 5 abonnements de niveau 1 !',
      );
      expect(
        copy.contribution('Alice', const HtAction('TIER_2_SUB'), 1),
        'Alice vient de s’abonner au niveau 2 !',
      );
    });
  });
}
