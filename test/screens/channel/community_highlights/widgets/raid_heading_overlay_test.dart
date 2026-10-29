import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/raid_arrival.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/raid_avatar.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/raid_heading_overlay.dart';

final _arrival = RaidArrival(
  fromName: 'Nisqyy',
  targetName: 'Splinter',
  viewers: 1204,
  at: DateTime.utc(2026, 10, 28, 20),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool leaving,
    Size video = const Size(390, 220),
    bool reduceMotion = false,
    VoidCallback? onDone,
    VoidCallback? onTapVideo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: video,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: onTapVideo,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                  Positioned.fill(
                    child: RaidHeadingOverlay(
                      arrival: _arrival,
                      leaving: leaving,
                      onDone: onDone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(RaidHeadingOverlay.scrimKey),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  testWidgets('leaving: after the hit, "Heading to" fades in over the video', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, leaving: true, onTapVideo: () => taps++);
    expect(find.byKey(RaidHeadingOverlay.scrimKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(RaidHeadingOverlay.scrimKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(opacityOf(tester), 1);
    expect(find.text('Heading to Splinter'), findsOneWidget);
    expect(find.text('1,204 viewers coming with you'), findsOneWidget);
    expect(find.byType(RaidAvatar), findsOneWidget);
    // Opaque, never a blur over the video, and it takes no tap.
    expect(find.byType(BackdropFilter), findsNothing);
    final scrim = tester.widget<ColoredBox>(
      find.byKey(RaidHeadingOverlay.scrimKey),
    );
    expect(scrim.color.a, closeTo(0.9, 0.01));
    await tester.tapAt(const Offset(195, 110));
    expect(taps, 1);
  });

  for (final video in const [Size(390, 220), Size(832, 468), Size(854, 480)]) {
    testWidgets('fits a ${video.width.toInt()} dp video', (tester) async {
      await pump(tester, leaving: true, video: video);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Heading to Splinter'), findsOneWidget);
    });
  }

  testWidgets('arriving: shown, then fades and says so once', (tester) async {
    var done = 0;
    await pump(tester, leaving: false, onDone: () => done++);
    expect(opacityOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(tester), lessThan(1));
    expect(done, 0);
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(find.byKey(RaidHeadingOverlay.scrimKey), findsNothing);
  });

  testWidgets('reduce motion: a short fade, nothing moves', (tester) async {
    await pump(tester, leaving: true, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 75));
    expect(find.text('Heading to Splinter'), findsOneWidget);
    final scale = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byType(RaidAvatar),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
