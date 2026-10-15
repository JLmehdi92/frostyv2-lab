import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_end_strip.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

import 'hype_train_widget_harness.dart';

HtReward emote(int i) =>
    HtReward(type: HtRewardType.emote, id: 'emote$i', token: 'hype$i');

Future<HtHarness> ended(
  WidgetTester tester,
  HtEndReason reason, {
  HtVariant? variant,
}) async {
  final h = HtHarness(
    snapshot: HtOngoingSnapshot(
      liveTrain(variant: variant, expiresIn: const Duration(minutes: 5)),
      fetchedAt: DateTime.utc(2026),
    ),
  );
  await pumpSlot(tester, h.store);
  h.inject(
    HtEndEvent(reason: reason, rewards: [for (var i = 0; i < 4; i++) emote(i)]),
  );
  await tester.pump();
  return h;
}

double drain(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byKey(const ValueKey('ht-strip-bar')))
    .value!;

final _strip = find.byType(HypeTrainEndStrip);
final _bar = find.byKey(const ValueKey('ht-strip-bar'));
final _emotes = find.descendant(
  of: find.byKey(const ValueKey('ht-strip-emotes')),
  matching: find.byType(FrostyCachedNetworkImage),
);
const _rewards = 'Great work! Emotes are being delivered to supporters';

/// Pumps 100 ms frames until the strip shows.
Future<void> untilStrip(WidgetTester tester) async {
  for (var t = 0; t < 200 && _strip.evaluate().isEmpty; t++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(_strip, findsOneWidget);
}

/// Pumps 100 ms frames for [ms].
Future<void> frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The opacity [finder] is drawn at (1 when nothing fades it).
double shown(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final fade in tester.widgetList<FadeTransition>(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  )) {
    opacity *= fade.opacity.value;
  }
  return opacity;
}

void main() {
  testWidgets('rewards: the text, then three emotes at 14.9 s', (tester) async {
    final h = await ended(tester, HtEndReason.completed);
    // The completed sequence (marquee, totals, summary) comes first.
    await untilStrip(tester);
    await frames(tester, 1000);

    expect(tester.getSize(_strip).height, 74);
    final text = tester.widget<Text>(find.text(_rewards));
    expect(text.style?.fontSize, 14);
    expect(text.textAlign, TextAlign.center);
    expect(shown(tester, find.text(_rewards)), 1);
    expect(_emotes, findsNothing);

    await frames(tester, 14200);
    expect(_emotes, findsNWidgets(3));
    for (final emote in tester.widgetList<FrostyCachedNetworkImage>(_emotes)) {
      expect((emote.width, emote.height), (24.0, 24.0));
    }
    if (find.text(_rewards).evaluate().isNotEmpty) {
      expect(shown(tester, find.text(_rewards)), 0);
    }
    await frames(tester, 300);
    expect(find.text(_rewards), findsNothing);
    expect(shown(tester, _emotes.first), 1);
    await h.close(tester);
  });

  testWidgets('a 3 dp bar in the fill colour drains over 20 s, then the '
      'strip is gone', (tester) async {
    final h = await ended(tester, HtEndReason.completed);
    await untilStrip(tester);

    final strip = tester.getRect(_strip);
    expect(tester.getSize(_bar).height, 3);
    expect(tester.getRect(_bar).bottom, strip.bottom);
    expect(
      tester.widget<LinearProgressIndicator>(_bar).color,
      const Color(0xFF12A87A),
    );

    await frames(tester, 10000);
    expect(drain(tester), closeTo(0.5, 0.05));

    await frames(tester, 11000);
    expect(_strip, findsNothing);
    await h.close(tester);
  });

  testWidgets('golden rewards mention the 24 hour emote', (tester) async {
    final h = await ended(
      tester,
      HtEndReason.completed,
      variant: HtVariant.goldenKappa,
    );
    await untilStrip(tester);
    await frames(tester, 500);

    expect(find.textContaining('24 hrs'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('expired: a plain strip that cannot be tapped', (tester) async {
    final h = await ended(tester, HtEndReason.expired);
    await tester.pump(const Duration(milliseconds: 600));

    final text = tester.widget<Text>(
      find.text('You missed the Train. Better luck next time!'),
    );
    expect(text.maxLines, 2);
    expect(tester.getSize(_strip).height, 74);
    expect(
      find.descendant(of: _strip, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ht-strip-golden')), findsNothing);
    await h.close(tester);
  });

  testWidgets('an expired golden train shows the golden Kappa', (tester) async {
    final h = await ended(
      tester,
      HtEndReason.expired,
      variant: HtVariant.goldenKappa,
    );
    await tester.pump(const Duration(milliseconds: 600));

    final golden = find.byKey(const ValueKey('ht-strip-golden'));
    expect(tester.getSize(golden), const Size(40, 40));
    expect(
      tester.getRect(golden).right,
      closeTo(tester.getRect(_strip).right - 8, 0.5),
    );
    await h.close(tester);
  });

  testWidgets('large text on a narrow strip does not overflow', (tester) async {
    final h = HtHarness(
      snapshot: HtOngoingSnapshot(
        liveTrain(
          variant: HtVariant.goldenKappa,
          expiresIn: const Duration(minutes: 5),
        ),
        fetchedAt: DateTime.utc(2026),
      ),
    );
    await pumpSlot(tester, h.store, width: 220, textScale: 2);
    h.inject(const HtEndEvent(reason: HtEndReason.expired));
    await frames(tester, 1000);

    expect(_strip, findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });
}
