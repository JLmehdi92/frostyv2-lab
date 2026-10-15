import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_sheet.dart';
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

  testWidgets('tapping the banner opens and closes the details', (
    tester,
  ) async {
    var learnMore = 0;
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HypeTrainSlot(store: h.store, onLearnMore: () => learnMore++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Hype Train'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HypeTrainSheet), findsOneWidget);
    await tester.ensureVisible(find.text('More Info'));
    await tester.tap(find.text('More Info'));
    expect(learnMore, 1);

    await tester.tap(find.text('Hype Train'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HypeTrainSheet), findsNothing);
    await h.close(tester);
  });

  testWidgets('the banner and its details share one card', (tester) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);
    final card = find.byKey(const ValueKey('ht-card'));

    expect(
      find.ancestor(of: find.byType(HypeTrainBanner), matching: card),
      findsOneWidget,
    );
    final material = tester.widget<Material>(card);
    expect(material.elevation, 4);
    expect(material.color, const Color(0xFFFFFFFF));
    expect(material.borderRadius, BorderRadius.circular(6));

    h.store.toggleExpanded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.ancestor(of: find.byType(HypeTrainSheet), matching: card),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.byType(HypeTrainBanner), matching: card),
      findsOneWidget,
    );
    await h.close(tester);
  });

  testWidgets('opening the details keeps the banner alive', (tester) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);
    final banner = tester.state(find.byType(HypeTrainBanner));
    final bar = tester.state(find.byType(HypeTrainProgressBar));

    h.store.toggleExpanded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HypeTrainSheet), findsOneWidget);
    expect(tester.state(find.byType(HypeTrainBanner)), same(banner));
    expect(tester.state(find.byType(HypeTrainProgressBar)), same(bar));

    h.store.toggleExpanded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.state(find.byType(HypeTrainBanner)), same(banner));
    await h.close(tester);
  });

  testWidgets('collapsing cross-fades the banner into the pill', (
    tester,
  ) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
    );
    await pumpSlot(tester, h.store);

    h.store.setCollapsed(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HypeTrainBanner), findsOneWidget);
    expect(find.byType(HypeTrainPill), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HypeTrainBanner), findsNothing);
    expect(find.byType(HypeTrainPill), findsOneWidget);
    await h.close(tester);
  });
}
