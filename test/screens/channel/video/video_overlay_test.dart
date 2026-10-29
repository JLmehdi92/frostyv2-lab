import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/video/latency_pill.dart';
import 'package:frosty/screens/channel/video/video_overlay.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_player.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockChatStore extends Mock implements ChatStore {}

void main() {
  late MockTwitchApi api;
  late MockChatStore chat;

  setUp(() {
    api = MockTwitchApi();
    when(() => api.getUser(userLogin: any(named: 'userLogin'))).thenAnswer(
      (_) async => const UserTwitch('42', 'streamer', 'Streamer', ''),
    );
    chat = MockChatStore();
    when(() => chat.displayName).thenReturn('Streamer');
    when(() => chat.channelName).thenReturn('streamer');
    when(() => chat.isInSharedChatMode).thenReturn(false);
  });

  /// The overlay over a [width] × [height] player on a [screen].
  Future<void> pump(
    WidgetTester tester,
    FakePlayer player, {
    required Size screen,
    required Size video,
    bool dark = true,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      Provider<TwitchApi>.value(
        value: api,
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: video,
                child: ColoredBox(
                  color: Colors.black,
                  child: VideoOverlay(
                    videoStore: player,
                    chatStore: chat,
                    settingsStore: player.settingsStore,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Unmounts, so the uptime's shared clock stops.
  Future<void> done(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  group('phone portrait (board ChaineLecteur)', () {
    testWidgets('has every control of the live player, without overflow', (
      tester,
    ) async {
      final player = FakePlayer(stream: fakeStream());
      for (final dark in [true, false]) {
        await pump(
          tester,
          player,
          screen: const Size(390, 844),
          video: const Size(390, 220),
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        for (final tip in [
          'Back',
          'Clip',
          'Videos',
          'Quality and settings',
          'Pause',
          'Stream uptime',
          'Viewer count',
          'Enter picture-in-picture',
          'Refresh',
          'Enter landscape mode',
          'Channel profile',
        ]) {
          expect(find.byTooltip(tip), findsOneWidget, reason: tip);
        }
        // Landscape-only controls stay out of the portrait player.
        for (final tip in [
          'Show chat overlay',
          'Hide chat overlay',
          'Enter fullscreen mode',
          'Hide chat',
        ]) {
          expect(find.byTooltip(tip), findsNothing, reason: tip);
        }
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.text('Streamer'), findsOneWidget);
        expect(find.text('ON TEST DOTA 2 AVEC @befreesh'), findsOneWidget);
      }
      await done(tester);
    });

    testWidgets('keeps room for the latency pill, which it does not draw', (
      tester,
    ) async {
      final player = FakePlayer(stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(390, 844),
        video: const Size(390, 220),
      );
      // Room for the pill the channel screen draws over this spot (it never
      // hides with the controls), without a second pill.
      expect(find.byType(LatencyPill), findsNothing);
      final slot = find.byKey(VideoOverlay.latencySlotKey);
      final metrics = PlayerChromeMetrics.of(tester.element(slot));
      final rect = tester.getRect(slot);
      expect(rect.right, closeTo(390 - metrics.pillEdge, 0.01));
      expect(rect.width, LatencyPill.slotWidth(tester.element(slot)));
      final settings = tester.getRect(find.byTooltip('Quality and settings'));
      expect(
        settings.right + PlayerChromeMetrics.pillGap,
        closeTo(rect.left, 0.01),
      );

      // The widest label fits in the room kept for it.
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: LatencyPill(store: FakePlayer(latency: '188.8s')),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(LatencyPill)).width,
        lessThanOrEqualTo(rect.width + 0.5),
      );
      await pump(
        tester,
        player,
        screen: const Size(390, 844),
        video: const Size(390, 220),
      );

      player.settingsStore.showLatency = false;
      await tester.pump();
      expect(find.byKey(VideoOverlay.latencySlotKey), findsNothing);
      await done(tester);
    });

    testWidgets('play and pause go to the player', (tester) async {
      final player = FakePlayer(stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(390, 844),
        video: const Size(390, 220),
      );
      await tester.tap(find.byTooltip('Pause'));
      expect(player.calls, contains('pausePlay'));

      player.paused = true;
      await tester.pump();
      expect(find.byTooltip('Play'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.tap(find.byTooltip('Enter picture-in-picture'));
      expect(player.calls, containsAll(['refresh', 'togglePip']));
      await done(tester);
    });

    testWidgets('offline: past broadcasts, videos, refresh', (tester) async {
      final player = FakePlayer(offline: fakeOfflineChannel);
      await pump(
        tester,
        player,
        screen: const Size(390, 844),
        video: const Size(390, 220),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Past broadcasts'), findsOneWidget);
      expect(find.byTooltip('Videos'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.byType(LatencyPill), findsNothing);
      await done(tester);
    });
  });

  testWidgets('a small phone and an overlay beside the chat do not overflow', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({})
      ..fullScreen = true
      ..fullScreenChatOverlay = true;
    final player = FakePlayer(settings: settings, stream: fakeStream());
    for (final (screen, video) in [
      (const Size(320, 640), const Size(320, 180)),
      // The chat overlay takes 30 % of an 844 dp landscape phone.
      (const Size(844, 390), const Size(591, 390)),
    ]) {
      await pump(tester, player, screen: screen, video: video);
      expect(tester.takeException(), isNull, reason: '$screen');
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    }
    await done(tester);
  });

  group('phone landscape full screen (board ChaineLecteur)', () {
    testWidgets('adds the chat overlay toggle and full screen', (tester) async {
      final settings = SettingsStore.fromJson({})
        ..fullScreen = true
        ..fullScreenChatOverlay = true;
      final player = FakePlayer(settings: settings, stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(844, 390),
        video: const Size(844, 390),
      );
      expect(tester.takeException(), isNull);
      for (final tip in [
        'Hide chat overlay',
        'Exit fullscreen mode',
        'Exit landscape mode',
        'Enter picture-in-picture',
        'Refresh',
        'Quality and settings',
      ]) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
      // Only a tablet's side chat has its own hide control.
      expect(find.byTooltip('Hide chat'), findsNothing);

      await tester.tap(find.byTooltip('Hide chat overlay'));
      await tester.pump();
      expect(settings.fullScreenChatOverlay, isFalse);
      expect(find.byTooltip('Show chat overlay'), findsOneWidget);
      await done(tester);
    });
  });

  group('the category stays one double tap away in landscape', () {
    /// The category's text, and whether a double tap opens its streams.
    bool linked(WidgetTester tester, String text) {
      final detector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      return detector.onDoubleTap != null;
    }

    for (final (label, screen, video, fullScreen) in [
      (
        'phone beside its chat',
        const Size(844, 390),
        const Size(591, 390),
        false,
      ),
      ('phone full screen', const Size(844, 390), const Size(844, 390), true),
      (
        'tablet full screen',
        const Size(1280, 854),
        const Size(1280, 854),
        true,
      ),
      (
        'tablet beside its chat',
        const Size(1280, 854),
        const Size(880, 495),
        false,
      ),
    ]) {
      testWidgets(label, (tester) async {
        final settings = SettingsStore.fromJson({})..fullScreen = fullScreen;
        final player = FakePlayer(settings: settings, stream: fakeStream());
        await pump(tester, player, screen: screen, video: video);
        expect(tester.takeException(), isNull);
        expect(find.text('Dota 2'), findsOneWidget);
        expect(linked(tester, 'Dota 2'), isTrue);
        await done(tester);
      });
    }

    testWidgets('offline too', (tester) async {
      final player = FakePlayer(offline: fakeOfflineChannel);
      await pump(
        tester,
        player,
        screen: const Size(844, 390),
        video: const Size(844, 390),
      );
      expect(find.text('Dota 2'), findsOneWidget);
      expect(linked(tester, 'Dota 2'), isTrue);
      await done(tester);
    });

    testWidgets('not in portrait: the info under the video has it', (
      tester,
    ) async {
      final player = FakePlayer(stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(390, 844),
        video: const Size(390, 220),
      );
      expect(find.text('Dota 2'), findsNothing);
      await done(tester);
    });
  });

  group('tablet (boards Tablette, TablettePortrait)', () {
    testWidgets('beside the chat: the category, and "Hide chat"', (
      tester,
    ) async {
      final settings = SettingsStore.fromJson({})..fullScreen = false;
      final player = FakePlayer(settings: settings, stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(1280, 854),
        video: const Size(880, 495),
      );
      expect(tester.takeException(), isNull);
      // The category stands under the name; the title is below the video.
      expect(find.text('Dota 2'), findsOneWidget);
      expect(find.text('ON TEST DOTA 2 AVEC @befreesh'), findsNothing);

      await tester.tap(find.byTooltip('Hide chat'));
      await tester.pump();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);

      // And back to the side chat.
      await tester.tap(find.byTooltip('Show chat'));
      await tester.pump();
      expect(settings.fullScreen, isFalse);
      await done(tester);
    });

    testWidgets('in portrait the channel is under the video, not over it', (
      tester,
    ) async {
      final player = FakePlayer(stream: fakeStream());
      await pump(
        tester,
        player,
        screen: const Size(854, 1280),
        video: const Size(854, 480),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Channel profile'), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      await done(tester);
    });
  });
}
