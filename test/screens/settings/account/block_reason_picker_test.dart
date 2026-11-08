import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/settings/account/block_reason_picker.dart';

import '../../../helpers/l10n.dart';

void main() {
  testWidgets('a reason is picked, and picked again to clear it', (
    tester,
  ) async {
    BlockReason? reason;
    await pumpLocalized(
      tester,
      locale: en,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => BlockReasonPicker(
            selected: reason,
            onSelected: (choice) => setState(() => reason = choice),
          ),
        ),
      ),
    );
    expect(find.text('Reason (optional)'), findsOneWidget);
    await tester.tap(find.text('Spam'));
    await tester.pump();
    expect(reason, BlockReason.spam);
    await tester.tap(find.text('Harassment'));
    await tester.pump();
    expect(reason, BlockReason.harassment);
    await tester.tap(find.text('Harassment'));
    await tester.pump();
    expect(reason, isNull);
  });

  testWidgets('the reasons read in French', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(body: BlockReasonPicker(selected: null, onSelected: (_) {})),
    );
    expect(find.text('Motif (facultatif)'), findsOneWidget);
    expect(englishLeaks(tester), isEmpty);
  });
}
