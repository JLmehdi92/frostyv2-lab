import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';

import 'hype_train_widget_harness.dart';

final _clip = find.byKey(const ValueKey('ht-fill-clip'));
final _fill = find.byKey(const ValueKey('ht-fill'));

Future<void> pumpBar(
  WidgetTester tester,
  int percent, {
  HtPalette? palette,
  Duration duration = const Duration(milliseconds: 200),
  TextDirection direction = TextDirection.ltr,
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
}
