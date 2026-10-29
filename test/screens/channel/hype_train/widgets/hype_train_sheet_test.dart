import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/hype_train_event.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';

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
    expect(find.text('Level 8 emotes'), findsOneWidget);
    expect(find.text('Level 9 emotes'), findsOneWidget);

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

  group('twitch layout', () {
    testWidgets('headers are the board labels, as headings', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = harnessFor(withRewards(liveTrain()));
      await pumpSheet(tester, h.store);

      for (final header in ['HYPE CONDUCTORS', 'AVAILABLE REWARDS']) {
        expect(
          tester.getSemantics(find.text(header)),
          containsSemantics(isHeader: true),
        );
        // Board ChaineHypeDetail: 11 / 700, wide tracking, green.
        final style = tester.widget<Text>(find.text(header)).style;
        expect(style?.fontSize, 11);
        expect(style?.fontWeight, FontWeight.w700);
        expect(style?.letterSpacing, greaterThan(1));
        expect(style?.color?.g, greaterThan(style?.color?.r ?? 1));
      }
      expect(find.text('Current Hype Train top supporters.'), findsOneWidget);
      await h.close(tester);
      semantics.dispose();
    });

    testWidgets('the level target is a 12 sp footnote', (tester) async {
      final h = harnessFor(liveTrain(value: 0));
      await pumpSheet(tester, h.store);

      final target = tester.widget<Text>(
        find.textContaining('Completing Level 7'),
      );
      expect(target.style?.fontSize, 12);
      await h.close(tester);
    });

    testWidgets('conductors: one row of two equal cells with 28 dp badges', (
      tester,
    ) async {
      final h = harnessFor(
        liveTrain().copyWith(
          conductors: [
            conductor(HtSource.subs, 'giver', {'TIER_1_GIFTED_SUB': 5}),
          ],
        ),
      );
      await pumpSheet(tester, h.store);

      final row = find.byKey(const ValueKey('ht-conductors'));
      final cells = find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('ht-conductor-subs') ||
            w.key == const ValueKey('ht-conductor-bits'),
      );
      expect(find.descendant(of: row, matching: cells), findsNWidgets(2));
      expect(tester.widget(cells.first), isA<Expanded>());
      final badges = find.byKey(const ValueKey('ht-conductor-badge'));
      expect(badges, findsNWidgets(2));
      for (final badge in badges.evaluate()) {
        expect(badge.size, const Size(28, 28));
      }
      expect(
        tester.getSize(cells.first).width,
        closeTo(tester.getSize(cells.last).width, 0.5),
      );
      expect(
        tester
            .widget<Text>(find.text('giver has contributed 5 Subs!'))
            .style
            ?.fontSize,
        12,
      );
      await h.close(tester);
    });

    testWidgets('rewards: 28 dp emotes with a 9 dp lock, centred', (
      tester,
    ) async {
      final h = harnessFor(withRewards(liveTrain()));
      await pumpSheet(tester, h.store);

      final rewards = find.byKey(const ValueKey('ht-reward'));
      expect(rewards, findsNWidgets(2));
      expect(tester.getSize(rewards.first), const Size(28, 28));
      final lock = find.byKey(const ValueKey('ht-reward-lock'));
      expect(tester.getSize(lock.first), const Size(9, 9));
      expect(
        tester.getBottomRight(lock.first),
        tester.getBottomRight(rewards.first),
      );
      final sheet = tester.getRect(find.byType(HypeTrainSheet));
      expect(
        tester.getCenter(find.text('Level 7 emotes')).dx,
        closeTo(sheet.center.dx, 0.5),
      );
      final gap =
          tester.getTopLeft(rewards.last).dx -
          tester.getTopRight(rewards.first).dx;
      expect(gap, closeTo(16, 0.5));
      await h.close(tester);
    });

    testWidgets('the variant card: 1 dp border, radius 4', (tester) async {
      final h = harnessFor(
        liveTrain(
          level: 2,
          treasure: const HtTreasure(
            discountPercentage: 50,
            threshold: 3,
            status: HtUnlockStatus.none,
          ),
        ),
      );
      await pumpSheet(tester, h.store);

      final card =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('ht-variant-card')),
                  )
                  .decoration
              as BoxDecoration;
      expect(card.borderRadius, BorderRadius.circular(4));
      expect((card.border! as Border).top.width, 1);
      expect(card.color, const Color(0xFFEFEFF1));
      final title = tester.widget<Text>(find.text('Treasure Train'));
      expect(title.style?.fontSize, 16);
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(find.textContaining('learn more'), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('the record line is centred with a trophy', (tester) async {
      final h = harnessFor(
        liveTrain(total: 5000).copyWith(
          ath: const HtAth(level: 9, goal: 0, progression: 0, total: 10000),
        ),
      );
      await pumpSheet(tester, h.store);

      final record = find.textContaining(
        'Channel all-time record! 50% Level 9',
      );
      expect(record, findsOneWidget);
      expect(
        tester.getCenter(record).dx,
        closeTo(tester.getCenter(find.byType(HypeTrainSheet)).dx, 0.5),
      );
      expect(
        find.descendant(
          of: record,
          matching: find.byIcon(Icons.emoji_events_rounded),
        ),
        findsOneWidget,
      );
      await h.close(tester);
    });

    testWidgets('shared trains list their contributions', (tester) async {
      final h = harnessFor(
        liveTrain(
          shared: HtShared(
            id: 's',
            channels: [
              for (final id in ['a', 'b'])
                HtSharedChannel(user: user(id), progress: progress(total: 50)),
            ],
          ),
        ),
      );
      await pumpSheet(tester, h.store);

      expect(find.text('CONTRIBUTIONS'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2));
      await h.close(tester);
    });

    testWidgets('approaching: the question, two lines and a 3 dp bar', (
      tester,
    ) async {
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

      expect(
        tester
            .widget<Text>(find.text('What is a Hype Train?'))
            .style
            ?.fontWeight,
        FontWeight.w600,
      );
      expect(find.text('Level 1 emotes'), findsOneWidget);
      final bar = find.byKey(const ValueKey('ht-approaching-details-bar'));
      expect(tester.getSize(bar).height, 3);
      expect(
        tester.widget<LinearProgressIndicator>(bar).backgroundColor,
        const Color(0x14000000),
      );
      await h.close(tester);
    });
  });
}
