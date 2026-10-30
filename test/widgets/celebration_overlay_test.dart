import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/hermes_client.dart';
import 'package:onset/widgets/celebration_overlay.dart';
import 'package:onset/widgets/celebrations/particles/celebration_view.dart';
import 'package:provider/provider.dart';

class MockChannelEventsStore extends Mock implements ChannelEventsStore {}

class MockHermesClient extends Mock implements HermesClient {}

class MockPointsService extends Mock implements TwitchPointsService {}

Celebration _celebration({CelebrationArea area = CelebrationArea.everywhere}) =>
    Celebration(
      effect: CelebrationEffect.fireworks,
      area: area,
      intensity: CelebrationIntensity.noice,
      duration: const Duration(seconds: 2),
      eventId: 'gift-1',
    );

void main() {
  late MockChannelEventsStore store;
  late SettingsStore settings;

  setUp(() {
    store = MockChannelEventsStore();
    settings = SettingsStore.fromJson({});
    when(() => store.celebration).thenReturn(_celebration());
    when(() => store.clearCelebration()).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: CelebrationOverlay(store: store)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Alignment alignment(WidgetTester tester) =>
      tester
              .widget<Align>(
                find.descendant(
                  of: find.byType(CelebrationOverlay),
                  matching: find.byType(Align),
                ),
              )
              .alignment
          as Alignment;

  testWidgets('switched off in settings, nothing plays', (tester) async {
    settings.showCelebrations = false;
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(CelebrationOverlay),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('Subtle keeps the video clear (chat says it instead)', (
    tester,
  ) async {
    settings.celebrationsOnVideo = CelebrationsOnVideo.subtle;
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(CelebrationOverlay),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('without a celebration, nothing plays', (tester) async {
    when(() => store.celebration).thenReturn(null);
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(CelebrationOverlay),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('it never takes a tap', (tester) async {
    await pump(tester);

    final ignore = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(CelebrationOverlay),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('it clears itself once, when its time is up', (tester) async {
    await pump(tester);

    await tester.pump(const Duration(milliseconds: 1900));
    verifyNever(() => store.clearCelebration());

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    verify(() => store.clearCelebration()).called(1);

    await tester.pump(const Duration(seconds: 5));
    verifyNever(() => store.clearCelebration());
  });

  testWidgets('a channel closed mid-celebration does not clear it', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    verifyNever(() => store.clearCelebration());
  });

  for (final change in ['Subtle', 'Show celebrations off']) {
    testWidgets('switched to $change mid-celebration, it is cleared, not '
        'kept to replay later', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 500));
      verifyNever(() => store.clearCelebration());

      if (change == 'Subtle') {
        settings.celebrationsOnVideo = CelebrationsOnVideo.subtle;
      } else {
        settings.showCelebrations = false;
      }
      await tester.pump();
      await tester.pump();
      verify(() => store.clearCelebration()).called(1);
      await tester.pump(const Duration(seconds: 5));
      verifyNever(() => store.clearCelebration());
    });
  }

  group('a CHAT celebration lands on the chat', () {
    setUp(
      () => when(
        () => store.celebration,
      ).thenReturn(_celebration(area: CelebrationArea.chat)),
    );

    testWidgets('right of the video by default in landscape', (tester) async {
      await pump(tester, size: const Size(900, 400));

      expect(alignment(tester), Alignment.centerRight);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('left when the chat is on the left', (tester) async {
      settings.landscapeChatLeftSide = true;
      await pump(tester, size: const Size(900, 400));

      expect(alignment(tester), Alignment.centerLeft);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('below the video in portrait', (tester) async {
      await pump(tester);

      expect(alignment(tester), Alignment.bottomCenter);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('reduce motion: a short still flash, then it clears once', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(child: CelebrationOverlay(store: store)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    verifyNever(() => store.clearCelebration());
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    verify(() => store.clearCelebration()).called(1);
    await tester.pump(const Duration(seconds: 5));
    verifyNever(() => store.clearCelebration());
  });

  testWidgets('hidden mid-celebration (TickerMode off), it stops and clears '
      'once instead of waiting to resume', (tester) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, on, _) => TickerMode(
              enabled: on,
              child: Stack(
                children: [
                  Positioned.fill(child: CelebrationOverlay(store: store)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    verifyNever(() => store.clearCelebration());

    enabled.value = false;
    await tester.pump();
    await tester.pump();
    verify(() => store.clearCelebration()).called(1);
    await tester.pump(const Duration(seconds: 5));
    verifyNever(() => store.clearCelebration());
  });

  for (final state in [AppLifecycleState.paused, AppLifecycleState.hidden]) {
    testWidgets('the app sent to the background (${state.name}) ends it '
        'once', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 500));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      await tester.pump();
      verify(() => store.clearCelebration()).called(1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      verifyNever(() => store.clearCelebration());
    });
  }

  testWidgets('it is drawn by ONSET particles, never a Lottie', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(
        of: find.byType(CelebrationOverlay),
        matching: find.byType(CelebrationParticles),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  group('every effect, intensity and area fits every screen', () {
    for (final size in const [
      Size(390, 844),
      Size(1280, 854),
      Size(854, 1280),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        for (final effect in CelebrationEffect.values) {
          for (final intensity in CelebrationIntensity.values) {
            for (final area in CelebrationArea.values) {
              when(() => store.celebration).thenReturn(
                Celebration(
                  effect: effect,
                  area: area,
                  intensity: intensity,
                  duration: const Duration(milliseconds: 900),
                  eventId: '${effect.name}-${intensity.name}-${area.name}',
                ),
              );
              await pump(tester, size: size);
              for (var i = 0; i < 6; i++) {
                await tester.pump(const Duration(milliseconds: 160));
              }
              expect(tester.takeException(), isNull);
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  testWidgets('the long-press preview plays every effect and clears each '
      'one', (tester) async {
    final hermes = MockHermesClient();
    when(() => hermes.dispose()).thenReturn(null);
    final events = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      client: hermes,
      pointsService: MockPointsService(),
    );
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(child: CelebrationOverlay(store: events)),
            ],
          ),
        ),
      ),
    );

    final played = <CelebrationEffect>{};
    for (var i = 0; i < 5; i++) {
      events.playPreviewCelebration();
      played.add(events.celebration!.effect);
      await tester.pump();
      expect(find.byType(CelebrationParticles), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(events.celebration, isNotNull);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(events.celebration, isNull);
      expect(find.byType(CelebrationParticles), findsNothing);
    }
    expect(played, hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a VIDEO celebration lands on the player', (tester) async {
    when(
      () => store.celebration,
    ).thenReturn(_celebration(area: CelebrationArea.video));
    await pump(tester, size: const Size(900, 400));

    expect(alignment(tester), Alignment.centerLeft);
    await tester.pump(const Duration(seconds: 3));
  });
}
