import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/models/pinata.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/weekly_rewards.dart';
import 'package:onset/screens/channel/chat/widgets/prediction_dialogs.dart';
import 'package:onset/screens/channel/chat/widgets/viewer_rewards.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';

import '../fixtures/legendary_payloads.dart';
import '../fixtures/pinata_payloads.dart';
import '../fixtures/weekly_rewards_payloads.dart';
import '../helpers/l10n.dart';

void main() {
  final french = lookupAppLocalizations(fr);

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      for (final stake in [0, 2500]) {
        testWidgets('the prediction terms, stake $stake, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: PredictionTermsDialog(
                outcome: 'Victoire',
                stake: stake,
                stakeLabel: stake == 0 ? '0' : '2 500',
                pointsName: french.predictionPointsFallback,
                restriction: stake == 0
                    ? PredictionRestriction.categoryLocked
                    : PredictionRestriction.none,
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          expect(find.text(french.predictionTermsLink), findsOneWidget);
          await expectFrenchThroughout(
            tester,
            'prediction terms $stake, $at',
            content: const ['Victoire'],
          );
        });
      }

      for (final earned in [false, true]) {
        testWidgets('the weekly rewards, earned $earned, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  spacing: 12,
                  children: [
                    WeeklyRewardsCard(
                      rewards: WeeklyRewards.fromBody(
                        weeklyRewardsResponse(earned: earned),
                      )!,
                    ),
                    CommunityMomentCard(onClaim: () {}),
                  ],
                ),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          expect(find.text(french.weeklyRewardsTitle), findsOneWidget);
          expect(find.text(french.momentCardTitle), findsOneWidget);
          await expectFrenchThroughout(tester, 'weekly $earned, $at');
        });
      }

      for (final type in [
        'CHOSEN_SUB_EMOTE_UNLOCK',
        'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK',
      ]) {
        testWidgets('the emote picker, $type, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: EmoteUnlockSheet(
                reward: PointsReward(
                  id: 'r',
                  title: 'r',
                  cost: 5000,
                  automaticType: type,
                ),
                load: () async =>
                    UnlockableEmote.listFrom(unlockableEmotesResponse),
                onUnlock: (_) {},
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(EmoteUnlockSheet.emoteKey('301')));
          await tester.pump();
          await expectFrenchThroughout(
            tester,
            'emote picker $type, $at',
            content: const [
              'chanGg_BW',
              'chanGg_HF',
              'chanGg_SG',
              'chanGg_SQ',
              'chanGg_TK',
              'chanGg',
              'chanHi',
            ],
          );
        });
      }

      testWidgets('the hype chests, $at', (tester) async {
        final collection = LegendaryCollection.fromBody(
          legendarySeasonResponse(),
        )!;
        await pumpLocalized(
          tester,
          Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: HypeChestsCard(
                    collection: collection,
                    onSeeCollection: () {},
                  ),
                ),
                Expanded(child: HypeChestsSheet(collection: collection)),
              ],
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.hypeChestsSeeCollection), findsOneWidget);
        await expectFrenchThroughout(
          tester,
          'hype chests, $at',
          content: const ['Winter Chests'],
        );
      });

      for (final eligible in [true, false]) {
        testWidgets('the piñata, eligible $eligible, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: PinataDetails(
                load: () async =>
                    PinataState.fromBody(pinataResponse(eligible: eligible)),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          expect(find.text(french.pinataTitle), findsOneWidget);
          await expectFrenchThroughout(tester, 'piñata $eligible, $at');
        });
      }

      testWidgets('the moderator step, $at', (tester) async {
        await pumpLocalized(
          tester,
          const Scaffold(
            body: PredictionModeratorDialog(
              creator: PredictionCreator.other,
              creatorName: 'Modo',
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.predictionModeratorTitle), findsOneWidget);
        await expectFrenchThroughout(
          tester,
          'moderator step, $at',
          content: const ['Modo'],
        );
      });
    }
  }
}
