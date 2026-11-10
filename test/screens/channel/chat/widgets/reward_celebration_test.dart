import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/screens/channel/chat/widgets/reward_celebration.dart';
import 'package:onset/screens/channel/chat/widgets/viewer_rewards.dart';

import '../../../../helpers/l10n.dart';

const _emotes = [
  LegendaryEmote(id: 'e1', token: 'Wow', tier: 'RARE', isOwned: true),
  LegendaryEmote(id: 'e2', token: 'Yay', tier: 'EPIC', isOwned: true),
];

void main() {
  testWidgets('the bonus burst shows the points, then goes', (tester) async {
    var done = false;
    await pumpLocalized(
      tester,
      Scaffold(
        body: Center(child: PointsBurst(points: 50, onDone: () => done = true)),
      ),
      locale: en,
    );
    await tester.pump();
    expect(find.text('+50'), findsOneWidget);
    expect(find.bySemanticsLabel('Bonus collected: +50'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('with reduced motion the burst still ends', (tester) async {
    var done = false;
    await pumpLocalized(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: PointsBurst(points: 10, onDone: () => done = true),
        ),
      ),
      locale: en,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(done, isTrue);
  });

  testWidgets('the reveal names what is new and closes', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const ChestRevealSheet(revealed: _emotes),
            ),
            child: const Text('go'),
          ),
        ),
      ),
      locale: en,
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('2 new emotes'), findsOneWidget);
    expect(find.bySemanticsLabel('Wow'), findsOneWidget);
    await tester.tap(find.byKey(ChestRevealSheet.doneKey));
    await tester.pumpAndSettle();
    expect(find.byType(ChestRevealSheet), findsNothing);
  });

  testWidgets('an empty reveal says the emotes were already owned', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const Scaffold(body: ChestRevealSheet(revealed: [])),
      locale: en,
    );
    await tester.pumpAndSettle();
    expect(find.text('No new emote this time'), findsOneWidget);
    expect(
      find.text('Your chests held emotes you already own.'),
      findsOneWidget,
    );
  });

  testWidgets('unopened chests open from ONSET', (tester) async {
    var opened = 0;
    await pumpLocalized(
      tester,
      Scaffold(
        body: HypeChestsCard(
          collection: const LegendaryCollection(
            campaignName: 'Season',
            emotes: _emotes,
            unopenedChests: 2,
            freeChests: 2,
          ),
          onSeeCollection: () {},
          onOpen: () => opened++,
        ),
      ),
      locale: en,
    );
    await tester.tap(find.byKey(HypeChestsCard.openKey));
    expect(opened, 1);
    expect(find.text('Open 2 chests'), findsOneWidget);
  });

  testWidgets('while opening, the button waits', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: HypeChestsCard(
          collection: const LegendaryCollection(
            campaignName: 'Season',
            emotes: _emotes,
            unopenedChests: 1,
          ),
          onSeeCollection: () {},
          onOpen: () {},
          opening: true,
        ),
      ),
      locale: en,
    );
    expect(find.text('Opening…'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.byKey(HypeChestsCard.openKey),
    );
    expect(button.onPressed, isNull);
  });

  for (final locale in [fr, en]) {
    for (final (name, size) in const [
      ('320x640', Size(320, 640)),
      ('360x640', Size(360, 640)),
      ('390x844', Size(390, 844)),
      ('844x390', Size(844, 390)),
      ('1024x1366', Size(1024, 1366)),
    ]) {
      for (final scale in frenchTextScales) {
        testWidgets('${locale.languageCode} $name ×$scale: the reveal reads '
            'whole', (tester) async {
          for (final revealed in [_emotes, const <LegendaryEmote>[]]) {
            await pumpLocalized(
              tester,
              Scaffold(body: ChestRevealSheet(revealed: revealed)),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await tester.pumpAndSettle();
            final where = '${locale.languageCode} $name ×$scale';
            expect(tester.takeException(), isNull, reason: where);
            expect(clippedTexts(tester), isEmpty, reason: where);
            expect(ellipsizedTexts(tester), isEmpty, reason: where);
            if (locale == fr) {
              expect(englishLeaks(tester), isEmpty, reason: where);
            }
          }
        });
      }
    }
  }
}
