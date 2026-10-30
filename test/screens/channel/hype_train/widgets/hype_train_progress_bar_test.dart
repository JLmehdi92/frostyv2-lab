import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';

import 'hype_train_widget_harness.dart';

final _clip = find.byKey(const ValueKey('ht-fill-clip'));
final _fill = find.byKey(const ValueKey('ht-fill'));

Future<void> pumpBar(
  WidgetTester tester,
  int percent, {
  HtPalette? palette,
  Duration duration = const Duration(milliseconds: 200),
  TextDirection direction = TextDirection.ltr,
  Duration morph = HypeTrainProgressBar.morphDuration,
  ValueNotifier<double>? edge,
}) => tester.pumpWidget(
  Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        height: 74,
        child: HypeTrainProgressBar(
          percent: percent,
          duration: duration,
          morph: morph,
          edge: edge,
          palette:
              palette ??
              HtPalette.of(HtStyle.regular, const ColorScheme.light()),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the fill is the banner background, clipped to the level', (
    tester,
  ) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);
    final banner = tester.getRect(find.byType(HypeTrainBanner));

    expect(tester.getRect(find.byType(HypeTrainProgressBar)), banner);
    expect(tester.getSize(_clip).width, closeTo(banner.width * 0.33, 0.5));
    expect(tester.getSize(_clip).height, banner.height);
    expect(tester.getSize(_fill).width, banner.width);
    expect(tester.getTopLeft(_clip), banner.topLeft);
    await h.close(tester);
  });

  testWidgets('the fill reaches a new value 200 ms later, decelerating', (
    tester,
  ) async {
    await pumpBar(tester, 10);
    expect(tester.getSize(_clip).width, closeTo(30, 0.5));

    await pumpBar(tester, 60);
    await tester.pump(const Duration(milliseconds: 100));
    final halfway = tester.getSize(_clip).width;
    expect(halfway, greaterThan(30 + 150 / 2), reason: 'decelerates');
    expect(halfway, lessThan(180));

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(_clip).width, closeTo(180, 0.5));
    expect(tester.getSize(_fill).width, 300);
  });

  testWidgets('reduced motion jumps to the new value', (tester) async {
    await pumpBar(tester, 10, duration: Duration.zero);
    await pumpBar(tester, 60, duration: Duration.zero);
    await tester.pump();

    expect(tester.getSize(_clip).width, closeTo(180, 0.5));
  });

  testWidgets('at 100% the fill is the whole banner', (tester) async {
    await pumpBar(tester, 100);

    expect(tester.getSize(_clip), const Size(300, 74));
  });

  testWidgets('right to left the fill grows from the right', (tester) async {
    await pumpBar(tester, 50, direction: TextDirection.rtl);

    expect(tester.getTopLeft(_clip).dx, closeTo(150, 0.5));
  });

  testWidgets('a gradient spans the whole width, not the filled part', (
    tester,
  ) async {
    await pumpBar(
      tester,
      25,
      palette: HtPalette.of(HtStyle.athReached, const ColorScheme.light()),
    );

    expect(tester.getSize(_clip).width, closeTo(75, 0.5));
    expect(tester.getSize(_fill).width, 300);
    final decoration =
        tester.widget<DecoratedBox>(_fill).decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
  });

  testWidgets('an unlocked treasure covers the banner at any level', (
    tester,
  ) async {
    await pumpBar(
      tester,
      10,
      palette: HtPalette.of(
        HtStyle.treasure,
        const ColorScheme.light(),
        treasureUnlocked: true,
      ),
    );

    expect(_clip, findsNothing);
    expect(tester.getSize(_fill), const Size(300, 74));
  });

  group('ONSET level colours', () {
    HtPalette level(int n) =>
        HtPalette.of(HtStyle.regular, const ColorScheme.dark(), level: n);
    HypeTrainProgressBarState state(WidgetTester tester) => tester
        .state<HypeTrainProgressBarState>(find.byType(HypeTrainProgressBar));

    testWidgets('a lower percentage restarts from 0 (a level up)', (
      tester,
    ) async {
      await pumpBar(tester, 100, palette: level(2));
      await pumpBar(tester, 20, palette: level(3));
      await tester.pump(const Duration(milliseconds: 1));
      expect(state(tester).value, lessThan(0.05));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = state(tester).value;
      expect(mid, inExclusiveRange(0.05, 0.2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state(tester).value, closeTo(0.2, 0.001));
    });

    testWidgets("a new level's colour morphs in over 600 ms", (tester) async {
      await pumpBar(tester, 50, palette: level(1));
      await pumpBar(tester, 50, palette: level(2));
      expect(state(tester).morphValue, 0);
      // Both fills are drawn while it morphs.
      expect(
        find.descendant(
          of: find.byType(HypeTrainProgressBar),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(state(tester).morphValue, closeTo(0.5, 0.01));
      final track = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(HypeTrainProgressBar),
              matching: find.byType(ColoredBox),
            ),
          )
          .first
          .color;
      expect(track, isNot(level(1).track));
      expect(track, isNot(level(2).track));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state(tester).morphValue, 1);
      expect(
        (tester.widget<DecoratedBox>(_fill).decoration as BoxDecoration).color,
        const Color(0xFF14B8A6),
      );
    });

    testWidgets('reduced motion morphs in 200 ms', (tester) async {
      await pumpBar(
        tester,
        50,
        palette: level(4),
        morph: HypeTrainProgressBar.reducedMorph,
      );
      await pumpBar(
        tester,
        50,
        palette: level(5),
        morph: HypeTrainProgressBar.reducedMorph,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(state(tester).morphValue, 1);
    });

    testWidgets('publishes the drawn fill for the text', (tester) async {
      final edge = ValueNotifier<double>(-1);
      addTearDown(edge.dispose);
      await pumpBar(tester, 10, palette: level(4), edge: edge);
      expect(edge.value, closeTo(0.1, 1e-9));

      await pumpBar(tester, 60, palette: level(4), edge: edge);
      await tester.pump(const Duration(milliseconds: 100));
      expect(edge.value, state(tester).value);
      expect(edge.value, inExclusiveRange(0.1, 0.6));
    });

    testWidgets('level 6 and up flows across a repeating gradient', (
      tester,
    ) async {
      await pumpBar(tester, 50, palette: level(6));
      final gradient =
          (tester.widget<DecoratedBox>(_fill).decoration as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(gradient.tileMode, TileMode.repeated);
      expect(state(tester).sheenValue, 0);
      await tester.pump(HypeTrainProgressBar.sheenPeriod ~/ 2);
      expect(state(tester).sheenValue, closeTo(0.5, 0.01));
      final moved =
          (tester.widget<DecoratedBox>(_fill).decoration as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(moved.transform, isNotNull);
    });
  });
}
