import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_countdown.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_level_pill.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_progress_bar.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_split_color.dart';

import '../../../../helpers/l10n.dart' show ellipsizedTexts;
import 'hype_train_widget_harness.dart';

const _step = 'ht-step-';

final _banner = find.byKey(const ValueKey('ht-banner'));

Finder stepKey(String kind) => find.byKey(ValueKey('$_step$kind'));

double marqueeX(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('ht-marquee')),
  );
  return transform.transform.getTranslation().x;
}

void main() {
  HtHarness running(WidgetTester tester, {int level = 7}) => HtHarness(
    snapshot: HtOngoingSnapshot(
      liveTrain(level: level),
      fetchedAt: DateTime.utc(2026),
    ),
  );

  testWidgets('shows level, percent and the countdown', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    expect(find.byType(HypeTrainBanner), findsOneWidget);
    expect(find.text('LVL 7'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('0:16'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:15'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a progression fills the bar in 200 ms', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);
    final bar = tester.state<HypeTrainProgressBarState>(
      find.byType(HypeTrainProgressBar),
    );
    expect(bar.value, closeTo(0.33, 0.01));

    h.inject(htSmall(16500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bar.value, closeTo(0.43, 0.01));
    expect(find.text('43%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a large contribution takes over, then the train is back', (
    tester,
  ) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    h.inject(htSmall(16500, isLarge: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(stepKey('largeContribution'), findsOneWidget);
    expect(find.textContaining('Viewer_1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 5000));
    expect(stepKey('largeContribution'), findsOneWidget);

    // The step ends at 6500 ms; the cross-fade starts on the next frame.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stepKey('largeContribution'), findsNothing);
    expect(find.text('43%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('a level-up plays flash, marquee, level complete', (
    tester,
  ) async {
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(stepKey('flash100'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('LVL 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 550));
    expect(stepKey('marquee'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    final early = marqueeX(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(marqueeX(tester), lessThan(early));

    await tester.pump(const Duration(milliseconds: 800));
    expect(stepKey('levelComplete'), findsOneWidget);
    expect(find.text('Level 2 Complete!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('LVL 3'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('the marquee runs the other way in RTL', (tester) async {
    Future<double> firstX(TextDirection direction) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, direction: direction);
      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final x = marqueeX(tester);
      await h.close(tester);
      return x;
    }

    expect(await firstX(TextDirection.ltr), greaterThan(0));
    expect(await firstX(TextDirection.rtl), lessThan(0));
  });

  testWidgets('reduced motion: the marquee text stands still', (tester) async {
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store, reduceMotion: true);
    expect(h.store.reduceMotion, isTrue);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(stepKey('marquee'), findsOneWidget);
    expect(find.byKey(const ValueKey('ht-marquee')), findsNothing);
    expect(find.textContaining(HtCopy(L10n.english).levelUp), findsWidgets);
    await h.close(tester);
  });

  testWidgets('semantics: one label, live step text, no countdown node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = running(tester, level: 2);
    await pumpSlot(tester, h.store);

    expect(
      find.bySemanticsLabel(RegExp(r'level 2, 33 percent, .* left')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('0:16'), findsNothing);

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3300));
    // Past the first frame of the cross-fade (opacity 0 hides semantics).
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getSemantics(find.text('Level 2 Complete!')),
      containsSemantics(isLiveRegion: true),
    );

    await h.close(tester);
    semantics.dispose();
  });

  testWidgets('collapses to a pill and expands back', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store);

    // Swipe up: there is no collapse button, as on Twitch.
    expect(find.byTooltip('Collapse Hype Train'), findsNothing);
    await tester.fling(_banner, const Offset(0, -120), 1000);
    // Level 7's gradient flows for ever: settle by time, not by idling.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HypeTrainBanner), findsNothing);
    expect(find.byKey(const ValueKey('ht-pill')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('ht-pill'))).height, 32);
    expect(
      tester.getSize(find.byKey(const ValueKey('ht-pill-fill'))).width,
      closeTo(
        tester.getSize(find.byKey(const ValueKey('ht-pill'))).width * 0.33,
        0.5,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ht-pill')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HypeTrainBanner), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('large text does not overflow at 360 px', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('LVL 7'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('builds in the dark theme', (tester) async {
    final h = running(tester);
    await pumpSlot(tester, h.store, theme: ThemeData.dark());

    expect(find.text('33%'), findsOneWidget);
    await h.close(tester);
  });

  group('layout', () {
    HtHarness withAth(HtAthState athState) => HtHarness(
      snapshot: HtOngoingSnapshot(
        liveTrain(athState: athState),
        fetchedAt: DateTime.utc(2026),
      ),
    );

    testWidgets(
      'the banner is 74 dp tall when its subtitle fits one line',
      (tester) async {
        // Wide enough for the test font's wide letters to keep the
        // subtitle on one line: on two, the banner grows to show them.
        final h = running(tester);
        await pumpSlot(tester, h.store, width: 600);

        expect(tester.getSize(_banner).height, 74);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('it grows with the text and never overflows', (tester) async {
      for (final width in [360.0, 280.0, 220.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          final h = running(tester);
          await pumpSlot(tester, h.store, width: width, textScale: scale);

          expect(tester.takeException(), isNull, reason: '$width @ $scale');
          expect(
            tester.getSize(_banner).height,
            greaterThanOrEqualTo(74 * scale - 0.01),
            reason: '$width @ $scale',
          );
          await h.close(tester);
        }
      }
    });

    testWidgets('no style overflows at any width, scale or direction', (
      tester,
    ) async {
      for (final athState in [
        HtAthState.none,
        HtAthState.approaching,
        HtAthState.reached,
      ]) {
        for (final compact in [false, true]) {
          for (final direction in TextDirection.values) {
            for (final width in [360.0, 280.0, 220.0]) {
              for (final scale in [1.0, 1.3, 2.0]) {
                final h = withAth(athState);
                await pumpSlot(
                  tester,
                  h.store,
                  width: width,
                  textScale: scale,
                  direction: direction,
                  compact: compact,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      '$athState compact $compact $direction $width @ '
                      '$scale',
                );
                await h.close(tester);
              }
            }
          }
        }
      }
    });

    testWidgets('the level pill is a near-black pill with LVL n in the '
        'level colour', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(HypeTrainLevelPill),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xDB0A0A0A));
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(
        tester.widget<Text>(find.text('LVL 7')).style?.color,
        const Color(0xFFC8FF3D),
      );
      await h.close(tester);
    });

    testWidgets('title, subtitle, percentage and countdown styles', (
      tester,
    ) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final title = tester.widget<Text>(find.byKey(const ValueKey('ht-title')));
      expect(title.data, 'Hype Train');
      expect(title.style?.fontSize, 18);
      expect(title.style?.fontWeight, FontWeight.w700);
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey('ht-subtitle')),
      );
      expect(subtitle.data, 'Sub, gift, or use Bits!');
      expect(subtitle.maxLines, 2);
      expect(subtitle.style?.fontWeight, FontWeight.w400);
      final percent = tester.widget<Text>(
        find.byKey(const ValueKey('ht-percent')),
      );
      expect(percent.style?.fontSize, 24);
      expect(percent.style?.fontWeight, FontWeight.w700);
      final countdown = tester.widget<Text>(
        find.descendant(
          of: find.byType(HypeTrainCountdown),
          matching: find.byType(Text),
        ),
      );
      expect(countdown.style?.fontSize, 14);
      expect(countdown.style?.fontWeight, FontWeight.w400);
      // No variant icon at rest.
      expect(find.byIcon(Icons.train_rounded), findsNothing);
      await h.close(tester);
    });

    testWidgets('the chevron opens the details and turns', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);
      final chevron = find.byIcon(Icons.expand_more_rounded);

      await tester.tap(chevron);
      await tester.pump();
      expect(h.store.expanded, isTrue);
      expect(
        tester
            .widget<AnimatedRotation>(
              find.ancestor(
                of: chevron,
                matching: find.byType(AnimatedRotation),
              ),
            )
            .turns,
        0.5,
      );
      await h.close(tester);
    });

    testWidgets('a screen reader action collapses it', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.customSemanticsActions?.isNotEmpty ?? false),
        ),
      );
      final actions = semantics.properties.customSemanticsActions!;
      expect(actions.keys.single.label, 'Collapse Hype Train');
      actions.values.single();
      await tester.pumpAndSettle();

      expect(h.store.collapsed, isTrue);
      expect(find.byKey(const ValueKey('ht-pill')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('compact: no title, the train name as its line, every word', (
      tester,
    ) async {
      final h = running(tester);
      await pumpSlot(
        tester,
        h.store,
        compact: true,
        width: 220,
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('ht-title')), findsNothing);
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey('ht-subtitle')),
      );
      expect(subtitle.data, 'Hype Train');
      // Shrunk, then wrapped on a narrow banner, never cut.
      expect(subtitle.maxLines, lessThanOrEqualTo(2));
      expect(
        ellipsizedTexts(
          tester,
          within: find.byKey(const ValueKey('ht-subtitle')),
        ),
        isEmpty,
      );
      await h.close(tester);
    });

    testWidgets('a record in sight: the trophy instead of the pill', (
      tester,
    ) async {
      final h = withAth(HtAthState.approaching);
      await pumpSlot(tester, h.store);

      final trophy = find.byKey(const ValueKey('ht-ath-trophy'));
      expect(trophy, findsOneWidget);
      // The full 100 dp column at phone width, cropped to the banner.
      expect(
        tester
            .getSize(
              find.ancestor(of: trophy, matching: find.byType(ClipRect)).first,
            )
            .width,
        100,
      );
      expect(find.byType(HypeTrainLevelPill), findsNothing);
      expect(find.byKey(const ValueKey('ht-title')), findsNothing);
      expect(find.text(HtCopy(L10n.english).athApproaching), findsOneWidget);
      // At least the 74 dp base, taller when the line wraps (every word
      // in the app's font: hype_train_banner_fit_test).
      expect(tester.getSize(_banner).height, greaterThanOrEqualTo(74));
      await h.close(tester);
    });

    testWidgets('a record reached: a trophy in the pill', (tester) async {
      final h = withAth(HtAthState.reached);
      await pumpSlot(tester, h.store);

      final trophy = find.descendant(
        of: find.byType(HypeTrainLevelPill),
        matching: find.byIcon(Icons.emoji_events_rounded),
      );
      expect(trophy, findsOneWidget);
      expect(tester.getSize(trophy), const Size(24, 24));
      expect(tester.widget<Icon>(trophy).color, Colors.white);
      await h.close(tester);
    });

    testWidgets('right to left: the pill starts on the right', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store, direction: TextDirection.rtl);

      final banner = tester.getRect(_banner);
      expect(
        tester.getRect(find.byType(HypeTrainLevelPill)).right,
        closeTo(banner.right - 8, 0.5),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('ht-percent'))).dx,
        lessThan(banner.center.dx),
      );
      await h.close(tester);
    });

    testWidgets('a flash at 100% does not scale the percentage', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('100%'),
          matching: find.byType(AnimatedScale),
        ),
        findsNothing,
      );
      await h.close(tester);
    });
  });

  group('announcements', () {
    double opacityOf(WidgetTester tester, Finder finder) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    testWidgets('the resting content fades out; the fill stays', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);
      expect(opacityOf(tester, find.text('LVL 2')), 1);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(stepKey('marquee'), findsOneWidget);

      expect(opacityOf(tester, find.text('LVL 2')), 0);
      expect(opacityOf(tester, find.byKey(const ValueKey('ht-percent'))), 0);
      expect(opacityOf(tester, find.byIcon(Icons.expand_more_rounded)), 0);
      expect(find.byType(HypeTrainProgressBar), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('the marquee runs across the whole banner', (tester) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      final banner = tester.getRect(_banner);

      expect(marqueeX(tester), closeTo(banner.width, 40));
      final text = tester.widget<Text>(find.text(HtCopy(L10n.english).levelUp));
      expect(text.style?.fontSize, 24);
      expect(text.style?.fontWeight, FontWeight.w700);
      await h.close(tester);
    });

    testWidgets('"Level 2 Complete!" is centred at 24 sp', (tester) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pump(const Duration(milliseconds: 200));
      final complete = find.text('Level 2 Complete!');

      expect(tester.widget<Text>(complete).style?.fontSize, 24);
      expect(
        tester.getCenter(complete).dx,
        closeTo(tester.getCenter(_banner).dx, 1),
      );
      expect(
        tester.getCenter(complete).dy,
        closeTo(tester.getCenter(_banner).dy, 1),
      );
      await h.close(tester);
    });

    testWidgets('a large gift is a small announcement with a gift icon', (
      tester,
    ) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);

      h.inject(htSmall(16500, isLarge: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      final small = find.byKey(const ValueKey('ht-small-announcement'));

      expect(small, findsOneWidget);
      expect(
        find.descendant(
          of: small,
          matching: find.byIcon(Icons.card_giftcard_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: small,
          matching: find.text('Viewer_1 just gifted 50 Tier 1 Subs!'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.text('Viewer_1 just gifted 50 Tier 1 Subs!'))
            .style
            ?.fontSize,
        13,
      );
      await h.close(tester);
    });

    testWidgets('compact announcements are smaller', (tester) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, compact: true);

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        tester.widget<Text>(find.text('Level 2 Complete!')).style?.fontSize,
        18,
      );
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });

    testWidgets('announcements fit large text on a narrow banner', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, width: 280, textScale: 2);

      h.inject(htSmall(16500, isLarge: true));
      h.inject(htLevelUp(3));
      for (var t = 0; t < 120; t++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'at ${t * 100} ms');
      }
      await h.close(tester);
    });
  });

  group('ONSET level colours', () {
    HypeTrainProgressBarState bar(WidgetTester tester) => tester
        .state<HypeTrainProgressBarState>(find.byType(HypeTrainProgressBar));

    RenderHtSplitColor splitOf(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderHtSplitColor>(
          find.ancestor(of: text, matching: find.byType(HtSplitColor)).first,
        );

    BoxDecoration fillDecoration(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(find.byKey(const ValueKey('ht-fill')))
                .decoration
            as BoxDecoration;

    testWidgets('dark text on the fill, light on the track, turning at '
        'the edge', (tester) async {
      final h = running(tester, level: 4);
      await pumpSlot(tester, h.store);

      expect(fillDecoration(tester).color, const Color(0xFFC8FF3D));
      final numbers = splitOf(tester, find.text('33%'));
      expect(numbers.onFill, HtLevelColors.onFill);
      expect(numbers.onTrack, HtLevelColors.onTrack);
      // The percentage is at the end, on the track: all light.
      expect(numbers.split.at, 0);
      // The subtitle starts on the fill and runs onto the track.
      final subtitle = splitOf(
        tester,
        find.byKey(const ValueKey('ht-subtitle')),
      );
      final banner = tester.getRect(_banner);
      final box = tester.getRect(find.byKey(const ValueKey('ht-subtitle')));
      final edge = banner.left + banner.width * 0.33;
      expect(subtitle.split.at, closeTo((edge - box.left) / box.width, 0.02));
      expect(subtitle.split.fillOnLeft, isTrue);
      // The level pill keeps its own colours.
      expect(
        find.ancestor(
          of: find.byType(HypeTrainLevelPill),
          matching: find.byType(HtSplitColor),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('ht-hairline')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('the edge follows the fill as it grows', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);
      final subtitle = splitOf(
        tester,
        find.byKey(const ValueKey('ht-subtitle')),
      );
      final before = subtitle.split.at;

      h.inject(htSmall(16500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar(tester).value, closeTo(0.43, 0.01));
      expect(subtitle.split.at, greaterThan(before));
      await h.close(tester);
    });

    testWidgets('right to left the fill and its dark text are on the right', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, direction: TextDirection.rtl);

      final numbers = splitOf(tester, find.text('33%'));
      expect(numbers.split.fillOnLeft, isFalse);
      await h.close(tester);
    });

    testWidgets('level up: 100 % in 200 ms, a flash with "Level n '
        'Complete!", the colour morphs in 600 ms, the bar restarts', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store);
      expect(fillDecoration(tester).color, const Color(0xFF14B8A6));

      h.inject(htLevelUp(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar(tester).value, closeTo(1, 0.001));
      expect(find.byKey(const ValueKey('ht-flash')), findsNothing);

      // Flash 500 ms, then the marquee 2.5 s: "Level 2 Complete!".
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Level 2 Complete!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      final flash = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('ht-flash')),
      );
      expect(flash.color.a, closeTo(0.45, 0.02));
      // The colour is already morphing to level 3's while it is announced.
      expect(bar(tester).morphValue, lessThan(0.1));
      expect(
        fillDecoration(tester).gradient!.colors.first,
        const Color(0xFF3DDBA6),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(bar(tester).morphValue, inExclusiveRange(0.3, 0.7));
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('ht-flash')))
            .color
            .a,
        lessThan(0.2),
      );
      // The level pill's text morphs too.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('ht-flash')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      // Level 3 starts again from 0 rather than draining back.
      expect(bar(tester).value, lessThan(0.1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bar(tester).morphValue, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar(tester).value, closeTo(0.1, 0.01));
      // The pill counts up to the new level (1 s).
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('LVL 3'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('LVL 3')).style?.color,
        const Color(0xFF3DDBA6),
      );
      await h.close(tester);
    });

    testWidgets('reduce motion: no flash, a 200 ms colour change', (
      tester,
    ) async {
      final h = running(tester, level: 2);
      await pumpSlot(tester, h.store, reduceMotion: true);

      h.inject(htLevelUp(3));
      await tester.pump();
      for (var t = 0; t < 40; t++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('ht-flash')), findsNothing);
        if (find.text('Level 2 Complete!').evaluate().isNotEmpty) break;
      }
      expect(find.text('Level 2 Complete!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(bar(tester).morphValue, inExclusiveRange(0.3, 0.7));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bar(tester).morphValue, 1);
      await h.close(tester);
    });

    testWidgets('level 6 and up flows; reduce motion and a hidden screen '
        'stop it', (tester) async {
      final h = running(tester);
      await pumpSlot(tester, h.store);
      final first = bar(tester).sheenValue;
      await tester.pump(const Duration(seconds: 1));
      expect(bar(tester).sheenValue, closeTo(first + 0.25, 0.01));
      expect(
        (fillDecoration(tester).gradient! as LinearGradient).tileMode,
        TileMode.repeated,
      );
      await h.close(tester);

      final still = running(tester);
      await pumpSlot(tester, still.store, reduceMotion: true);
      await tester.pump(const Duration(seconds: 1));
      expect(bar(tester).sheenValue, 0);
      await still.close(tester);
    });

    testWidgets('a background tab pauses the flow (TickerMode)', (
      tester,
    ) async {
      final h = running(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TickerMode(
            enabled: false,
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: HypeTrainBanner(store: h.store),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final before = bar(tester).sheenValue;
      await tester.pump(const Duration(seconds: 1));
      expect(bar(tester).sheenValue, before);
      await h.close(tester);
    });

    for (final (name, width, compact) in [
      ('phone 390', 390.0, false),
      ('tablet portrait 560', 560.0, false),
      ('tablet side chat 280', 280.0, true),
      ('landscape side chat 256', 256.0, true),
    ]) {
      testWidgets('every level fits: $name', (tester) async {
        for (var level = 1; level <= 7; level++) {
          final h = running(tester, level: level);
          await pumpSlot(tester, h.store, width: width, compact: compact);
          expect(tester.takeException(), isNull, reason: 'L$level');
          await h.close(tester);
        }
      });
    }
  });
}
