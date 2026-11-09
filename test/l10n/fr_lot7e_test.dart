import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/chat/widgets/prediction_dialogs.dart';

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
