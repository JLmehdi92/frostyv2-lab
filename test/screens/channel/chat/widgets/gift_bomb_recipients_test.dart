import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/widgets/gift_bomb_recipients.dart';
import 'package:onset/theme.dart';

import '../../../../helpers/semantics_audit.dart';

GiftBomb _bomb({int count = 5}) => GiftBomb(
  key: 'bomb',
  gifterName: 'qqalex',
  isAnonymous: false,
  count: count,
  collapsed: true,
);

void main() {
  late ValueNotifier<GiftBomb> live;
  late List<bool> changes;

  setUp(() {
    live = ValueNotifier(_bomb());
    changes = [];
  });

  tearDown(() => live.dispose());

  Future<void> pump(
    WidgetTester tester, {
    bool expanded = false,
    bool reduceMotion = false,
    Brightness brightness = Brightness.dark,
    double width = 390,
    TextDirection direction = TextDirection.ltr,
  }) {
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? themes.dark : themes.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Directionality(
                    textDirection: direction,
                    child: GiftBombRecipients(
                      live: live,
                      initiallyExpanded: expanded,
                      onExpandedChanged: changes.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void give(int n) {
    for (var i = 0; i < n; i++) {
      live.value = live.value.withGift('viewer_${live.value.received}');
    }
  }

  testWidgets('counts the recipients as they arrive', (tester) async {
    await pump(tester);
    expect(find.text('0 of 5 recipients'), findsOneWidget);

    give(3);
    await tester.pump();
    expect(find.text('3 of 5 recipients'), findsOneWidget);

    give(2);
    await tester.pump();
    expect(find.text('5 recipients'), findsOneWidget);
  });

  testWidgets('a 28 dp pill in a 44 dp target, in the signal colour', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.getSize(find.byKey(GiftBombRecipients.toggleKey)).height, 44);
    final text = tester.widget<Text>(find.text('0 of 5 recipients'));
    expect(text.style?.color, OnsetTokens.accent);
  });

  for (final direction in TextDirection.values) {
    testWidgets('the target reaches into the row padding (${direction.name})', (
      tester,
    ) async {
      await pump(tester, direction: direction);

      final row = tester.getRect(find.byType(GiftBombRecipients));
      final target = tester.getRect(find.byKey(GiftBombRecipients.toggleKey));
      if (direction == TextDirection.ltr) {
        expect(target.left, row.left - 8);
      } else {
        expect(target.right, row.right + 8);
      }
    });
  }

  testWidgets('the light theme uses the readable dark lime', (tester) async {
    await pump(tester, brightness: Brightness.light);

    final text = tester.widget<Text>(find.text('0 of 5 recipients'));
    expect(text.style?.color, OnsetColors.light.subNoticeText);
  });

  testWidgets('opens inline in 220 ms and closes again', (tester) async {
    give(5);
    await pump(tester);
    final closed = tester.getSize(find.byType(GiftBombRecipients)).height;
    expect(find.text('viewer_0'), findsNothing);

    await tester.tap(find.byKey(GiftBombRecipients.toggleKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final halfway = tester.getSize(find.byType(GiftBombRecipients)).height;
    expect(halfway, greaterThan(closed));
    await tester.pump(const Duration(milliseconds: 110));
    final open = tester.getSize(find.byType(GiftBombRecipients)).height;
    expect(open, greaterThan(halfway));
    for (var i = 0; i < 5; i++) {
      expect(find.text('viewer_$i'), findsOneWidget);
    }
    expect(changes, [true]);

    await tester.tap(find.byKey(GiftBombRecipients.toggleKey));
    await tester.pumpAndSettle();
    expect(find.text('viewer_0'), findsNothing);
    expect(tester.getSize(find.byType(GiftBombRecipients)).height, closed);
    expect(changes, [true, false]);
  });

  testWidgets('reduce motion opens at once', (tester) async {
    give(5);
    await pump(tester, reduceMotion: true);

    await tester.tap(find.byKey(GiftBombRecipients.toggleKey));
    await tester.pump();
    expect(find.text('viewer_4'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('starts open when the chat kept it open', (tester) async {
    give(2);
    await pump(tester, expanded: true);

    expect(find.text('viewer_1'), findsOneWidget);
  });

  testWidgets('names past the kept ones show as "+N more"', (tester) async {
    live.value = _bomb(count: 1000);
    give(GiftBombTracker.maxRecipients + 30);
    await pump(tester, expanded: true);
    await tester.pump();

    expect(find.text('+30 more'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers get one button that opens and says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    give(5);
    await pump(tester);

    expect(
      tester.getSemantics(find.byKey(GiftBombRecipients.toggleKey)),
      matchesSemantics(
        label: '5 recipients',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
      ),
    );
    expectNoSilentButtons(tester, reason: 'gift bomb recipients');
    handle.dispose();
  });

  for (final width in [256.0, 320.0]) {
    testWidgets('fits a ${width.toInt()} dp chat', (tester) async {
      give(5);
      await pump(tester, expanded: true, width: width);
      expect(tester.takeException(), isNull);
    });
  }
}
