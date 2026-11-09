import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/follow/follow_flow.dart';

import '../../helpers/l10n.dart';

void main() {
  for (final locale in [fr, en]) {
    for (final (name, size) in const [
      ('320x640', Size(320, 640)),
      ('360x640', Size(360, 640)),
      ('390x844', Size(390, 844)),
      ('844x390', Size(844, 390)),
      ('1024x1366', Size(1024, 1366)),
    ]) {
      for (final scale in frenchTextScales) {
        testWidgets(
          '${locale.languageCode} $name ×$scale: the twitch.tv prompt reads '
          'whole',
          (tester) async {
            await pumpLocalized(
              tester,
              Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => FollowFlow.toggle(
                        context,
                        target: FollowTarget.channel,
                        id: '1',
                        name: 'Streamer',
                        following: false,
                        openOnTwitch: () async {},
                      ),
                      child: const Text('go'),
                    ),
                  ),
                ),
              ),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await tester.tap(find.text('go'));
            await tester.pumpAndSettle();

            final where = '${locale.languageCode} $name ×$scale';
            expect(find.byKey(FollowFlow.confirmKey), findsOneWidget);
            expect(tester.takeException(), isNull, reason: where);
            expect(clippedTexts(tester), isEmpty, reason: where);
            expect(ellipsizedTexts(tester), isEmpty, reason: where);
            if (locale == fr) {
              expect(
                englishLeaks(tester).where((text) => text != 'go'),
                isEmpty,
                reason: where,
              );
            }
          },
        );
      }
    }
  }
}
