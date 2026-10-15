import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_approaching_banner.dart';

import 'hype_train_widget_harness.dart';

HtApproachingEvent approaching(
  Map<int, int> deadlines, {
  Set<String> participants = const {},
}) => HtApproachingEvent(
  HypeTrainApproaching(
    id: 'a',
    goal: 3,
    deadlines: deadlines,
    participants: participants,
    creatorColor: 0xFFBD0078,
  ),
);

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
}
