import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/chat/widgets/prediction_dialogs.dart';

import '../../../../helpers/l10n.dart';

void main() {
  final french = lookupAppLocalizations(fr);

  Future<void> open(
    WidgetTester tester,
    Widget dialog, {
    Size size = const Size(360, 640),
  }) async {
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showDialog<bool>(context: context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: size,
      textScale: 1.3,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void expectOnScreen(WidgetTester tester, Key key) {
    final rect = tester.getRect(find.byKey(key));
    expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(
      tester
              .hitTestOnBinding(rect.center)
              .path
              .any(
                (entry) => entry.target == tester.renderObject(find.byKey(key)),
              ) ||
          find.byKey(key).hitTestable().evaluate().isNotEmpty,
      isTrue,
    );
  }

  for (final stake in [0, 2500]) {
    testWidgets('the terms dialog keeps its buttons in sight, stake $stake', (
      tester,
    ) async {
      await open(
        tester,
        PredictionTermsDialog(
          outcome: 'Victoire de l’équipe bleue au prochain round',
          stake: stake,
          stakeLabel: '2 500',
          pointsName: french.predictionPointsFallback,
          restriction: PredictionRestriction.categoryLocked,
        ),
      );
      expect(
        find.byKey(PredictionTermsDialog.acceptKey).hitTestable(),
        findsOneWidget,
      );
      expectOnScreen(tester, PredictionTermsDialog.acceptKey);
    });
  }

  testWidgets('the moderator dialog keeps its buttons in sight', (
    tester,
  ) async {
    await open(
      tester,
      const PredictionModeratorDialog(
        creator: PredictionCreator.other,
        creatorName: 'UnTrèsLongNomDeModérateur',
      ),
    );
    expect(
      find.byKey(PredictionModeratorDialog.acceptKey).hitTestable(),
      findsOneWidget,
    );
    expectOnScreen(tester, PredictionModeratorDialog.acceptKey);
  });

  testWidgets('on a short window the text scrolls and the buttons stay', (
    tester,
  ) async {
    await open(
      tester,
      PredictionTermsDialog(
        outcome: 'Victoire',
        stake: 0,
        stakeLabel: '0',
        pointsName: french.predictionPointsFallback,
        restriction: PredictionRestriction.regionLocked,
      ),
      size: const Size(360, 420),
    );
    expect(
      find.byKey(PredictionTermsDialog.acceptKey).hitTestable(),
      findsOneWidget,
    );
    expectOnScreen(tester, PredictionTermsDialog.acceptKey);
  });
}
