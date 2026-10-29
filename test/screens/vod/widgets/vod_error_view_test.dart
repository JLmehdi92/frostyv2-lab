import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/screens/vod/widgets/vod_error_view.dart';

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

  testWidgets('only a problem that can pass offers a retry', (tester) async {
    var retries = 0;
    await pump(tester, VodPlaybackProblem.unknown, onRetry: () => retries++);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(retries, 1);

    await pump(tester, VodPlaybackProblem.notFound, onRetry: () => retries++);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    await pump(tester, VodPlaybackProblem.geoBlocked, onRetry: () => retries++);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('a video for subscribers reads like the official app', (
    tester,
  ) async {
    var retries = 0;
    await pump(
      tester,
      VodPlaybackProblem.subscriberOnly,
      onRetry: () => retries++,
    );

    expect(
      find.text('This video is only available to subscribers.'),
      findsOneWidget,
    );
    expect(
      find.text('Subscribe now to watch and support this channel.'),
      findsOneWidget,
    );
    // Subscribing (or a renewed web token) opens it: the official app
    // offers a refresh too.
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(retries, 1);
  });

  testWidgets('a clip names itself in the message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VodErrorView(
          problem: VodPlaybackProblem.notFound,
          subject: 'clip',
        ),
      ),
    );

    expect(find.text('This clip is no longer available'), findsOneWidget);
    expect(
      VodErrorView.messageFor(VodPlaybackProblem.notFound),
      'This video is no longer available',
    );
  });
}
