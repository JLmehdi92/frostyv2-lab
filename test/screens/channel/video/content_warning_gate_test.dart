import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/screens/channel/video/content_warning_gate.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

Channel _channel(List<String> labels) => Channel(
  broadcasterId: '1',
  broadcasterLogin: 'streamer',
  broadcasterName: 'Streamer',
  broadcasterLanguage: 'en',
  title: 'Title',
  gameId: '1',
  gameName: 'Game',
  contentClassificationLabels: labels,
);

void main() {
  late MockTwitchApi api;
  late SettingsStore settings;
  final active = <bool>[];

  setUp(() {
    AcceptedContentWarnings.reset();
    active.clear();
    api = MockTwitchApi();
    settings = SettingsStore.fromJson({});
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TwitchApi>.value(value: api),
        Provider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ContentWarningGate(
            userId: '1',
            displayName: 'Streamer',
            onActiveChanged: active.add,
            child: const Text('VIDEO'),
          ),
        ),
      ),
    ),
  );

  testWidgets('a labeled channel is covered until accepted', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel(['SexualThemes']));

    await pump(tester);
    await tester.pump();

    expect(find.text('Start watching'), findsOneWidget);
    expect(find.textContaining('Sexual Themes'), findsOneWidget);

    await tester.tap(find.text('Start watching'));
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(AcceptedContentWarnings.has('1'), isTrue);
    // The channel is told to pause while covered, then resume on accept.
    expect(active, [true, false]);
  });

  testWidgets('no labels, no warning', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel([]));
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(active, isEmpty);
  });

  testWidgets('already accepted this session: never asks again', (
    tester,
  ) async {
    AcceptedContentWarnings.add('1');
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    verifyNever(() => api.getChannel(userId: any(named: 'userId')));
  });

  testWidgets('with the setting off, it never fetches or warns', (
    tester,
  ) async {
    settings.warnMatureContent = false;
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    verifyNever(() => api.getChannel(userId: any(named: 'userId')));
  });

  testWidgets('a failed fetch plays instead of blocking', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenThrow(const ApiException('offline'));
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(find.text('VIDEO'), findsOneWidget);
  });

  group('ContentWarningCover', () {
    testWidgets("reads like the official app's warning", (tester) async {
      var accepted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentWarningCover(
              displayName: 'Streamer',
              labels: const ['Mature-Rated Game', 'Gambling'],
              onAccept: () => accepted++,
            ),
          ),
        ),
      );

      expect(find.text('Just one second…'), findsOneWidget);
      expect(
        find.text("Streamer's content is intended for certain audiences."),
        findsOneWidget,
      );
      expect(
        find.text('It may contain: Mature-Rated Game, Gambling'),
        findsOneWidget,
      );
      await tester.tap(find.text('Start watching'));
      expect(accepted, 1);
    });

    testWidgets('go back leaves the screen it covers', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('HOME')),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: ContentWarningCover(
                displayName: '',
                labels: const ['Gambling'],
                onAccept: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This content is intended for certain audiences.'),
        findsOneWidget,
        reason: 'no name: the fallback wording',
      );

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('contentWarningConsented', () {
    test("twitch's warning is the viewer's to tap unless they chose", () {
      expect(
        contentWarningConsented(warnMatureContent: true, channelId: '1'),
        isFalse,
      );
      expect(
        contentWarningConsented(warnMatureContent: false, channelId: '1'),
        isTrue,
        reason: 'warnings turned off',
      );
      AcceptedContentWarnings.add('1');
      expect(
        contentWarningConsented(warnMatureContent: true, channelId: '1'),
        isTrue,
        reason: 'accepted this session',
      );
      expect(
        contentWarningConsented(warnMatureContent: true, channelId: '2'),
        isFalse,
      );
      expect(
        contentWarningConsented(warnMatureContent: true, channelId: ''),
        isFalse,
      );
    });
  });

  testWidgets('the cover fits a phone player, both buttons on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 390,
              height: 220,
              child: ContentWarningCover(
                displayName: 'Streamer',
                labels: const [
                  'Significant Profanity or Vulgarity',
                  'Gambling',
                ],
                onAccept: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final button in ['Start watching', 'Go back']) {
      final rect = tester.getRect(find.text(button));
      expect(rect.bottom, lessThanOrEqualTo(220), reason: button);
    }
  });
}
