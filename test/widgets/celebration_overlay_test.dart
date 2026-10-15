import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/celebration.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/widgets/celebration_overlay.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockChannelEventsStore extends Mock implements ChannelEventsStore {}

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

  testWidgets('a VIDEO celebration lands on the player', (tester) async {
    when(
      () => store.celebration,
    ).thenReturn(_celebration(area: CelebrationArea.video));
    await pump(tester, size: const Size(900, 400));

    expect(alignment(tester), Alignment.centerLeft);
    await tester.pump(const Duration(seconds: 3));
  });
}
