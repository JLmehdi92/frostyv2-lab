import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
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
        find.text(VodErrorView.messageFor(problem, L10n.english)),
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
      find.text('This video is available only to subscribers.'),
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
          subject: PlaybackSubject.clip,
        ),
      ),
    );

    expect(find.text('This clip is no longer available.'), findsOneWidget);
    expect(
      VodErrorView.messageFor(VodPlaybackProblem.notFound, L10n.english),
      'This video is no longer available.',
    );
  });

  test('French words a video and a clip each its own way', () {
    final french = lookupAppLocalizations(const Locale('fr'));
    String message(VodPlaybackProblem problem, PlaybackSubject subject) =>
        VodErrorView.messageFor(problem, french, subject: subject);
    expect(
      VodErrorView.messageFor(VodPlaybackProblem.notFound, french),
      'Cette vidéo n’est plus disponible',
    );
    expect(
      message(VodPlaybackProblem.notFound, PlaybackSubject.clip),
      'Ce clip n’est plus disponible',
    );
    // Every subject is a branch of every message, in both languages: a
    // subject the ARB files miss would fall back to the video's words.
    for (final l in [L10n.english, french]) {
      for (final problem in VodPlaybackProblem.values) {
        expect(
          VodErrorView.messageFor(problem, l, subject: PlaybackSubject.clip),
          isNot(VodErrorView.messageFor(problem, l)),
          reason: '${l.localeName} ${problem.name}',
        );
      }
    }
  });

  testWidgets('a subscriber-only video offers to subscribe', (tester) async {
    var subscribes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VodErrorView(
            problem: VodPlaybackProblem.subscriberOnly,
            onSubscribe: () => subscribes++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Subscribe'));
    expect(subscribes, 1);
  });

  testWidgets('no subscribe button for other problems or without a channel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VodErrorView(
            problem: VodPlaybackProblem.notFound,
            onSubscribe: () {},
          ),
        ),
      ),
    );
    expect(find.text('Subscribe'), findsNothing);

    await pump(tester, VodPlaybackProblem.subscriberOnly);
    expect(find.text('Subscribe'), findsNothing);
  });
}
