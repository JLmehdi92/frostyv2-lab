import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/screens/whispers/whisper_actions.dart';

import '../../helpers/l10n.dart';

void main() {
  testWidgets('stopping replies confirms, then reports Twitch’s answer', (
    tester,
  ) async {
    var calls = 0;
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => stopWhisperReplies(
              context,
              name: 'Friend',
              remove: () async {
                calls++;
                return ViewerActionOutcome.done;
              },
            ),
            child: const Text('go'),
          ),
        ),
      ),
      locale: en,
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Stop Friend’s replies?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('whisper-stop-replies-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Done.'), findsOneWidget);
  });
}
