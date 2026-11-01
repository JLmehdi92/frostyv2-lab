import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/widgets/gift_bomb_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_slot.dart';
import 'package:onset/screens/channel/community_highlights/widgets/incoming_raid_pin.dart';

import '../../../../helpers/community_highlights_harness.dart';
import '../../../../helpers/live_curves.dart';

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

  testWidgets('a shown card follows its updates (votes, then results)', (
    tester,
  ) async {
    await start(tester);
    await pump(tester, slot());
    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE', votes: [1, 3]));
    await tester.pumpAndSettle();
    h.store.toggleExpanded();
    await tester.pumpAndSettle();
    expect(find.textContaining('75%'), findsOneWidget);

    h.send(HighlightTopic.polls, pollPayload('POLL_UPDATE', votes: [9, 1]));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('90%'), findsOneWidget);
    expect(find.textContaining('75%'), findsNothing);

    h.send(
      HighlightTopic.polls,
      pollPayload(
        'POLL_COMPLETE',
        status: 'COMPLETED',
        votes: [9, 1],
        endedAt: clock.now(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Final results'), findsOneWidget);
    h.store.dispose();
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
    expect(find.widgetWithText(HighlightNewPill, 'New pinned'), findsOneWidget);
    // The 30 dp signal pill.
    expect(
      tester
          .getSize(find.widgetWithText(HighlightNewPill, 'New pinned'))
          .height,
      30,
    );

    await tester.tap(find.widgetWithText(HighlightNewPill, 'New pinned'));
    await tester.pumpAndSettle();
    expect(h.store.current!.kind, HighlightKind.pinned);
    expect(find.byType(HighlightNewPill), findsNothing);
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
    h.send(
      HighlightTopic.raid,
      raidPayload('raid_update_v2', createdAt: clock.now()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go now'));
    await tester.pump();
    expect(watched.single.targetLogin, 'friend');
    h.store.dispose();
  });

  testWidgets('an incoming raid pins over the poll, then gives it back', (
    tester,
  ) async {
    await start(tester);
    await pump(tester, slot());
    h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
    await tester.pumpAndSettle();

    h.store.showIncomingRaid(
      const IncomingRaid(raiderName: 'Raider', viewers: 15),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IncomingRaidPin), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingRaidPin), findsNothing);
    expect(find.text('Which?'), findsOneWidget);

    // Another one leaves by itself.
    h.store.showIncomingRaid(
      const IncomingRaid(raiderName: 'Other', viewers: 3),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IncomingRaidPin), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 6600));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingRaidPin), findsNothing);
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
      expect(highlightLabel(kind, L10n.english), isNotEmpty);
      expect(highlightIcon(kind), isA<IconData>());
    }
  });

  testWidgets('a gift bomb shows its banner card', (tester) async {
    await start(tester);
    await pump(tester, slot());

    h.store.showGiftBomb(
      const GiftBomb(
        key: 'bomb',
        gifterName: 'BigGifter',
        isAnonymous: false,
        count: 5,
        tier: 'Tier 1',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GiftBombPin), findsOneWidget);
    expect(find.text('BigGifter'), findsOneWidget);
    expect(find.text(' is gifting 5 subs'), findsOneWidget);
    expect(highlightLabel(HighlightKind.giftBomb, L10n.english), 'Gift Subs');
    expect(highlightIcon(HighlightKind.giftBomb), Icons.card_giftcard_rounded);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();
    // It folds away first (280 ms), then leaves the stack.
    expect(h.store.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.store.giftBomb, isNotNull);
    expect(h.store.visible, isFalse);

    // It leaves the store at its end.
    await tester.pump(const Duration(seconds: 10));
    expect(h.store.giftBomb, isNull);
  });

  testWidgets('a gift bomb follows its gifts and goes one line when '
      'compact', (tester) async {
    await start(tester);
    await pump(tester, slot(compact: true));

    final live = ValueNotifier(
      const GiftBomb(
        key: 'bomb',
        gifterName: 'BigGifter',
        isAnonymous: false,
        count: 5,
      ),
    );
    addTearDown(live.dispose);
    h.store.showGiftBomb(live.value, live: live);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('×5'), findsOneWidget);
    live.value = live.value.withGift('a').withGift('b').withGift('c');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final ring = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(GiftBombPin.ringKey),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((ring.painter! as GiftBombRingPainter).fraction, closeTo(0.6, 1e-9));
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('the New pill keeps one curve however often it rebuilds', (
    tester,
  ) async {
    final curves = LiveCurves.track();
    Widget pill() => MaterialApp(
      home: Center(
        child: HighlightNewPill(kind: HighlightKind.pinned, onPressed: () {}),
      ),
    );
    await tester.pumpWidget(pill());
    await tester.pumpAndSettle();
    final settled = curves.count;
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(pill());
    }
    expect(curves.count, settled);
    await tester.pumpWidget(const SizedBox());
    expect(curves.count, 0);
  });
}
