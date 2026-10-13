import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/coin_unlock.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/merge_aura.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/mythic_reveal.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/rainbow_sweep.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/rocket_launch.dart';
import 'package:frosty/screens/channel/hype_train/widgets/effects/trophy_burst.dart';

const _duration = Duration(milliseconds: 1600);

Future<void> pumpEffect(WidgetTester tester, Widget effect) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 200, height: 48, child: effect)),
        ),
      ),
    );

HtReward emote(int i) =>
    HtReward(type: HtRewardType.emote, id: 'emote$i', token: 'e$i');

HtUser user(String id) => HtUser(id: id, login: id, displayName: 'User $id');

void main() {
  group('coin unlock', () {
    testWidgets('flips, then sparkles after 70%, then unlocks', (tester) async {
      await pumpEffect(
        tester,
        const CoinUnlock(duration: _duration, discount: 50),
      );
      final state = tester.state<CoinUnlockState>(find.byType(CoinUnlock));

      expect(find.byKey(const ValueKey('coin')), findsOneWidget);
      expect(find.byKey(const ValueKey('sparkle-0')), findsNothing);
      expect(state.progress, 0);

      await tester.pump(const Duration(milliseconds: 800));
      expect(state.progress, closeTo(0.5, 0.01));
      expect(find.byKey(const ValueKey('sparkle-0')), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sparkle-0')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(state.progress, 1);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('reduced motion is a still coin', (tester) async {
      await pumpEffect(
        tester,
        const CoinUnlock(duration: _duration, discount: 50, reduceMotion: true),
      );

      expect(find.byKey(const ValueKey('coin')), findsOneWidget);
      expect(
        tester.state<CoinUnlockState>(find.byType(CoinUnlock)).progress,
        1,
      );
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });
  });

  testWidgets('the rocket climbs up and right', (tester) async {
    await pumpEffect(tester, const RocketLaunch(duration: _duration));
    Offset rocket() => tester.getCenter(find.byKey(const ValueKey('rocket')));

    final start = rocket();
    await tester.pump(const Duration(milliseconds: 800));
    final middle = rocket();
    expect(middle.dx, greaterThan(start.dx));
    expect(middle.dy, lessThan(start.dy));
    expect(find.byKey(const ValueKey('rocket-burst')), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('rocket-burst')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('the rainbow sweep moves and loops its cycles', (tester) async {
    await pumpEffect(
      tester,
      const RainbowSweep(
        cycleDuration: Duration(milliseconds: 2000),
        child: Text('content'),
      ),
    );
    final state = tester.state<RainbowSweepState>(find.byType(RainbowSweep));
    final first = state.gradient.begin;

    await tester.pump(const Duration(milliseconds: 1000));
    expect(state.gradient.begin, isNot(first));
    expect(find.text('content'), findsOneWidget);

    // Frame by frame, as on a device: a cycle restarts on a frame.
    for (var i = 0; i < 49; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.isAnimating, isTrue, reason: 'third cycle');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.isAnimating, isFalse, reason: 'three cycles then stop');
  });

  testWidgets('the trophy pops in', (tester) async {
    await pumpEffect(
      tester,
      const TrophyBurst(duration: Duration(milliseconds: 6000)),
    );
    final state = tester.state<TrophyBurstState>(find.byType(TrophyBurst));

    expect(find.byKey(const ValueKey('trophy')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.scale, greaterThan(0.5));
    await tester.pump(const Duration(seconds: 6));
  });

  group('mythic', () {
    final pool = [for (var i = 0; i < 6; i++) emote(i)];

    testWidgets('the roulette lands on the selected emote', (tester) async {
      await pumpEffect(
        tester,
        MythicSelect(
          duration: const Duration(milliseconds: 2000),
          pool: pool,
          selected: pool[4],
        ),
      );
      final state = tester.state<MythicSelectState>(find.byType(MythicSelect));
      final seen = <int>{};
      for (var i = 0; i < 19; i++) {
        seen.add(state.highlighted);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 200));

      expect(seen.length, greaterThan(2), reason: 'it cycles');
      expect(state.highlighted, 4);
    });

    testWidgets('an unknown selection still settles', (tester) async {
      await pumpEffect(
        tester,
        MythicSelect(
          duration: const Duration(milliseconds: 2000),
          pool: pool,
          selected: emote(99),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(
        tester.state<MythicSelectState>(find.byType(MythicSelect)).highlighted,
        inInclusiveRange(0, 5),
      );
    });

    testWidgets('the reveal scales the emote up', (tester) async {
      await pumpEffect(
        tester,
        MythicReveal(
          duration: const Duration(milliseconds: 2000),
          emote: pool.first,
        ),
      );

      expect(find.byKey(const ValueKey('mythic-reveal')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('merge aura staggers both groups of avatars', (tester) async {
    await pumpEffect(
      tester,
      MergeAura(
        duration: const Duration(milliseconds: 1000),
        previous: [user('1'), user('2')],
        joining: [user('3')],
      ),
    );

    expect(find.byType(HtAvatar), findsNWidgets(3));
    expect(find.text('+'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('avatars without a CDN picture show an initial', (tester) async {
    await pumpEffect(
      tester,
      HypeTrainAvatarStack(users: [user('7'), user('8')]),
    );

    expect(find.text('U'), findsNWidgets(2));
  });
}
