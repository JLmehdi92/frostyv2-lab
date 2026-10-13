import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_channel_overlays.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_video_pill.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';

import 'hype_train_widget_harness.dart';

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
          HypeTrainVideoOverlay(store: h.store, settingsStore: settings),
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
                HypeTrainChatOverlay(
                  store: h.store,
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
        find.bySemanticsLabel(RegExp('Hype Train approaching')),
      ),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    expect(h.store.phase, HtPhase.approaching);
    await h.close(tester);
    semantics.dispose();
  });
}
