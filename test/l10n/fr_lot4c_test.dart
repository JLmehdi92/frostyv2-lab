import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/audience_labels.dart';

import '../helpers/l10n.dart';

void main() {
  final french = lookupAppLocalizations(fr);

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the audience labels over a player, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AudienceLabels(
                  labelIds: const ['Gambling', 'ProfanityVulgarity'],
                  paidPromotion: true,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        expect(find.text(french.audienceLabelPaidPromotion), findsOneWidget);
        await expectFrenchThroughout(tester, 'audience labels, $at');
      });
    }
  }
}
