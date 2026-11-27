import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/vod/widgets/go_to_time_dialog.dart';

import '../../../helpers/l10n.dart';

void main() {
  Future<Future<Duration?>> open(
    WidgetTester tester, {
    required Duration length,
  }) async {
    late Future<Duration?> result;
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => result = showGoToTimeDialog(
              context,
              position: Duration.zero,
              length: length,
            ),
            child: const Text('open'),
          ),
        ),
      ),
      locale: en,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the keyboard’s Done goes to the time typed', (tester) async {
    final result = await open(tester, length: const Duration(hours: 1));
    await tester.enterText(find.byType(TextField), '12:30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(await result, const Duration(minutes: 12, seconds: 30));
  });

  testWidgets('a video whose length is unknown takes any time', (tester) async {
    final result = await open(tester, length: Duration.zero);
    await tester.enterText(find.byType(TextField), '12:30');
    await tester.pump();
    final l = lookupAppLocalizations(en);
    expect(
      find.textContaining(l.vodGoToTimeInvalid(end: '0:00')),
      findsNothing,
    );
    await tester.tap(find.text(l.vodGoToTimeGo));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(await result, const Duration(minutes: 12, seconds: 30));
  });

  testWidgets('a time past the end is refused', (tester) async {
    await open(tester, length: const Duration(minutes: 10));
    await tester.enterText(find.byType(TextField), '12:30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
