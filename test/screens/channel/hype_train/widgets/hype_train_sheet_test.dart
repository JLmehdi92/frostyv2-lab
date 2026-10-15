import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../hype_train_test_data.dart';
import 'hype_train_widget_harness.dart';

HtReward emote(String id) =>
    HtReward(type: HtRewardType.emote, id: id, token: id);

HtConductor conductor(HtSource source, String name, Map<String, int> did) =>
    HtConductor(source: source, user: user(name), participations: did);

Future<void> pumpSheet(
  WidgetTester tester,
  HypeTrainStore store, {
  VoidCallback? onLearnMore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HypeTrainSheet(
            store: store,
            onLearnMore: onLearnMore ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

HypeTrainExecution withRewards(HypeTrainExecution train) => train.copyWith(
  progress: HtProgress(
    level: HtLevel(
      value: train.level,
      cumulativeGoal: 20000,
      rewards: [emote('level1'), emote('level2')],
    ),
    goal: train.progress.goal,
    value: train.progress.value,
    total: train.progress.total,
  ),
);

void main() {
  HtHarness harnessFor(HypeTrainExecution train) => HtHarness(
    snapshot: HtOngoingSnapshot(train, fetchedAt: DateTime.utc(2026)),
  );

  testWidgets('the level target reads 10 Tier 1 Subs or 4,700 Bits', (
    tester,
  ) async {
    final h = harnessFor(withRewards(liveTrain(value: 0)));
    await pumpSheet(tester, h.store);

    expect(find.textContaining('10 Tier 1 Subs'), findsOneWidget);
    expect(find.textContaining('4,700 Bits'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('conductors with amounts; an empty slot invites', (tester) async {
    final h = harnessFor(
      liveTrain().copyWith(
        conductors: [
          conductor(HtSource.subs, 'giver', {'TIER_1_GIFTED_SUB': 5}),
        ],
      ),
    );
    await pumpSheet(tester, h.store);

    expect(find.text('giver has contributed 5 Subs!'), findsOneWidget);
    expect(find.text('Use Bits to take over this spot!'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('level rewards are locked; unlocked ones are not', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = harnessFor(withRewards(liveTrain(level: 2)));
    await pumpSheet(tester, h.store);

    expect(find.bySemanticsLabel('Locked reward level1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));

    h.inject(htLevelUp(3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.bySemanticsLabel('Unlocked reward level1'), findsOneWidget);

    await h.close(tester);
    semantics.dispose();
  });

  testWidgets('treasure copy before and after the threshold', (tester) async {
    const treasure = HtTreasure(
      discountPercentage: 50,
      threshold: 3,
      status: HtUnlockStatus.none,
    );
    final before = harnessFor(liveTrain(level: 2, treasure: treasure));
    await pumpSheet(tester, before.store);
    expect(find.textContaining('at Level 3'), findsOneWidget);
    await before.close(tester);

    final after = harnessFor(liveTrain(level: 4, treasure: treasure));
    await pumpSheet(tester, after.store);
    expect(find.textContaining('Save 50% on 5 or more'), findsOneWidget);
    expect(find.textContaining('All Aboard!'), findsOneWidget);
    await after.close(tester);
  });

  testWidgets('community copy before and after the threshold', (tester) async {
    final community = HtCommunity.parse(const {
      'rewardLevelThreshold': 5,
      'nextRewardAmount': 20,
      'currentRewardAmount': 30,
    });
    final before = harnessFor(liveTrain(level: 3, community: community));
    await pumpSheet(tester, before.store);
    expect(find.textContaining('Hit Level 5'), findsOneWidget);
    await before.close(tester);

    final after = harnessFor(liveTrain(level: 6, community: community));
    await pumpSheet(tester, after.store);
    expect(find.textContaining('You unlocked 30 emotes'), findsOneWidget);
    await after.close(tester);
  });

  testWidgets('"Coming up" loads once, on first expand', (tester) async {
    final h = harnessFor(liveTrain());
    when(() => h.service.getUpcomingRewards(any())).thenAnswer(
      (_) async => [
        (8, [emote('next8')]),
        (9, [emote('next9')]),
      ],
    );
    await pumpSheet(tester, h.store);
    verifyNever(() => h.service.getUpcomingRewards(any()));

    await tester.ensureVisible(find.text('Coming up'));
    await tester.tap(find.text('Coming up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Level 8'), findsOneWidget);
    expect(find.text('Level 9'), findsOneWidget);

    await tester.ensureVisible(find.text('Coming up'));
    await tester.tap(find.text('Coming up'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Coming up'));
    await tester.tap(find.text('Coming up'));
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => h.service.getUpcomingRewards(any())).called(1);
    await h.close(tester);
  });

  testWidgets('"Coming up" shows an empty state', (tester) async {
    final h = harnessFor(liveTrain());
    when(
      () => h.service.getUpcomingRewards(any()),
    ).thenAnswer((_) async => const []);
    await pumpSheet(tester, h.store);

    await tester.ensureVisible(find.text('Coming up'));
    await tester.tap(find.text('Coming up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nothing more to show yet'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('learn more uses the injected launcher', (tester) async {
    var opened = 0;
    final h = harnessFor(liveTrain());
    await pumpSheet(tester, h.store, onLearnMore: () => opened++);

    await tester.ensureVisible(find.text('More Info'));
    await tester.tap(find.text('More Info'));

    expect(opened, 1);
    await h.close(tester);
  });

  testWidgets('no buying buttons (D4)', (tester) async {
    final h = harnessFor(liveTrain());
    await pumpSheet(tester, h.store);

    for (final label in ['Subscribe', 'Gift', 'Cheer', 'Gift a sub']) {
      expect(find.widgetWithText(ElevatedButton, label), findsNothing);
      expect(find.widgetWithText(FilledButton, label), findsNothing);
    }
    await h.close(tester);
  });

  testWidgets('sections are headings', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = harnessFor(liveTrain());
    await pumpSheet(tester, h.store);

    expect(
      tester.getSemantics(find.text('HYPE CONDUCTORS')),
      containsSemantics(isHeader: true),
    );
    await h.close(tester);
    semantics.dispose();
  });

  testWidgets('the record line', (tester) async {
    final h = harnessFor(
      liveTrain(total: 5000).copyWith(
        ath: const HtAth(level: 9, goal: 0, progression: 0, total: 10000),
      ),
    );
    await pumpSheet(tester, h.store);

    expect(find.textContaining('Level 9'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('approaching: explainer and level 1 rewards', (tester) async {
    final h = HtHarness();
    await pumpSheet(tester, h.store);
    h.inject(
      HtApproachingEvent(
        HypeTrainApproaching(
          id: 'a',
          goal: 3,
          deadlines: const {1: 60},
          levelOneRewards: [emote('first')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('What is a Hype Train?'), findsOneWidget);
    expect(find.bySemanticsLabel('Locked reward first'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('nothing when the train is gone', (tester) async {
    final h = HtHarness();
    await pumpSheet(tester, h.store);

    expect(find.text('HYPE CONDUCTORS'), findsNothing);
    expect(tester.getSize(find.byType(HypeTrainSheet)).height, 0);
    await h.close(tester);
  });
}
