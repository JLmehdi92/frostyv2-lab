import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/community_highlights/widgets/gift_bomb_pin.dart';
import 'package:onset/theme.dart';

import '../../../../helpers/semantics_audit.dart';

final _start = DateTime.utc(2026, 10, 13, 20);

const _lime = OnsetTokens.accent;

GiftBomb _bomb({int count = 5, String gifter = 'qqalex', int received = 0}) =>
    GiftBomb(
      key: 'bomb',
      gifterName: gifter,
      isAnonymous: false,
      count: count,
      tier: 'Tier 1',
      received: received,
    );

GiftBombBanner _banner({
  int count = 5,
  String gifter = 'qqalex',
  ValueNotifier<GiftBomb>? live,
  Duration length = const Duration(seconds: 10),
  int received = 0,
}) => GiftBombBanner(
  bomb: _bomb(count: count, gifter: gifter, received: received),
  startedAt: _start,
  endsAt: _start.add(length),
  live: live,
);

void main() {
  var dismissed = 0;
  // Twitch's clock follows the test clock: the pin reads it for its
  // countdown.
  var elapsed = Duration.zero;
  DateTime now() => _start.add(elapsed);

  setUp(() {
    dismissed = 0;
    elapsed = Duration.zero;
  });

  Future<void> pump(
    WidgetTester tester,
    GiftBombBanner banner, {
    bool reduceMotion = false,
    bool compact = false,
    double width = 390,
    bool dark = true,
    bool dismissible = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dark
          ? const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark
          : const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1280, 854),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: width - 16,
                child: GiftBombPin(
                  banner: banner,
                  now: now,
                  compact: compact,
                  onDismiss: dismissible ? () => dismissed++ : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Advances the test clock and Twitch's together.
  Future<void> wait(WidgetTester tester, Duration duration) async {
    elapsed += duration;
    await tester.pump(duration);
  }

  GiftBombRingPainter ring(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(GiftBombPin.ringKey),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as GiftBombRingPainter;

  double opacityOf(WidgetTester tester, Key key) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.byKey(key), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  double drain(WidgetTester tester) => tester
      .state<GiftBombCountdownBarState>(find.byKey(GiftBombPin.drainKey))
      .value;

  group('wide', () {
    testWidgets('"X is gifting N subs" and "R of N handed out"', (
      tester,
    ) async {
      await pump(tester, _banner(received: 3));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('qqalex'), findsOneWidget);
      expect(find.text(' is gifting 5 subs'), findsOneWidget);
      expect(find.text(' of 5 handed out'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(GiftBombPin.nameKey)).style?.color,
        _lime,
      );
    });

    testWidgets('a 56 dp card, 12 dp corners, no elevation', (tester) async {
      await pump(tester, _banner());
      await tester.pump(const Duration(milliseconds: 300));

      final pin = find.byKey(GiftBombPin.pinKey);
      expect(tester.getSize(pin).height, 56);
      final decoration =
          tester.widget<Container>(pin).decoration! as ShapeDecoration;
      expect(decoration.color, const Color(0xFF141414));
      expect(
        (decoration.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
      expect(find.byType(Material).evaluate().length, greaterThan(0));
      expect(
        tester
            .widgetList<Material>(
              find.descendant(of: pin, matching: find.byType(Material)),
            )
            .every((m) => m.elevation == 0),
        isTrue,
      );
      expect(
        tester.getSize(find.byKey(GiftBombPin.ringKey)),
        const Size.square(40),
      );
    });

    testWidgets('the close button is a 44 dp target', (tester) async {
      await pump(tester, _banner());
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.getSize(find.byType(IconButton)), const Size(44, 44));
      expect(find.byTooltip('Hide'), findsOneWidget);
    });
  });

  group('one line', () {
    testWidgets('"X ×N" in 44 dp', (tester) async {
      await pump(tester, _banner(count: 50), compact: true, width: 256);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('×50'), findsOneWidget);
      expect(find.text(' is gifting 50 subs'), findsNothing);
      expect(find.byKey(GiftBombPin.progressKey), findsNothing);
      expect(tester.getSize(find.byKey(GiftBombPin.pinKey)).height, 44);
      expect(
        tester.getSize(find.byKey(GiftBombPin.ringKey)),
        const Size.square(28),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(44, 44));
    });

    testWidgets('a column too narrow for the wide pin gets this one', (
      tester,
    ) async {
      await pump(tester, _banner(), width: 280);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('×5'), findsOneWidget);
    });
  });

  group('long names never cut the count', () {
    const long = 'saladetomateoignons0saladetomateoignons0';
    for (final width in [256.0, 320.0, 390.0, 600.0]) {
      for (final compact in [false, true]) {
        testWidgets('at ${width.toInt()} dp${compact ? ', one line' : ''}', (
          tester,
        ) async {
          await pump(
            tester,
            _banner(gifter: long, count: 100),
            width: width,
            compact: compact,
          );
          await tester.pump(const Duration(milliseconds: 300));

          final pin = tester.getRect(find.byKey(GiftBombPin.pinKey));
          final count = tester.getRect(find.byKey(GiftBombPin.countKey));
          final name = find.byKey(GiftBombPin.nameKey);
          expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
          expect(count.right, lessThanOrEqualTo(pin.right - 44));
          expect(count.left, greaterThanOrEqualTo(tester.getRect(name).right));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('large text still fits', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
            home: Scaffold(
              body: SizedBox(
                width: 374,
                child: GiftBombPin(
                  banner: _banner(gifter: long, count: 100),
                  now: now,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('the ring and the box', () {
    testWidgets('the ring follows the gifts received', (tester) async {
      final live = ValueNotifier(_bomb());
      addTearDown(live.dispose);
      await pump(tester, _banner(live: live));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ring(tester).fraction, 0);

      live.value = live.value.withGift('a').withGift('b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(ring(tester).fraction, closeTo(0.4, 1e-9));
      expect(ring(tester).color, _lime);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('the closed box hops while gifts arrive', (tester) async {
      await pump(tester, _banner());
      await tester.pump(const Duration(milliseconds: 300));

      expect(giftBoxHopAt(0.25), (-2.0, -4.0));
      expect(giftBoxHopAt(0.75), (-2.0, 4.0));
      expect(giftBoxHopAt(0), (-0.0, -0.0));
      expect(find.byKey(GiftBombPin.closedBoxKey), findsOneWidget);
      expect(opacityOf(tester, GiftBombPin.openBoxKey), 0);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('the last gift opens the box in a burst, then "thanks!"', (
      tester,
    ) async {
      final live = ValueNotifier(_bomb(received: 4));
      addTearDown(live.dispose);
      await pump(tester, _banner(live: live));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(GiftBombPin.glowKey), findsNothing);
      expect(find.byKey(GiftBombPin.sparksKey), findsNothing);

      live.value = live.value.withGift('e');
      await tester.pump();
      // Squash, then the open box fades in from 60 ms over 120 ms.
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacityOf(tester, GiftBombPin.openBoxKey), 0);
      expect(find.byKey(GiftBombPin.glowKey), findsOneWidget);
      expect(find.byKey(GiftBombPin.sparksKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 120));
      expect(opacityOf(tester, GiftBombPin.openBoxKey), closeTo(1, 1e-9));
      expect(opacityOf(tester, GiftBombPin.closedBoxKey), closeTo(0, 1e-9));
      // The glow peaks at 40 % of its 400 ms, then fades.
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester.widget<Opacity>(find.byKey(GiftBombPin.glowKey)).opacity,
        closeTo(1, 0.01),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<Opacity>(find.byKey(GiftBombPin.glowKey)).opacity,
        0,
      );
      expect(find.text('5 of 5 · thanks!'), findsOneWidget);
      expect(find.text(' of 5 handed out'), findsNothing);
      expect(ring(tester).fraction, 1);
      // It stays until the countdown ends.
      expect(tester.getSize(find.byKey(GiftBombPin.pinKey)).height, 56);
    });

    testWidgets('a bomb first seen complete opens without a burst', (
      tester,
    ) async {
      await pump(tester, _banner(received: 5));
      await tester.pump(const Duration(milliseconds: 300));

      expect(opacityOf(tester, GiftBombPin.openBoxKey), 1);
      expect(find.byKey(GiftBombPin.sparksKey), findsNothing);
    });
  });

  group('reduce motion', () {
    testWidgets('no hop, no burst: a 150 ms cross-fade', (tester) async {
      final live = ValueNotifier(_bomb(received: 4));
      addTearDown(live.dispose);
      await pump(tester, _banner(live: live), reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 300));

      final box = find.byKey(GiftBombPin.closedBoxKey);
      expect(
        find
            .ancestor(of: box, matching: find.byType(Transform))
            .evaluate()
            .where((e) {
              final w = e.widget as Transform;
              return !w.transform.isIdentity();
            }),
        isEmpty,
      );

      live.value = live.value.withGift('e');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacityOf(tester, GiftBombPin.openBoxKey), closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacityOf(tester, GiftBombPin.openBoxKey), 1);
      expect(find.byKey(GiftBombPin.glowKey), findsNothing);
      expect(find.byKey(GiftBombPin.sparksKey), findsNothing);
    });

    testWidgets('the bar steps once a second', (tester) async {
      await pump(tester, _banner(), reduceMotion: true);

      await wait(tester, const Duration(milliseconds: 2500));
      expect(drain(tester), closeTo(0.8, 1e-9));
      await wait(tester, const Duration(milliseconds: 400));
      expect(drain(tester), closeTo(0.8, 1e-9));
      await wait(tester, const Duration(milliseconds: 200));
      expect(drain(tester), closeTo(0.7, 1e-9));
    });
  });

  group('countdown', () {
    testWidgets('a 2 dp signal bar drains along the bottom edge', (
      tester,
    ) async {
      await pump(tester, _banner());
      expect(drain(tester), 1);
      await wait(tester, const Duration(milliseconds: 300));

      final pin = tester.getRect(find.byKey(GiftBombPin.pinKey));
      final bar = tester.getRect(find.byKey(GiftBombPin.drainKey));
      expect(bar.height, 2);
      expect(bar.bottom, pin.bottom);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(GiftBombPin.drainKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        _lime,
      );
      await wait(tester, const Duration(milliseconds: 2200));
      expect(drain(tester), closeTo(0.75, 0.01));
    });

    testWidgets('a banner shown late starts part-drained', (tester) async {
      await pump(
        tester,
        GiftBombBanner(
          bomb: _bomb(),
          startedAt: _start.subtract(const Duration(seconds: 4)),
          endsAt: _start.add(const Duration(seconds: 6)),
        ),
      );

      expect(drain(tester), closeTo(0.6, 1e-9));
    });

    for (final (count, seconds) in [(5, 10), (25, 15), (50, 20), (100, 30)]) {
      testWidgets('$count gifts: folds away as its ${seconds}s end', (
        tester,
      ) async {
        await pump(
          tester,
          _banner(count: count, length: bannerDuration(count)!),
        );
        await wait(tester, Duration(seconds: seconds) - GiftBombPin.exit);
        expect(tester.getSize(find.byKey(GiftBombPin.pinKey)).height, 56);
        await wait(tester, const Duration(milliseconds: 140));
        final half = tester.getSize(find.byType(GiftBombPin)).height;
        expect(half, inExclusiveRange(0, 56));
        await wait(tester, const Duration(milliseconds: 140));
        expect(tester.getSize(find.byType(GiftBombPin)).height, 0);
        expect(dismissed, 0);
      });
    }
  });

  group('a new banner in the same place', () {
    testWidgets('another bomb starts over as a fresh pin', (tester) async {
      await pump(tester, _banner(gifter: 'first'));
      await wait(tester, const Duration(seconds: 10));
      await wait(tester, const Duration(milliseconds: 300));
      // The first one folded away at its end.
      expect(tester.getSize(find.byType(GiftBombPin)).height, 0);

      await pump(
        tester,
        GiftBombBanner(
          bomb: const GiftBomb(
            key: 'other',
            gifterName: 'second',
            isAnonymous: false,
            count: 5,
          ),
          startedAt: now(),
          endsAt: now().add(const Duration(seconds: 10)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('second'), findsOneWidget);
      expect(tester.getSize(find.byKey(GiftBombPin.pinKey)).height, 56);
      expect(tester.getSize(find.byType(GiftBombPin)).height, 56);
    });

    testWidgets('the same bomb pinned again for longer comes back', (
      tester,
    ) async {
      await pump(tester, _banner());
      await wait(tester, const Duration(milliseconds: 9800));
      await wait(tester, const Duration(milliseconds: 100));
      expect(tester.getSize(find.byType(GiftBombPin)).height, lessThan(56));

      await pump(tester, _banner(length: const Duration(seconds: 20)));
      await tester.pump();
      expect(tester.getSize(find.byType(GiftBombPin)).height, 56);
    });
  });

  group('dismiss', () {
    testWidgets('the close button folds it away, then dismisses', (
      tester,
    ) async {
      await pump(tester, _banner());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Hide'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(dismissed, 0);
      await tester.pump(const Duration(milliseconds: 160));
      expect(dismissed, 1);
      expect(tester.getSize(find.byType(GiftBombPin)).height, 0);

      // Tapping again while it leaves does nothing more.
      await tester.pump(const Duration(seconds: 1));
      expect(dismissed, 1);
    });

    testWidgets('without a dismiss there is no close button', (tester) async {
      await pump(tester, _banner(), dismissible: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(IconButton), findsNothing);
    });
  });

  testWidgets('screen readers hear the whole pin and can press Hide', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _banner(received: 2));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('qqalex is gifting 5 subs'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('qqalex is gifting 5 subs')),
      matchesSemantics(
        label: 'qqalex is gifting 5 subs',
        value: '2 of 5 handed out',
        isLiveRegion: true,
        children: [anything],
      ),
    );
    expectNoSilentButtons(tester, reason: 'gift bomb pin');
    handle.dispose();
  });

  testWidgets('the light theme keeps the name readable', (tester) async {
    await pump(tester, _banner(), dark: false);
    await tester.pump(const Duration(milliseconds: 300));

    final name = tester.widget<Text>(find.byKey(GiftBombPin.nameKey));
    expect(name.style?.color, OnsetColors.light.subNoticeText);
    expect(
      tester.widget<Container>(find.byKey(GiftBombPin.pinKey)).decoration,
      isA<ShapeDecoration>().having(
        (d) => d.color,
        'color',
        OnsetTokens.surfaceLight,
      ),
    );
  });
}
