import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_slot.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/community_highlights_harness.dart';

void main() {
  late Harness h;
  late List<OutgoingRaid> watched;
  late int opened;

  setUp(() {
    h = Harness();
    watched = [];
    opened = 0;
  });

  Future<void> start(WidgetTester tester, {PinnedChatMessage? pin}) async {
    if (pin != null) {
      when(() => h.service.getPinned(any())).thenAnswer((_) async => pin);
    }
    h.create();
    addTearDown(h.store.dispose);
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );

  HighlightSlot slot({bool compact = false}) => HighlightSlot(
    store: h.store,
    onWatchRaid: watched.add,
    compact: compact,
    onOpenDetails: () => opened++,
  );

  testWidgets('nothing up, nothing shown', (tester) async {
    await start(tester);
    await pump(tester, slot());
    expect(find.byType(HighlightPager), findsNothing);
    expect(tester.getSize(find.byType(HighlightSlot)).height, 0);
  });

  testWidgets('one card, then paging between two', (tester) async {
    await start(tester, pin: pinnedModel('pin'));
    await pump(tester, slot());
    expect(find.textContaining('Rules', findRichText: true), findsOneWidget);
    expect(find.byType(HighlightPager), findsNothing);

    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pumpAndSettle();
    expect(find.text('Which?'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Highlight 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next highlight'));
    await tester.pumpAndSettle();
    expect(h.store.current!.kind, HighlightKind.pinned);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.textContaining('Rules', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Previous highlight'));
    await tester.pumpAndSettle();
    expect(h.store.current!.kind, HighlightKind.poll);
  });

  testWidgets('a new one behind an expanded card shows a "New" pill', (
    tester,
  ) async {
    await start(tester);
    await pump(tester, slot());
    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pumpAndSettle();
    h.store.toggleExpanded();
    await tester.pump();

    h.send(HighlightTopic.pinned, pinPayload('pin'));
    await tester.pumpAndSettle();
    // The expanded poll keeps the slot.
    expect(h.store.current!.kind, HighlightKind.poll);
    expect(find.widgetWithText(ActionChip, 'New pinned'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'New pinned'));
    await tester.pumpAndSettle();
    expect(h.store.current!.kind, HighlightKind.pinned);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('compact keeps the card collapsed; a tap opens the details', (
    tester,
  ) async {
    await start(tester);
    await pump(tester, slot(compact: true));
    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pumpAndSettle();
    h.store.toggleExpanded();
    await tester.pumpAndSettle();
    // Collapsed: the question, not the choices.
    expect(find.text('Which?'), findsOneWidget);
    expect(find.text('C0'), findsNothing);

    await tester.tap(find.text('Which?'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('a raid Watch hands the target over', (tester) async {
    await start(tester);
    await pump(tester, slot());
    h.send(HighlightTopic.raid, raidPayload('raid_update_v2'));
    await tester.pumpAndSettle();
    h.store.toggleExpanded();
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Watch'));
    await tester.pump();
    expect(watched.single.targetLogin, 'friend');
  });

  testWidgets('the video pill names the kind and how many more', (
    tester,
  ) async {
    await start(tester, pin: pinnedModel('pin'));
    var taps = 0;
    await pump(
      tester,
      Center(
        child: HighlightVideoPill(store: h.store, onTap: () => taps++),
      ),
    );
    expect(find.text('Pinned'), findsOneWidget);

    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pumpAndSettle();
    expect(find.text('Poll +1'), findsOneWidget);
    expect(find.bySemanticsLabel('Poll and 1 more'), findsOneWidget);
    expect(tester.getSize(find.byType(InkWell)).height, 40);

    await tester.tap(find.text('Poll +1'));
    expect(taps, 1);
  });

  testWidgets('the details sheet shows the card expanded, then closes when '
      'nothing is up', (tester) async {
    await start(tester);
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showHighlightDetails(context, h.store, onWatchRaid: watched.add),
          child: const Text('open'),
        ),
      ),
    );
    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('C0'), findsOneWidget);
    // No dismiss in the sheet: closing the sheet is enough.
    expect(find.byTooltip('Dismiss'), findsNothing);

    h.send(
      HighlightTopic.polls,
      pollPayload('POLL_ARCHIVE', status: 'ARCHIVED'),
    );
    await tester.pumpAndSettle();
    expect(h.store.visible, isFalse);
    expect(find.text('C0'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('labels and icons cover every kind', (tester) async {
    for (final kind in HighlightKind.values) {
      expect(highlightLabel(kind), isNotEmpty);
      expect(highlightIcon(kind), isA<IconData>());
    }
  });
}
