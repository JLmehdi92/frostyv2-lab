import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/hype_train_event.dart';
import 'package:onset/screens/channel/channel_top_overlays.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/community_highlights/widgets/gift_bomb_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_slot.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_video_pill.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../helpers/community_highlights_harness.dart' as ch;
import 'hype_train/widgets/hype_train_widget_harness.dart';

class MockChatTabsStore extends Mock implements ChatTabsStore {}

HtHarness running() => HtHarness(
  snapshot: HtOngoingSnapshot(
    liveTrain(expiresIn: const Duration(minutes: 5)),
    fetchedAt: DateTime.utc(2026),
  ),
);

void main() {
  late SettingsStore settings;
  late MockChatTabsStore tabs;

  setUp(() {
    settings = SettingsStore.fromJson({});
    tabs = MockChatTabsStore();
    when(() => tabs.showTabBar).thenReturn(false);
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('landscape full screen with hidden chat: the pill on video', (
    tester,
  ) async {
    settings
      ..fullScreen = true
      ..fullScreenChatOverlay = false;
    final h = running();
    await pumpAt(
      tester,
      const Size(800, 360),
      Stack(
        children: [
          const SizedBox.expand(),
          ChannelVideoTopOverlay(hypeTrain: h.store, settingsStore: settings),
        ],
      ),
    );

    expect(find.byType(HypeTrainVideoPill), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('the compact banner fits a 140 px landscape chat', (
    tester,
  ) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(
        liveTrain(level: 2, expiresIn: const Duration(minutes: 5)),
        fetchedAt: DateTime.utc(2026),
      ),
    );
    await pumpAt(
      tester,
      const Size(800, 360),
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 140,
          child: HypeTrainSlot(
            store: h.store,
            compact: true,
            onLearnMore: () {},
          ),
        ),
      ),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    h.inject(htLevelUp(3));
    for (var t = 0; t < 40; t++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'at ${t * 100} ms');
    }

    h.store.setCollapsed(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: 'collapsed pill');
    await h.close(tester);
  });

  testWidgets('the details never reach the chat input; typing closes them', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final h = running();
    await pumpAt(
      tester,
      const Size(360, 740),
      Column(
        children: [
          const SizedBox(height: 300),
          SizedBox(
            height: 213,
            child: Stack(
              children: [
                const SizedBox.expand(),
                ChannelChatTopOverlay(
                  hypeTrain: h.store,
                  settingsStore: settings,
                  chatTabsStore: tabs,
                  chatInputFocus: focus,
                  bottomBarHeight: 56,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 56,
                    child: TextField(focusNode: focus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    h.store.toggleExpanded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final slotBottom = tester.getBottomLeft(find.byType(HypeTrainSlot)).dy;
    expect(slotBottom, lessThanOrEqualTo(300 + 213 - 56));

    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.store.expanded, isFalse);
    expect(find.byType(HypeTrainSheet), findsNothing);
    await h.close(tester);
  });

  testWidgets('with large text the banner and details still fit above the '
      'chat input', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final h = running();
    await pumpAt(
      tester,
      const Size(360, 740),
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 400,
          child: ChannelChatTopOverlay(
            hypeTrain: h.store,
            settingsStore: settings,
            chatTabsStore: tabs,
            chatInputFocus: focus,
            bottomBarHeight: 56,
          ),
        ),
      ),
      textScale: 2,
    );

    h.store.toggleExpanded();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(HypeTrainSheet), findsOneWidget);
    // The banner (148 dp at twice the text) and its details, unscrolled.
    expect(
      tester.getSize(find.byType(HypeTrainSlot)).height,
      lessThanOrEqualTo(400 - 6 - 56 - 8),
    );
    await h.close(tester);
  });

  testWidgets('a landscape phone chat gets the compact banner', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final h = running();
    await pumpAt(
      tester,
      const Size(800, 360),
      Align(
        alignment: Alignment.topRight,
        child: SizedBox(
          width: 300,
          height: 360,
          child: ChannelChatTopOverlay(
            hypeTrain: h.store,
            settingsStore: settings,
            chatTabsStore: tabs,
            chatInputFocus: focus,
            bottomBarHeight: 56,
          ),
        ),
      ),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(HypeTrainBanner), findsOneWidget);
    expect(find.byKey(const ValueKey('ht-title')), findsNothing);
    // Its natural height, under the full banner's 74 dp × 1.3.
    expect(
      tester.getSize(find.byKey(const ValueKey('ht-banner'))).height,
      lessThan(74 * 1.3),
    );
    await h.close(tester);
  });

  testWidgets('the modal details close when the train is gone', (tester) async {
    final h = running();
    late BuildContext context;
    await pumpAt(
      tester,
      const Size(800, 360),
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.expand();
        },
      ),
    );

    showHypeTrainDetails(context, h.store, settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HypeTrainSheet), findsOneWidget);
    // The sheet on the community green.
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      htSheetBackground(Theme.of(context).brightness),
    );

    h.inject(const HtEndEvent(reason: HtEndReason.expired));
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HypeTrainSheet), findsNothing);
    await h.close(tester);
  });

  testWidgets('the countdown does not rebuild the banner', (tester) async {
    final h = running();
    await pumpSlot(tester, h.store);
    final pill = tester.widget(find.byType(HypeTrainLevelPill));
    final banner = tester.widget(find.byType(HypeTrainBanner));

    await tester.pump(const Duration(seconds: 2));

    expect(
      identical(tester.widget(find.byType(HypeTrainLevelPill)), pill),
      isTrue,
    );
    expect(
      identical(tester.widget(find.byType(HypeTrainBanner)), banner),
      isTrue,
    );
    await h.close(tester);
  });

  testWidgets('the approaching banner is a button for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = HtHarness();
    await pumpSlot(tester, h.store);
    h.inject(
      HtApproachingEvent(
        HypeTrainApproaching(id: 'a', goal: 3, deadlines: const {1: 60}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(RegExp('A Hype Train is approaching!')),
      ),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    expect(h.store.phase, HtPhase.approaching);
    await h.close(tester);
    semantics.dispose();
  });

  group('large screens', () {
    Future<(HtHarness, HypeTrainSlot)> slotInChat(
      WidgetTester tester,
      double width,
    ) async {
      final h = running();
      await pumpAt(
        tester,
        const Size(1600, 1067),
        Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: width,
            height: 1000,
            child: Stack(
              children: [
                const SizedBox.expand(),
                ChannelChatTopOverlay(
                  hypeTrain: h.store,
                  settingsStore: settings,
                  chatTabsStore: tabs,
                  chatInputFocus: FocusNode(),
                  bottomBarHeight: 56,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return (h, tester.widget<HypeTrainSlot>(find.byType(HypeTrainSlot)));
    }

    testWidgets('the 320 dp side chat keeps the compact banner', (
      tester,
    ) async {
      final (h, slot) = await slotInChat(tester, 320);
      expect(slot.compact, isTrue);
      await h.close(tester);
    });

    testWidgets('a wide chat gets the full banner, at most 560 dp', (
      tester,
    ) async {
      final (h, slot) = await slotInChat(tester, 800);
      expect(slot.compact, isFalse);
      expect(
        tester.getSize(find.byType(HypeTrainSlot)).width,
        lessThanOrEqualTo(560),
      );
      await h.close(tester);
    });
  });

  group('community highlights', () {
    late ch.Harness hl;

    setUp(() => hl = ch.Harness());

    Future<void> start(WidgetTester tester, {bool expandNew = false}) async {
      hl.create(expandNew: expandNew);
      addTearDown(hl.store.dispose);
      hl.send(HighlightTopic.polls, ch.pollPayload('POLL_CREATE'));
      await tester.pump();
    }

    Widget chat({
      HtHarness? train,
      double width = 360,
      double height = 420,
      FocusNode? focus,
    }) => Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            const SizedBox.expand(),
            ChannelChatTopOverlay(
              hypeTrain: train?.store,
              highlights: hl.store,
              settingsStore: settings,
              chatTabsStore: tabs,
              chatInputFocus: focus,
              bottomBarHeight: 56,
            ),
          ],
        ),
      ),
    );

    HighlightSlot slot(WidgetTester tester) =>
        tester.widget<HighlightSlot>(find.byType(HighlightSlot));

    testWidgets('alone on a phone: the card, tap to expand', (tester) async {
      await start(tester);
      await pumpAt(tester, const Size(360, 740), chat());
      expect(slot(tester).compact, isFalse);
      expect(find.text('Which?'), findsOneWidget);
    });

    testWidgets('under a running train on a phone it stays one line', (
      tester,
    ) async {
      await start(tester);
      final train = running();
      await pumpAt(tester, const Size(360, 740), chat(train: train));
      expect(find.byType(HypeTrainSlot), findsOneWidget);
      expect(slot(tester).compact, isTrue);
      expect(
        tester.getTopLeft(find.byType(HighlightSlot)).dy,
        greaterThan(tester.getBottomLeft(find.byType(HypeTrainSlot)).dy),
      );

      // The train details take the room; the highlight comes back after.
      train.store.toggleExpanded();
      await tester.pump();
      expect(find.byType(HighlightSlot), findsNothing);
      train.store.toggleExpanded();
      await tester.pump();
      expect(find.byType(HighlightSlot), findsOneWidget);
      await train.close(tester);
    });

    testWidgets('a gift bomb stays up while the train details are open', (
      tester,
    ) async {
      hl.create();
      hl.store.showGiftBomb(
        const GiftBomb(
          key: 'bomb',
          gifterName: 'BigGifter',
          isAnonymous: false,
          count: 20,
          tier: 'Tier 1',
        ),
      );
      await tester.pump();
      final train = running();
      await pumpAt(tester, const Size(360, 740), chat(train: train));
      expect(find.byType(HighlightSlot), findsOneWidget);

      // Unlike a poll, a gift bomb is over in seconds: hiding it behind the
      // details would mean never seeing it.
      train.store.toggleExpanded();
      await tester.pump();
      expect(find.byType(HighlightSlot), findsOneWidget);
      // Disposed in the test body: its banner deadline is a timer the test
      // binding checks before tear-down runs.
      hl.store.dispose();
      await train.close(tester);
    });

    group('the gift bomb pin in each chat', () {
      // (view, chat column, one line?): a phone in portrait, the landscape
      // side chats, a tablet's side column and its portrait.
      for (final (name, view, column, oneLine) in [
        ('phone portrait 390x844', const Size(390, 844), 390.0, false),
        ('landscape side chat 256', const Size(844, 390), 256.0, true),
        ('landscape side chat 320', const Size(844, 390), 320.0, true),
        ('tablet landscape 1280x854', const Size(1280, 854), 280.0, true),
        ('tablet portrait 854x1280', const Size(854, 1280), 854.0, false),
        ('tablet wide chat 600', const Size(1280, 854), 600.0, false),
      ]) {
        testWidgets(name, (tester) async {
          hl.create();
          final live = ValueNotifier(
            const GiftBomb(
              key: 'bomb',
              gifterName: 'saladetomateoignons0saladetomateoignons0',
              isAnonymous: false,
              count: 20,
            ),
          );
          addTearDown(live.dispose);
          hl.store.showGiftBomb(live.value, live: live);
          await tester.pump();
          await pumpAt(
            tester,
            view,
            chat(width: column, height: view.height - 200),
          );
          await tester.pump(const Duration(milliseconds: 300));
          for (var i = 0; i < 20; i++) {
            live.value = live.value.withGift('r$i');
            await tester.pump(const Duration(milliseconds: 90));
          }
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(GiftBombPin), findsOneWidget);
          expect(find.text('×20'), oneLine ? findsOneWidget : findsNothing);
          expect(
            find.text(' is gifting 20 subs'),
            oneLine ? findsNothing : findsOneWidget,
          );
          final pin = tester.getRect(find.byKey(GiftBombPin.pinKey));
          expect(pin.height, oneLine ? 44 : 56);
          expect(pin.width, lessThanOrEqualTo(560));
          expect(tester.takeException(), isNull);
          hl.store.dispose();
        });
      }
    });

    testWidgets('an incoming raid stays up while the train details are '
        'open', (tester) async {
      hl.create();
      hl.store.showIncomingRaid(
        const IncomingRaid(raiderName: 'Raider', viewers: 15),
      );
      await tester.pump();
      final train = running();
      await pumpAt(tester, const Size(360, 740), chat(train: train));
      train.store.toggleExpanded();
      await tester.pump();
      expect(find.byType(HighlightSlot), findsOneWidget);
      hl.store.dispose();
      await train.close(tester);
    });

    testWidgets('a wide tablet chat shows it expanded under the train', (
      tester,
    ) async {
      await start(tester, expandNew: true);
      final train = running();
      await pumpAt(
        tester,
        const Size(1600, 1067),
        chat(train: train, width: 800, height: 1000),
      );
      expect(slot(tester).compact, isFalse);
      expect(find.text('C0'), findsOneWidget);
      expect(
        tester.getSize(find.byType(HighlightSlot)).width,
        lessThanOrEqualTo(560),
      );
      await train.close(tester);
    });

    testWidgets('never past the chat input, even expanded in a short chat', (
      tester,
    ) async {
      hl.create(expandNew: true);
      addTearDown(hl.store.dispose);
      hl.send(
        HighlightTopic.polls,
        ch.pollPayload('POLL_CREATE', votes: [1, 2, 3, 4, 5]),
      );
      await tester.pump();
      await pumpAt(
        tester,
        const Size(1600, 1067),
        Column(
          children: [
            const SizedBox(height: 300),
            chat(width: 800, height: 260),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      // The card scrolls inside what is left above the input.
      final box = find.ancestor(
        of: find.byType(HighlightSlot),
        matching: find.byType(SingleChildScrollView),
      );
      final bottom = tester.getBottomLeft(box).dy;
      expect(bottom, lessThanOrEqualTo(300 + 260 - 56));
    });

    testWidgets('a very short chat scrolls the tiers instead of overflowing', (
      tester,
    ) async {
      when(() => tabs.showTabBar).thenReturn(true);
      await start(tester);
      final train = running();
      for (final height in [130.0, 160.0]) {
        await pumpAt(
          tester,
          const Size(360, 740),
          chat(train: train, height: height),
        );
        expect(tester.takeException(), isNull, reason: '$height dp');
      }
      await train.close(tester);
    });

    testWidgets('hidden chat: both pills over the video, train first', (
      tester,
    ) async {
      settings
        ..fullScreen = true
        ..fullScreenChatOverlay = false;
      await start(tester);
      final train = running();
      await pumpAt(
        tester,
        const Size(800, 360),
        Stack(
          children: [
            const SizedBox.expand(),
            ChannelVideoTopOverlay(
              hypeTrain: train.store,
              highlights: hl.store,
              settingsStore: settings,
            ),
          ],
        ),
      );
      expect(find.byType(HypeTrainVideoPill), findsOneWidget);
      expect(find.byType(HighlightVideoPill), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(HighlightVideoPill)).dy,
        greaterThan(tester.getBottomLeft(find.byType(HypeTrainVideoPill)).dy),
      );
      await train.close(tester);
    });

    testWidgets('only the highlight pill without a train', (tester) async {
      settings
        ..fullScreen = true
        ..fullScreenChatOverlay = false;
      await start(tester);
      await pumpAt(
        tester,
        const Size(800, 360),
        Stack(
          children: [
            const SizedBox.expand(),
            ChannelVideoTopOverlay(
              highlights: hl.store,
              settingsStore: settings,
            ),
          ],
        ),
      );
      expect(find.byType(HighlightVideoPill), findsOneWidget);
      expect(tester.getTopLeft(find.byType(HighlightVideoPill)).dy, 56);
    });

    testWidgets('nothing with the landscape keyboard on a phone', (
      tester,
    ) async {
      await start(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await pumpAt(tester, const Size(800, 360), chat(height: 300));
      expect(find.byType(HighlightSlot), findsNothing);
    });
  });
}
