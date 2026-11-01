import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/hype_train_event.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_split_color.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_video_pill.dart';

import '../hype_train_test_data.dart';
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
    expect(find.text('Level 2 complete!'), findsOneWidget);
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
    final pill = find.byKey(const ValueKey('ht-video-pill'));
    int circles(String key) => find
        .descendant(of: pill, matching: find.byKey(ValueKey(key)))
        .evaluate()
        .length;
    expect(circles('ht-check-filled') + circles('ht-check-empty'), 2);
    await h.close(tester);
  });

  testWidgets('the landscape pill fills the third circle too', (tester) async {
    final h = HtHarness();
    await pumpPill(tester, h.store);
    h.inject(
      HtApproachingEvent(
        HypeTrainApproaching(
          id: 'a',
          goal: 6,
          deadlines: const {1: 40, 2: 80, 3: 120},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('ht-check-filled')), findsNWidgets(3));
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

  group('twitch landscape pill', () {
    final pill = find.byKey(const ValueKey('ht-video-pill'));
    final fill = find.byKey(const ValueKey('ht-pill-fill'));

    testWidgets(
      '32 dp, radius 16, on translucent black, white text',
      (tester) async {
        final h = HtHarness(
          snapshot: HtOngoingSnapshot(
            liveTrain(),
            fetchedAt: DateTime.utc(2026),
          ),
        );
        await pumpPill(tester, h.store);

        expect(tester.getSize(pill).height, 32);
        final shape =
            tester.widget<DecoratedBox>(pill).decoration as BoxDecoration;
        expect(shape.color, const Color(0x80000000));
        expect(shape.borderRadius, BorderRadius.circular(16));
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('LVL 7'))
              .text
              .style
              ?.color,
          Colors.white,
        );
        await h.close(tester);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('the fill sweeps the level fraction in its level colour', (
      tester,
    ) async {
      final h = HtHarness(
        snapshot: HtOngoingSnapshot(
          liveTrain(level: 4),
          fetchedAt: DateTime.utc(2026),
        ),
      );
      await pumpPill(tester, h.store);

      expect(
        tester.getSize(fill).width,
        closeTo(tester.getSize(pill).width * 0.33, 0.5),
      );
      expect(tester.getSize(fill).height, 32);
      expect(
        (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration)
            .gradient!
            .colors,
        const [Color(0xFFC8FF3D), Color(0xFFC8FF3D)],
      );
      // Dark on the lime, white over the video: the text turns at the edge.
      final split = tester.renderObject<RenderHtSplitColor>(
        find.byType(HtSplitColor),
      );
      expect(split.onFill, const Color(0xFF0A0A0A));
      expect(split.onTrack, Colors.white);
      await h.close(tester);
    });

    testWidgets('a shared train fills the pill in its level colours', (
      tester,
    ) async {
      final h = HtHarness(
        snapshot: HtOngoingSnapshot(
          liveTrain(
            shared: HtShared(
              id: 's',
              channels: [
                HtSharedChannel(user: user('a')),
                HtSharedChannel(user: user('b')),
              ],
            ),
          ),
          fetchedAt: DateTime.utc(2026),
        ),
      );
      await pumpPill(tester, h.store);

      final decoration =
          tester.widget<DecoratedBox>(fill).decoration as BoxDecoration;
      expect(decoration.color, isNull);
      // Level 7: the lime and orange of level 6 and up.
      expect(decoration.gradient!.colors, const [
        Color(0xFFC8FF3D),
        Color(0xFFFF7A45),
        Color(0xFFC8FF3D),
      ]);
      await h.close(tester);
    });

    testWidgets('a 48 dp touch target', (tester) async {
      var taps = 0;
      final h = HtHarness(
        snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
      );
      await pumpPill(tester, h.store, onTap: () => taps++);

      final target = find.byKey(const ValueKey('ht-video-pill-target'));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      // Just above the visible pill still taps it.
      await tester.tapAt(tester.getTopLeft(pill) + const Offset(20, -6));
      expect(taps, 1);
      await h.close(tester);
    });

    testWidgets('large text stays in the pill', (tester) async {
      final h = HtHarness(
        snapshot: HtOngoingSnapshot(liveTrain(), fetchedAt: DateTime.utc(2026)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: HypeTrainVideoPill(store: h.store, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(pill).height, 32);
      await h.close(tester);
    });
  });
}
