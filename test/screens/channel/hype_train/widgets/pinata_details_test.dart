import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/pinata.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';

import '../../../../helpers/l10n.dart';

void main() {
  testWidgets('the piñata card fits a small phone at double text size', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PinataDetails(
            load: () async =>
                const PinataState(stage: 3, isEligibleForRewards: true),
          ),
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pinata-card')), findsOneWidget);
  });

  testWidgets('at normal text size the stage sits at the end of the row', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PinataDetails(
            load: () async =>
                const PinataState(stage: 3, isEligibleForRewards: true),
          ),
        ),
      ),
      locale: en,
    );
    await tester.pump();
    final stage = find.text('Damage stage 3');
    final title = find.text('Piñata train');
    final row = find.ancestor(of: stage, matching: find.byType(Row)).first;
    expect(tester.getRect(stage).right, tester.getRect(row).right);
    expect(
      tester.getRect(title).right,
      lessThanOrEqualTo(tester.getRect(stage).left - 8),
    );
    expect(
      tester
              .getRect(
                find
                    .ancestor(of: title, matching: find.byType(Semantics))
                    .first,
              )
              .right +
          8,
      tester.getRect(stage).left,
    );
  });
}
