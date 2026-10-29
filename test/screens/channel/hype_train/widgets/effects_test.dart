import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/coin_unlock.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/hype_train_avatar_stack.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/merge_aura.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/mythic_reveal.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/rainbow_sweep.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/rocket_launch.dart';
import 'package:onset/screens/channel/hype_train/widgets/effects/trophy_burst.dart';

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

  testWidgets("the rainbow cycles Twitch's four colours top to bottom", (
    tester,
  ) async {
    await pumpEffect(
      tester,
      const RainbowSweep(
        cycleDuration: Duration(milliseconds: 2000),
        child: Text('content'),
      ),
    );
    final state = tester.state<RainbowSweepState>(find.byType(RainbowSweep));
    const pink = Color(0xFFFA1ED2);
    const lilac = Color(0xFFF093F9);
    const orange = Color(0xFFED722F);
    const yellow = Color(0xFFFAF31A);

    expect(state.gradient.begin, Alignment.topCenter);
    expect(state.gradient.end, Alignment.bottomCenter);
    expect(state.gradient.colors, const [pink, lilac, orange, yellow]);
    expect(find.text('content'), findsOneWidget);

    // Frame by frame, as on a device: a cycle restarts on a frame.
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.gradient.colors, const [lilac, orange, yellow, pink]);

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      state.gradient.colors.first,
      Color.lerp(lilac, orange, 0.5),
      reason: 'linear between quarters',
    );

    for (var i = 0; i < 47; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.isAnimating, isTrue, reason: 'third cycle');
    for (var i = 0; i < 8; i++) {
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

  testWidgets('merge aura: both groups around a counting pill', (tester) async {
    await pumpEffect(
      tester,
      MergeAura(
        duration: const Duration(milliseconds: 1000),
        previous: [user('1'), user('2')],
        joining: [user('3')],
        fromLevel: 3,
        level: 5,
      ),
    );

    expect(find.byType(HtAvatar), findsNWidgets(3));
    expect(find.text('LVL 3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LVL 4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LVL 5'), findsOneWidget);
  });

  testWidgets("merge auras sit at Twitch's offsets around the pill", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 74,
              child: MergeAura(
                duration: const Duration(milliseconds: 1000),
                previous: [user('1'), user('2'), user('3')],
                joining: [user('4'), user('5'), user('6')],
                fromLevel: 3,
                level: 5,
                reduceMotion: true,
              ),
            ),
          ),
        ),
      ),
    );
    final pill = tester.getCenter(find.byKey(const ValueKey('ht-merge-pill')));
    double dy(int aura) =>
        tester.getCenter(find.byKey(ValueKey('ht-aura-$aura'))).dy - pill.dy;
    double dx(int aura) =>
        tester.getCenter(find.byKey(ValueKey('ht-aura-$aura'))).dx;

    expect([for (var i = 1; i <= 6; i++) dy(i)], [-12, 12, -22, -12, 12, 22]);
    // Before the pill: 3, 5, 1; after it: 2, 4, 6.
    expect(dx(3) < dx(5) && dx(5) < dx(1) && dx(1) < pill.dx, isTrue);
    expect(pill.dx < dx(2) && dx(2) < dx(4) && dx(4) < dx(6), isTrue);
    final glow = find.byKey(const ValueKey('ht-aura-glow')).first;
    expect(tester.getSize(glow), const Size(80, 80));
  });

  testWidgets('avatars without a CDN picture show an initial', (tester) async {
    await pumpEffect(
      tester,
      HypeTrainAvatarStack(users: [user('7'), user('8')]),
    );

    expect(find.text('U'), findsNWidgets(2));
  });

  testWidgets('the avatar stack: 32 dp overlapping by 6, "+", joiners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HypeTrainAvatarStack(
              users: [for (var i = 0; i < 8; i++) user('$i')],
              joining: [user('a'), user('b')],
            ),
          ),
        ),
      ),
    );
    final avatars = find.byType(HtAvatar);

    expect(avatars, findsNWidgets(8), reason: 'six, then two joining');
    expect(tester.getSize(avatars.first), const Size(32, 32));
    expect(
      tester.getTopLeft(avatars.at(1)).dx - tester.getTopLeft(avatars.at(0)).dx,
      26,
    );
    final plus = find.byIcon(Icons.add_rounded);
    expect(plus, findsOneWidget);
    expect(tester.getSize(plus), const Size(24, 24));
    expect(
      tester.getTopLeft(plus).dx - tester.getTopRight(avatars.at(5)).dx,
      8,
    );
    expect(
      tester.getTopLeft(avatars.at(6)).dx - tester.getTopRight(plus).dx,
      8,
    );
  });

  testWidgets('every effect leaves no ticker or timer behind', (tester) async {
    final pool = [for (var i = 0; i < 4; i++) emote(i)];
    for (final effect in <Widget>[
      const CoinUnlock(duration: _duration, discount: 50),
      const RocketLaunch(duration: _duration),
      const RainbowSweep(
        cycleDuration: Duration(milliseconds: 500),
        child: SizedBox(),
      ),
      const TrophyBurst(duration: _duration),
      MythicPool(duration: _duration, pool: pool),
      MythicSelect(duration: _duration, pool: pool, selected: pool[1]),
      MythicReveal(duration: _duration, emote: pool.first),
      MergeAura(
        duration: _duration,
        previous: [user('1')],
        joining: [user('2')],
        fromLevel: 1,
        level: 2,
      ),
    ]) {
      await pumpEffect(tester, effect);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull, reason: '$effect');
      expect(tester.binding.transientCallbackCount, 0, reason: '$effect');
    }
  });
}
