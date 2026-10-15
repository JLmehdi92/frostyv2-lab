import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_countdown.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';

import 'hype_train_widget_harness.dart';

const _step = 'ht-step-';

final _banner = find.byKey(const ValueKey('ht-banner'));

Finder stepKey(String kind) => find.byKey(ValueKey('$_step$kind'));

double marqueeX(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('ht-marquee')),
  );
  return transform.transform.getTranslation().x;
}

void main() {
  HtHarness running(WidgetTester tester, {int level = 7}) => HtHarness(
    snapshot: HtOngoingSnapshot(
      liveTrain(level: level),
      fetchedAt: DateTime.utc(2026),
    ),
  );

  testWidgets('shows level, percent and the countdown', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    expect(find.byType(HypeTrainBanner), findsOneWidget);
    expect(find.text('LVL 7'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('0:16'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:15'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a progression fills the bar in 200 ms', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);
    final bar = tester.state<HypeTrainProgressBarState>(
      find.byType(HypeTrainProgressBar),
    );
    expect(bar.value, closeTo(0.33, 0.01));

    h.inject(htSmall(16500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bar.value, closeTo(0.43, 0.01));
    expect(find.text('43%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a large contribution takes over, then the train is back', (
    tester,
  ) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    h.inject(htSmall(16500, isLarge: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(stepKey('largeContribution'), findsOneWidget);
    expect(find.textContaining('Viewer_1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 5000));
    expect(stepKey('largeContribution'), findsOneWidget);

    // The step ends at 6500 ms; the cross-fade starts on the next frame.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stepKey('largeContribution'), findsNothing);
    expect(find.text('43%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a level-up plays flash, marquee, level complete', (
    tester,
  ) async {
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(stepKey('flash100'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('LVL 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 550));
    expect(stepKey('marquee'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    final early = marqueeX(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(marqueeX(tester), lessThan(early));

    await tester.pump(const Duration(milliseconds: 800));
    expect(stepKey('levelComplete'), findsOneWidget);
    expect(find.text('Level 2 Complete!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('LVL 3'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('the marquee runs the other way in RTL', (tester) async {
    Future<double> firstX(TextDirection direction) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, direction: direction);
      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final x = marqueeX(tester);
      await h.close(tester);
      return x;
    }

    expect(await firstX(TextDirection.ltr), greaterThan(0));
    expect(await firstX(TextDirection.rtl), lessThan(0));
  });

  testWidgets('reduced motion: the marquee text stands still', (tester) async {
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store, reduceMotion: true);
    expect(h.store.reduceMotion, isTrue);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(stepKey('marquee'), findsOneWidget);
    expect(find.byKey(const ValueKey('ht-marquee')), findsNothing);
    expect(find.textContaining(HtCopy.levelUp), findsWidgets);
    await h.close(tester);
  });

  testWidgets('semantics: one label, live step text, no countdown node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store);

    expect(
      find.bySemanticsLabel(RegExp(r'level 2, 33 percent, .* left')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('0:16'), findsNothing);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3300));
    // Past the first frame of the cross-fade (opacity 0 hides semantics).
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getSemantics(find.text('Level 2 Complete!')),
      containsSemantics(isLiveRegion: true),
    );

    await h.close(tester);
    semantics.dispose();
  });

  testWidgets('collapses to a pill and expands back', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    // Swipe up: there is no collapse button, as on Twitch.
    expect(find.byTooltip('Collapse Hype Train'), findsNothing);
    await tester.fling(_banner, const Offset(0, -120), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(HypeTrainBanner), findsNothing);
    expect(find.byKey(const ValueKey('ht-pill')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('ht-pill'))).height, 28);

    await tester.tap(find.byKey(const ValueKey('ht-pill')));
    await tester.pumpAndSettle();
    expect(find.byType(HypeTrainBanner), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('large text does not overflow at 360 px', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('LVL 7'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('builds in the dark theme', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store, theme: ThemeData.dark());

    expect(find.text('33%'), findsOneWidget);
    await h.close(tester);
  });

  group('layout', () {
    HtHarness withAth(HtAthState athState) => HtHarness(
      snapshot: HtOngoingSnapshot(
        liveTrain(athState: athState),
        fetchedAt: DateTime.utc(2026),
      ),
    );

    testWidgets(
      'the banner is 74 dp tall',
      (tester) async {
        final h = running(tester);
        await pumpSlot(tester, h.store);

        expect(tester.getSize(_banner).height, 74);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('it grows with the text and never overflows', (tester) async {
      for (final width in [360.0, 280.0, 220.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          final h = running(tester);
          await pumpSlot(tester, h.store, width: width, textScale: scale);

          expect(tester.takeException(), isNull, reason: '$width @ $scale');
          expect(
            tester.getSize(_banner).height,
            greaterThanOrEqualTo(74 * scale - 0.01),
            reason: '$width @ $scale',
          );
          await h.close(tester);
        }
      }
    });

    testWidgets('the level pill is a black pill with LVL n', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(HypeTrainLevelPill),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xCC000000));
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(
        tester.widget<Text>(find.text('LVL 7')).style?.color,
        Colors.white,
      );
      await h.close(tester);
    });

    testWidgets('title, subtitle, percentage and countdown styles', (
      tester,
    ) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final title = tester.widget<Text>(find.byKey(const ValueKey('ht-title')));
      expect(title.data, 'Hype Train');
      expect(title.style?.fontSize, 18);
      expect(title.style?.fontWeight, FontWeight.w700);
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey('ht-subtitle')),
      );
      expect(subtitle.data, 'Sub, gift, or use Bits!');
      expect(subtitle.maxLines, 2);
      expect(subtitle.style?.fontWeight, FontWeight.w400);
      final percent = tester.widget<Text>(
        find.byKey(const ValueKey('ht-percent')),
      );
      expect(percent.style?.fontSize, 24);
      expect(percent.style?.fontWeight, FontWeight.w700);
      final countdown = tester.widget<Text>(
        find.descendant(
          of: find.byType(HypeTrainCountdown),
          matching: find.byType(Text),
        ),
      );
      expect(countdown.style?.fontSize, 14);
      expect(countdown.style?.fontWeight, FontWeight.w400);
      // No variant icon at rest.
      expect(find.byIcon(Icons.train_rounded), findsNothing);
      await h.close(tester);
    });

    testWidgets('the chevron opens the details and turns', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);
      final chevron = find.byIcon(Icons.expand_more_rounded);

      await tester.tap(chevron);
      await tester.pump();
      expect(h.store.expanded, isTrue);
      expect(
        tester
            .widget<AnimatedRotation>(
              find.ancestor(
                of: chevron,
                matching: find.byType(AnimatedRotation),
              ),
            )
            .turns,
        0.5,
      );
      await h.close(tester);
    });

    testWidgets('a screen reader action collapses it', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.customSemanticsActions?.isNotEmpty ?? false),
        ),
      );
      final actions = semantics.properties.customSemanticsActions!;
      expect(actions.keys.single.label, 'Collapse Hype Train');
      actions.values.single();
      await tester.pumpAndSettle();

      expect(h.store.collapsed, isTrue);
      expect(find.byKey(const ValueKey('ht-pill')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('compact: no title, the train name as one line', (
      tester,
    ) async {
      final h = running(tester);
      await pumpSlot(
        tester,
        h.store,
        compact: true,
        width: 220,
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('ht-title')), findsNothing);
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey('ht-subtitle')),
      );
      expect(subtitle.data, 'Hype Train');
      expect(subtitle.maxLines, 1);
      expect(tester.getSize(_banner).height, lessThan(74));
      await h.close(tester);
    });

    testWidgets('a record in sight: the trophy instead of the pill', (
      tester,
    ) async {
      final h = withAth(HtAthState.approaching);
      await pumpSlot(tester, h.store);

      expect(find.byKey(const ValueKey('ht-ath-trophy')), findsOneWidget);
      expect(find.byType(HypeTrainLevelPill), findsNothing);
      expect(find.byKey(const ValueKey('ht-title')), findsNothing);
      expect(find.text(HtCopy.athApproaching), findsOneWidget);
      expect(tester.getSize(_banner).height, 74);
      await h.close(tester);
    });

    testWidgets('a record reached: a trophy in the pill', (tester) async {
      final h = withAth(HtAthState.reached);
      await pumpSlot(tester, h.store);

      expect(
        find.descendant(
          of: find.byType(HypeTrainLevelPill),
          matching: find.byIcon(Icons.emoji_events_rounded),
        ),
        findsOneWidget,
      );
      await h.close(tester);
    });

    testWidgets('right to left: the pill starts on the right', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store, direction: TextDirection.rtl);

      final banner = tester.getRect(_banner);
      expect(
        tester.getRect(find.byType(HypeTrainLevelPill)).right,
        closeTo(banner.right - 8, 0.5),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('ht-percent'))).dx,
        lessThan(banner.center.dx),
      );
      await h.close(tester);
    });

    testWidgets('a flash at 100% does not scale the percentage', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('100%'),
          matching: find.byType(AnimatedScale),
        ),
        findsNothing,
      );
      await h.close(tester);
    });
  });
}
