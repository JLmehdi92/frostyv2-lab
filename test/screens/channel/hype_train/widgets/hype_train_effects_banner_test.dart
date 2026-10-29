import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/hype_train_event.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/coin_unlock.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/merge_aura.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/mythic_reveal.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/rainbow_sweep.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/rocket_launch.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/trophy_burst.dart';

import '../hype_train_test_data.dart';
import 'hype_train_widget_harness.dart';

const _treasure = HtTreasure(
  discountPercentage: 50,
  threshold: 3,
  status: HtUnlockStatus.none,
);

HtShared sharedWith(List<String> ids) => HtShared(
  id: 's',
  channels: [
    for (final id in ids)
      HtSharedChannel(user: user(id), progress: progress(total: 100)),
  ],
);

HtReward emote(int i) =>
    HtReward(type: HtRewardType.emote, id: 'emote$i', token: 'e$i');

/// Pumps frame by frame (100 ms) for [ms], noting whether [finder] showed.
Future<bool> seenWithin(WidgetTester tester, Finder finder, int ms) async {
  var seen = false;
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    seen = seen || finder.evaluate().isNotEmpty;
  }
  return seen;
}

/// Pumps frame by frame (100 ms) until [finder] shows, for at most [ms].
Future<void> untilSeen(WidgetTester tester, Finder finder, int ms) async {
  for (var t = 0; t < ms && finder.evaluate().isEmpty; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  HtHarness harnessFor(HypeTrainExecution train) => HtHarness(
    snapshot: HtOngoingSnapshot(train, fetchedAt: DateTime.utc(2026)),
  );

  testWidgets('treasure: the coin unlocks at the threshold', (tester) async {
    final h = harnessFor(liveTrain(level: 2, treasure: _treasure));
    await pumpSlot(tester, h.store);
    expect(
      find.text('Reach Level 3 to unlock 50% OFF Gift Subs!'),
      findsOneWidget,
    );

    h.inject(htLevelUp(3));
    await tester.pump();

    expect(await seenWithin(tester, find.byType(CoinUnlock), 6000), isTrue);
    expect(
      find.text('50% OFF 5+ Gift Subs for the rest of this Hype Train'),
      findsOneWidget,
    );
    await h.close(tester);
  });

  testWidgets('community: the rocket at the threshold', (tester) async {
    final h = harnessFor(
      liveTrain(level: 4, community: HtCommunity.parse(const {})),
    );
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(5));
    await tester.pump();

    expect(await seenWithin(tester, find.byType(RocketLaunch), 6000), isTrue);
    await h.close(tester);
  });

  testWidgets('mythic end: the roulette lands on the chosen emote', (
    tester,
  ) async {
    final pool = [for (var i = 0; i < 5; i++) emote(i)];
    final h = harnessFor(
      liveTrain(
        variant: HtVariant.mythic,
        mythic: HtMythic(pool: pool, selectedEmote: pool[3]),
        expiresIn: const Duration(minutes: 5),
      ),
    );
    await pumpSlot(tester, h.store);

    h.inject(const HtEndEvent(reason: HtEndReason.completed));
    await tester.pump();
    // The rewards marquee (3 s), then the roulette (2 s, from its first
    // frame); it stays on screen while fading out.
    for (var t = 0; t < 5300; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final roulette = tester.state<MythicSelectState>(find.byType(MythicSelect));
    expect(roulette.highlighted, 3);
    await h.close(tester);
  });

  testWidgets('shared level-up: rainbow on the marquee only, then top 3', (
    tester,
  ) async {
    final h = harnessFor(liveTrain(level: 2, shared: sharedWith(['a', 'b'])));
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(RainbowSweep), findsNothing, reason: 'flash first');

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RainbowSweep), findsOneWidget);

    expect(
      await seenWithin(tester, find.textContaining('50%'), 9000),
      isTrue,
      reason: 'each of two channels holds half',
    );
    expect(find.byType(RainbowSweep), findsNothing);
    await h.close(tester);
  });

  testWidgets('record reached: the trophy', (tester) async {
    final h = harnessFor(liveTrain());
    await pumpSlot(tester, h.store);

    h.inject(
      HtProgressionEvent(
        trainId: 'train',
        sequenceId: 16100,
        action: const HtAction('CHEER'),
        source: HtSource.bits,
        quantity: 60,
        isLarge: false,
        progress: progress(
          level: 7,
          value: 1600,
          goal: 4700,
          total: 16100,
          athState: HtAthState.reached,
        ),
      ),
    );
    await tester.pump();

    expect(await seenWithin(tester, find.byType(TrophyBurst), 1500), isTrue);
    expect(find.text('All-time record shattered!'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a merge counts the level pill up', (tester) async {
    final h = harnessFor(liveTrain(level: 3, total: 9000));
    await pumpSlot(tester, h.store);

    h.inject(
      HtMergeEvent(
        train: liveTrain(id: 'merged', level: 5, total: 20000),
        previousChannels: [user('a')],
        joiningChannels: [user('b')],
      ),
    );
    await tester.pump();
    expect(find.byType(HtAvatar), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 500));
    // One counting pill, the merge's own, between the auras.
    expect(find.text('LVL 4'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(MergeAura), matching: find.text('LVL 4')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('LVL 5'), findsWidgets);
    expect(find.text('LVL 4'), findsNothing);
    await h.close(tester);
  });

  testWidgets('the coin is as tall as the banner', (tester) async {
    final h = harnessFor(liveTrain(level: 2, treasure: _treasure));
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(3));
    await tester.pump();
    await untilSeen(tester, find.byType(CoinUnlock), 6000);
    // Past its cross-fade in.
    await tester.pump(const Duration(milliseconds: 100));
    // The padlock reads on the unlocked treasure's blue-green.
    final lock = tester.widget<Icon>(
      find.descendant(
        of: find.byType(CoinUnlock),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.lock_rounded ||
                  w.icon == Icons.lock_open_rounded),
        ),
      ),
    );
    expect(lock.color, Colors.white);
    expect(
      tester.getSize(find.byType(CoinUnlock)).height,
      tester.getSize(find.byKey(const ValueKey('ht-banner'))).height,
    );
    await h.close(tester);
  });

  testWidgets('the rocket flies across the whole banner', (tester) async {
    final h = harnessFor(
      liveTrain(level: 4, community: HtCommunity.parse(const {})),
    );
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(5));
    await tester.pump();
    await untilSeen(tester, find.byType(RocketLaunch), 6000);
    // Past its cross-fade in.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byType(RocketLaunch)),
      tester.getSize(find.byKey(const ValueKey('ht-banner'))),
    );
    await h.close(tester);
  });

  testWidgets('a shared level-up: the rainbow fills the banner, text black', (
    tester,
  ) async {
    final h = harnessFor(liveTrain(level: 2, shared: sharedWith(['a', 'b'])));
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));

    final rainbow = find.byKey(const ValueKey('rainbow'));
    expect(
      tester.getSize(rainbow),
      tester.getSize(find.byKey(const ValueKey('ht-banner'))),
    );
    expect(
      tester.widget<Text>(find.text('hyyyyypeeee')).style?.color,
      Colors.black,
    );
    await h.close(tester);
  });

  testWidgets('shared trains draw speedlines; others do not', (tester) async {
    var h = harnessFor(liveTrain(shared: sharedWith(['a', 'b'])));
    await pumpSlot(tester, h.store);
    expect(find.byKey(const ValueKey('ht-speedlines')), findsOneWidget);
    await h.close(tester);

    h = harnessFor(liveTrain());
    await pumpSlot(tester, h.store);
    expect(find.byKey(const ValueKey('ht-speedlines')), findsNothing);
    await h.close(tester);
  });

  group('a merge after a level-up', () {
    Future<HtHarness> levelledUp(WidgetTester tester) async {
      final h = harnessFor(liveTrain(level: 2, total: 9000));
      await pumpSlot(tester, h.store);
      h.inject(htLevelUp(3));
      await tester.pump();
      for (var t = 0; t < 60; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(h.store.step, isNull);
      expect(h.store.shownLevel, 3);
      return h;
    }

    Finder mergePill(String text) =>
        find.descendant(of: find.byType(MergeAura), matching: find.text(text));

    testWidgets('keeping the level does not count from an older one', (
      tester,
    ) async {
      final h = await levelledUp(tester);

      h.inject(
        HtMergeEvent(
          train: liveTrain(id: 'merged', level: 3, total: 20000),
          previousChannels: [user('a')],
          joiningChannels: [user('b')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mergePill('LVL 2'), findsNothing);
      expect(mergePill('LVL 3'), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('raising the level counts from the current one', (
      tester,
    ) async {
      final h = await levelledUp(tester);

      h.inject(
        HtMergeEvent(
          train: liveTrain(id: 'merged', level: 5, total: 30000),
          previousChannels: [user('a')],
          joiningChannels: [user('b')],
        ),
      );
      await tester.pump();

      expect(mergePill('LVL 3'), findsOneWidget);
      expect(mergePill('LVL 2'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(mergePill('LVL 4'), findsOneWidget);
      await h.close(tester);
    });
  });
}
