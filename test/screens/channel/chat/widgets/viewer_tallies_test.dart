import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';

import '../../../../helpers/l10n.dart';

void main() {
  testWidgets('the Bits balance and the gifts, each only when known', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const Scaffold(body: ViewerTallies(bitsBalance: 1250, giftedHere: 25)),
      locale: en,
    );
    expect(find.text('1 250 Bits'), findsOneWidget);
    expect(find.text('25 subs gifted here since you joined'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Scaffold(body: ViewerTallies(giftedHere: 1)),
      locale: en,
    );
    expect(find.byKey(const ValueKey('viewer-bits')), findsNothing);
    expect(find.text('1 sub gifted here since you joined'), findsOneWidget);
  });
}
