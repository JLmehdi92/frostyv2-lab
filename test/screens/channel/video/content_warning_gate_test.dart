import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/screens/channel/video/content_warning_gate.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_player.dart';

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
  final states = <ContentGate>[];

  setUp(() {
    AcceptedContentWarnings.reset();
    states.clear();
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
            onStateChanged: states.add,
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
    // The channel is told to hold the player while covered, then to let
    // it go on accept.
    expect(states, [
      ContentGate.pending,
      ContentGate.covering,
      ContentGate.clear,
    ]);
  });

  testWidgets('no labels, no warning', (tester) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel([]));
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    // Said all the same: a player held by an earlier warning goes free.
    expect(states, [ContentGate.pending, ContentGate.clear]);
  });

  testWidgets('already accepted this session: never asks again', (
    tester,
  ) async {
    AcceptedContentWarnings.add('1');
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(states, [ContentGate.clear]);
    verifyNever(() => api.getChannel(userId: any(named: 'userId')));
  });

  testWidgets('with the setting off, it never fetches or warns', (
    tester,
  ) async {
    settings.warnMatureContent = false;
    await pump(tester);
    await tester.pump();
    expect(find.text('Start watching'), findsNothing);
    expect(states, [ContentGate.clear]);
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
    expect(states, [ContentGate.pending, ContentGate.clear]);
  });

  testWidgets('pending while the labels are read', (tester) async {
    final channel = Completer<Channel>();
    when(() => api.getChannel(userId: '1')).thenAnswer((_) => channel.future);
    await pump(tester);
    await tester.pump();
    expect(states, [ContentGate.pending]);
    channel.complete(_channel(['Gambling']));
    await tester.pump();
    expect(states, [ContentGate.pending, ContentGate.covering]);
  });

  testWidgets('gone (chat only), it says nothing: chat only is not consent', (
    tester,
  ) async {
    when(
      () => api.getChannel(userId: '1'),
    ).thenAnswer((_) async => _channel(['Gambling']));
    await pump(tester);
    await tester.pump();
    expect(states, [ContentGate.pending, ContentGate.covering]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    expect(states, [ContentGate.pending, ContentGate.covering]);
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

  group('one keyed gate across the channel layouts', () {
    final gateKey = GlobalKey();

    /// The channel screen's portrait layout (the gate around the video) or
    /// its full-screen one (the gate around the video and its overlays).
    Widget layout({required bool fullScreen}) => MultiProvider(
      providers: [
        Provider<TwitchApi>.value(value: api),
        Provider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: fullScreen
              ? ContentWarningGate(
                  key: gateKey,
                  userId: '1',
                  displayName: 'Streamer',
                  onStateChanged: states.add,
                  child: const Stack(
                    children: [Text('VIDEO'), Text('CHAT OVERLAY')],
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: ContentWarningGate(
                        key: gateKey,
                        userId: '1',
                        displayName: 'Streamer',
                        onStateChanged: states.add,
                        child: const Text('VIDEO'),
                      ),
                    ),
                    const Expanded(child: Text('CHAT')),
                  ],
                ),
        ),
      ),
    );

    testWidgets('opened in full screen: covered, the player stays paused', (
      tester,
    ) async {
      when(
        () => api.getChannel(userId: '1'),
      ).thenAnswer((_) async => _channel(['Gambling']));
      await tester.pumpWidget(layout(fullScreen: true));
      await tester.pump();
      expect(find.text('Start watching'), findsOneWidget);
      expect(states, [ContentGate.pending, ContentGate.covering]);
    });

    testWidgets('portrait to full screen keeps the cover, asks once', (
      tester,
    ) async {
      when(
        () => api.getChannel(userId: '1'),
      ).thenAnswer((_) async => _channel(['Gambling']));
      await tester.pumpWidget(layout(fullScreen: false));
      await tester.pump();
      expect(find.text('Start watching'), findsOneWidget);

      await tester.pumpWidget(layout(fullScreen: true));
      await tester.pump();
      expect(find.text('Start watching'), findsOneWidget);
      // Neither fetched again nor resumed by the move.
      verify(() => api.getChannel(userId: '1')).called(1);
      expect(states, [ContentGate.pending, ContentGate.covering]);

      // Accepted in full screen, it stays accepted back in portrait.
      await tester.tap(find.text('Start watching'));
      await tester.pump();
      await tester.pumpWidget(layout(fullScreen: false));
      await tester.pump();
      expect(find.text('Start watching'), findsNothing);
      expect(states, [
        ContentGate.pending,
        ContentGate.covering,
        ContentGate.clear,
      ]);
      verifyNoMoreInteractions(api);
    });
  });

  group('the player is never held by a warning that is not there', () {
    /// The channel screen's wiring: the gate drives the player, and chat
    /// only removes the video (and the gate) from the screen.
    Widget screen(FakePlayer player, {required bool video}) => MultiProvider(
      providers: [
        Provider<TwitchApi>.value(value: api),
        Provider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: video
              ? ContentWarningGate(
                  userId: '1',
                  displayName: 'Streamer',
                  onStateChanged: (gate) => player.setContentGate(
                    followContentGate(player.contentGate, gate),
                  ),
                  child: const Text('VIDEO'),
                )
              : const Text('CHAT ONLY'),
        ),
      ),
    );

    for (final (label, reopen) in [
      ('the setting turned off', () => settings.warnMatureContent = false),
      (
        'a failed read',
        () => when(
          () => api.getChannel(userId: '1'),
        ).thenThrow(const ApiException('offline')),
      ),
    ]) {
      testWidgets('covered, chat only, then $label: it plays and leaves', (
        tester,
      ) async {
        when(
          () => api.getChannel(userId: '1'),
        ).thenAnswer((_) async => _channel(['Gambling']));
        final player = FakePlayer();
        await tester.pumpWidget(screen(player, video: true));
        await tester.pump();
        expect(player.contentGate, ContentGate.covering);

        // Chat only is not consent: still held, still kept on the screen.
        await tester.pumpWidget(screen(player, video: false));
        await tester.pump();
        await tester.pump();
        expect(player.contentGate, ContentGate.covering);
        pipPlayPause(player);
        expect(player.calls, isNot(contains('pausePlay')));

        reopen();
        await tester.pumpWidget(screen(player, video: true));
        await tester.pump();
        await tester.pump();
        expect(find.text('Start watching'), findsNothing);
        expect(player.contentGate, ContentGate.clear);
        pipPlayPause(player);
        expect(player.calls, contains('pausePlay'));
      });
    }

    testWidgets('covered, chat only, video again: held while it reads again', (
      tester,
    ) async {
      when(
        () => api.getChannel(userId: '1'),
      ).thenAnswer((_) async => _channel(['Gambling']));
      final player = FakePlayer();
      await tester.pumpWidget(screen(player, video: true));
      await tester.pump();
      await tester.pumpWidget(screen(player, video: false));
      await tester.pump();

      final labels = Completer<Channel>();
      when(() => api.getChannel(userId: '1')).thenAnswer((_) => labels.future);
      player.calls.clear();
      await tester.pumpWidget(screen(player, video: true));
      await tester.pump();
      await tester.pump();
      expect(player.contentGate, ContentGate.covering);
      expect(player.calls, isNot(contains('gate pending')));

      labels.complete(_channel(['Gambling']));
      await tester.pump();
      await tester.pump();
      expect(player.contentGate, ContentGate.covering);
      expect(find.text('Start watching'), findsOneWidget);
    });
  });
}
