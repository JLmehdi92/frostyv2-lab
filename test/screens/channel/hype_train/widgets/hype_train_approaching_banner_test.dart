import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_approaching_banner.dart';

import 'hype_train_widget_harness.dart';

HtApproachingEvent approaching(
  Map<int, int> deadlines, {
  Set<String> participants = const {},
  int goal = 3,
  int? creatorColor = 0xFFBD0078,
}) => HtApproachingEvent(
  HypeTrainApproaching(
    id: 'a',
    goal: goal,
    deadlines: deadlines,
    participants: participants,
    creatorColor: creatorColor,
  ),
);

final _pill = find.byKey(const ValueKey('ht-events-pill'));
final _bar = find.byKey(const ValueKey('ht-approaching-bar'));

Color pillColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_pill).decoration as BoxDecoration).color!;

int circles(WidgetTester tester) =>
    find.byKey(const ValueKey('ht-check-filled')).evaluate().length +
    find.byKey(const ValueKey('ht-check-empty')).evaluate().length;

Future<HtHarness> showing(
  WidgetTester tester,
  HtApproachingEvent event, {
  bool compact = false,
  double textScale = 1,
  double width = 360,
}) async {
  final h = HtHarness();
  await pumpSlot(
    tester,
    h.store,
    compact: compact,
    textScale: textScale,
    width: width,
  );
  h.inject(event);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return h;
}

int filledChecks(WidgetTester tester) => tester
    .widgetList<Icon>(find.byKey(const ValueKey('ht-check-filled')))
    .length;

void main() {
  testWidgets('checks, countdown bar and title', (tester) async {
    final h = HtHarness();
    await pumpSlot(tester, h.store);

    h.inject(approaching(const {1: 40, 2: 80}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(HypeTrainApproachingBanner), findsOneWidget);
    expect(find.text('A Hype Train is approaching!'), findsOneWidget);
    expect(filledChecks(tester), 2);
    final bar = find.byKey(const ValueKey('ht-approaching-bar'));
    final start = tester.widget<LinearProgressIndicator>(bar).value!;

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<LinearProgressIndicator>(bar).value,
      greaterThan(start),
    );

    await tester.pump(const Duration(seconds: 40));
    expect(filledChecks(tester), 1);
    await h.close(tester);
  });

  testWidgets('a viewer who took part reads "more"', (tester) async {
    final h = HtHarness(viewer: 'me');
    await pumpSlot(tester, h.store);

    h.inject(approaching(const {1: 40}, participants: const {'me'}));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('more'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('the bar is full when the train starts', (tester) async {
    final h = HtHarness();
    await pumpSlot(tester, h.store);
    h.inject(approaching(const {1: 40}));
    await tester.pump();
    await tester.pump();

    h.inject(HtStartEvent(liveTrain(level: 1, value: 0, total: 0)));
    expect(h.store.approachingCompleted, isTrue);
    await h.close(tester);
  });

  group('twitch layout', () {
    testWidgets('74 dp on the float card, title and subtitle', (tester) async {
      final h = await showing(tester, approaching(const {1: 40}));

      expect(
        tester.getSize(find.byType(HypeTrainApproachingBanner)).height,
        74,
      );
      final title = tester.widget<Text>(
        find.text('A Hype Train is approaching!'),
      );
      expect(title.style?.fontSize, 18);
      expect(title.maxLines, 2);
      final subtitle = tester.widget<Text>(
        find.text('Sub, gift, or use Bits now to start a Hype Train'),
      );
      expect(subtitle.style?.fontSize, 14);
      expect(subtitle.maxLines, 2);
      await h.close(tester);
    });

    testWidgets('the events pill is green without a creator colour', (
      tester,
    ) async {
      final h = await showing(
        tester,
        approaching(const {1: 40}, creatorColor: null),
      );

      expect(pillColor(tester), const Color(0xFF12A87A));
      final box =
          tester.widget<DecoratedBox>(_pill).decoration as BoxDecoration;
      expect(box.borderRadius, BorderRadius.circular(20));
      expect(
        find.descendant(of: _pill, matching: find.byIcon(Icons.train_rounded)),
        findsOneWidget,
      );
      await h.close(tester);
    });

    testWidgets("Twitch's purple turns green; other colours stay", (
      tester,
    ) async {
      var h = await showing(
        tester,
        approaching(const {1: 40}, creatorColor: 0xFF9147FF),
      );
      expect(pillColor(tester), const Color(0xFF12A87A));
      await h.close(tester);

      h = await showing(tester, approaching(const {1: 40}));
      expect(pillColor(tester), const Color(0xFFBD0078));
      await h.close(tester);
    });

    testWidgets('only the events pill takes the creator colour', (
      tester,
    ) async {
      Color? side(WidgetTester tester) => tester
          .widget<ColoredBox>(find.byKey(const ValueKey('ht-approaching-side')))
          .color;
      Color? bottom(WidgetTester tester) =>
          tester.widget<LinearProgressIndicator>(_bar).color;

      final h = await showing(tester, approaching(const {1: 40}));
      expect(pillColor(tester), const Color(0xFFBD0078));
      expect(side(tester), const Color(0xFF12A87A));
      expect(bottom(tester), const Color(0xFF12A87A));
      await h.close(tester);

      final d = HtHarness();
      await pumpSlot(tester, d.store, theme: ThemeData.dark());
      d.inject(approaching(const {1: 40}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(side(tester), const Color(0xFF12A87A));
      expect(bottom(tester), const Color(0xFF0C6D4F));
      await d.close(tester);
    });

    testWidgets('two circles up to a goal of 5, then three', (tester) async {
      var h = await showing(tester, approaching(const {1: 40}));
      expect(circles(tester), 2);
      await h.close(tester);

      h = await showing(tester, approaching(const {1: 40}, goal: 6));
      expect(circles(tester), 3);
      await h.close(tester);
    });

    testWidgets('a 3 dp bar at the bottom, full once the train starts', (
      tester,
    ) async {
      final h = await showing(tester, approaching(const {1: 40}));
      final banner = tester.getRect(find.byType(HypeTrainApproachingBanner));

      expect(tester.getSize(_bar).height, 3);
      expect(tester.getRect(_bar).bottom, banner.bottom);
      expect(
        tester.widget<LinearProgressIndicator>(_bar).backgroundColor,
        Colors.transparent,
      );

      h.inject(HtStartEvent(liveTrain(level: 1, value: 0, total: 0)));
      await tester.pump();
      expect(tester.widget<LinearProgressIndicator>(_bar).value, 1);
      await h.close(tester);
    });

    testWidgets('compact: no subtitle', (tester) async {
      final h = await showing(
        tester,
        approaching(const {1: 40}),
        compact: true,
      );

      expect(find.text('A Hype Train is approaching!'), findsOneWidget);
      expect(
        find.text('Sub, gift, or use Bits now to start a Hype Train'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });

    testWidgets('large text does not overflow', (tester) async {
      for (final width in [360.0, 280.0, 220.0]) {
        final h = await showing(
          tester,
          approaching(const {1: 40}, goal: 6),
          textScale: 2,
          width: width,
        );
        expect(tester.takeException(), isNull, reason: '$width');
        await h.close(tester);
      }
    });
  });
}
