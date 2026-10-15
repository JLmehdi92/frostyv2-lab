import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';

import 'hype_train_widget_harness.dart';

const _step = 'ht-step-';

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

    await tester.tap(find.byTooltip('Collapse Hype Train'));
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
}
