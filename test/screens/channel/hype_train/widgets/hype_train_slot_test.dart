import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_slot.dart';

import 'hype_train_widget_harness.dart';

void main() {
  testWidgets('hidden takes no space', (tester) async {
    final h = HtHarness();
    await pumpSlot(tester, h.store);

    expect(tester.getSize(find.byType(HypeTrainSlot)).height, 0);
    await h.close(tester);
  });

  testWidgets('a mounted slot is a presenter; unmounting detaches it', (
    tester,
  ) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(8));
    await tester.pump();
    expect(h.store.step?.kind, HtStepKind.fillTo, reason: 'animated');

    await tester.pumpWidget(const SizedBox());
    expect(h.store.step, isNull, reason: 'finished at once when detached');
    expect(h.store.shownLevel, 8);
    h.store.dispose();
    await tester.pump();
  });

  testWidgets('the slot grows when a train appears', (tester) async {
    final h = HtHarness();
    await pumpSlot(tester, h.store);

    h.inject(HtStartEvent(liveTrain(level: 1, value: 0, total: 0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final growing = tester.getSize(find.byType(HypeTrainSlot)).height;
    await tester.pump(const Duration(milliseconds: 600));
    final grown = tester.getSize(find.byType(HypeTrainSlot)).height;

    expect(growing, lessThan(grown));
    expect(grown, greaterThan(40));
    await h.close(tester);
  });

  testWidgets('a store-level end of a hidden slot keeps nothing on screen', (
    tester,
  ) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);
    h.inject(const HtEndEvent(reason: HtEndReason.expired));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getSize(find.byType(HypeTrainSlot)).height, 0);
    expect(h.store.train, isNull);
    expect(HtVariant.values, isNotEmpty);
    await h.close(tester);
  });
}
