import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_video_pill.dart';

import 'hype_train_widget_harness.dart';

Future<void> pumpPill(
  WidgetTester tester,
  HypeTrainStore store, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: HypeTrainVideoPill(store: store, onTap: onTap ?? () {}),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('hidden: nothing', (tester) async {
    final h = HtHarness();
    await pumpPill(tester, h.store);

    expect(find.byKey(const ValueKey('ht-video-pill')), findsNothing);
    await h.close(tester);
  });

  testWidgets('approaching, ongoing, levelling, ended', (tester) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(
        liveTrain(level: 2, expiresIn: const Duration(minutes: 5)),
        fetchedAt: DateTime.utc(2026),
      ),
    );
    await pumpPill(tester, h.store);
    expect(find.text('LVL 2'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(h.store.reduceMotion, isFalse);

    h.inject(htLevelUp(3));
    await tester.pump();
    // The compact plan is only the 2.5 s level pill.
    expect(find.text('Level 2 Complete!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('LVL 3'), findsOneWidget);

    h.inject(const HtEndEvent(reason: HtEndReason.completed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hype Train success!'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('approaching shows how many are left', (tester) async {
    final h = HtHarness();
    await pumpPill(tester, h.store);
    h.inject(
      HtApproachingEvent(
        HypeTrainApproaching(id: 'a', goal: 3, deadlines: const {2: 60}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Approaching'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('tap opens the details; one label for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpPill(tester, h.store, onTap: () => taps++);

    await tester.tap(find.byKey(const ValueKey('ht-video-pill')));
    expect(taps, 1);
    expect(
      find.bySemanticsLabel(RegExp('Hype Train level 7, 33 percent')),
      findsOneWidget,
    );
    await h.close(tester);
    semantics.dispose();
  });
}
