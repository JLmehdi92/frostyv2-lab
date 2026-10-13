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

void main() {
  testWidgets('rewards: three emotes, a draining bar, then gone', (
    tester,
  ) async {
    final h = await ended(tester, HtEndReason.completed);
    // The completed sequence (marquee, totals, summary) comes first.
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(HypeTrainEndStrip), findsOneWidget);
    expect(find.text('Rewards are on their way'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ht-strip-emotes')),
        matching: find.byType(FrostyCachedNetworkImage),
      ),
      findsNWidgets(3),
    );

    await tester.pump(const Duration(seconds: 10));
    expect(drain(tester), closeTo(0.5, 0.05));

    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HypeTrainEndStrip), findsNothing);
    await h.close(tester);
  });

  testWidgets('golden rewards mention the 24 hour emote', (tester) async {
    final h = await ended(
      tester,
      HtEndReason.completed,
      variant: HtVariant.goldenKappa,
    );
    await tester.pump(const Duration(seconds: 12));

    expect(find.textContaining('24 hours'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('expired: a plain strip that cannot be tapped', (tester) async {
    final h = await ended(tester, HtEndReason.expired);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('This Hype Train has ended'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HypeTrainEndStrip),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    await h.close(tester);
  });
}
