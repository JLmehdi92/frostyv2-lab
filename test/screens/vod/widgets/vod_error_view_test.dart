import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/vod/widgets/vod_error_view.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    VodPlaybackProblem problem, {
    VoidCallback? onRetry,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VodErrorView(problem: problem, onRetry: onRetry),
      ),
    ),
  );

  testWidgets('each problem has its message', (tester) async {
    for (final problem in VodPlaybackProblem.values) {
      await pump(tester, problem);
      expect(
        find.text(VodErrorView.messageFor(problem)),
        findsOneWidget,
        reason: problem.name,
      );
    }
  });

  testWidgets('only a temporary problem offers a retry', (tester) async {
    var retries = 0;
    await pump(tester, VodPlaybackProblem.unknown, onRetry: () => retries++);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(retries, 1);

    await pump(
      tester,
      VodPlaybackProblem.subscriberOnly,
      onRetry: () => retries++,
    );
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });
}
