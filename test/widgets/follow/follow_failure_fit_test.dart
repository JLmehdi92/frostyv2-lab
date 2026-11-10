import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:provider/provider.dart';

import '../../helpers/l10n.dart';

class _MockActions extends Mock implements FollowActions {}

void main() {
  const failures = [
    FollowResult.noWebSession,
    FollowResult.signedOut,
    FollowResult.mintTimeout,
    FollowResult.mintFailed,
    FollowResult.integrityRefused,
    FollowResult.gqlError,
    FollowResult.failed,
  ];

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
          '${locale.languageCode} $name ×$scale: every follow failure reads '
          'whole, with its action',
          (tester) async {
            final actions = _MockActions();
            var signedIn = true;
            var failure = failures.first;
            when(() => actions.isSignedIn).thenAnswer((_) => signedIn);
            when(() => actions.canFollowInApp).thenReturn(true);
            when(
              () => actions.connectWebSession(),
            ).thenAnswer((_) async => true);
            when(
              () => actions.followChannel(any()),
            ).thenAnswer((_) async => failure);
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
                      ),
                      child: const Text('go'),
                    ),
                  ),
                ),
              ),
              locale: locale,
              size: size,
              textScale: scale,
              wrap: (app) =>
                  Provider<FollowActions?>.value(value: actions, child: app),
            );

            Future<void> check(String what) async {
              await tester.tap(find.text('go'));
              await tester.pumpAndSettle();
              final where = '${locale.languageCode} $name ×$scale $what';
              expect(
                find.byType(SnackBarAction),
                what == FollowResult.integrityRefused.name
                    ? findsNothing
                    : findsOneWidget,
                reason: where,
              );
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
            }

            for (final next in failures) {
              failure = next;
              await check(next.name);
            }
            signedIn = false;
            await check('signed out');
          },
        );
      }
    }
  }
}
