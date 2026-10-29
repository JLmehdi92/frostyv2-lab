import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/raid_arrival.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/raid_heading_overlay.dart';

final _arrival = RaidArrival(
  fromName: 'Nisqyy',
  targetName: 'Splinter',
  viewers: 3,
  at: DateTime.utc(2026, 10, 28),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    RaidArrival? departure,
    RaidArrival? arrival,
    bool inPip = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 390,
        height: 220,
        child: RaidOverlayLayer(
          departure: departure,
          arrival: arrival,
          inPip: inPip,
        ),
      ),
    ),
  );

  testWidgets('leaving or arriving, the overlay is over the video', (
    tester,
  ) async {
    await pump(tester, departure: _arrival);
    expect(find.byType(RaidHeadingOverlay), findsOneWidget);
    expect(
      tester
          .widget<RaidHeadingOverlay>(find.byType(RaidHeadingOverlay))
          .leaving,
      isTrue,
    );
    await pump(tester, arrival: _arrival);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RaidHeadingOverlay>(find.byType(RaidHeadingOverlay))
          .leaving,
      isFalse,
    );
  });

  testWidgets('never in the PiP window', (tester) async {
    await pump(tester, departure: _arrival, inPip: true);
    expect(find.byType(RaidHeadingOverlay), findsNothing);
    await pump(tester, arrival: _arrival, inPip: true);
    expect(find.byType(RaidHeadingOverlay), findsNothing);
  });

  testWidgets('a departure called off fades out', (tester) async {
    await pump(tester, departure: _arrival);
    await tester.pump(const Duration(milliseconds: 900));
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // Still fading.
    expect(find.byType(RaidHeadingOverlay), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RaidHeadingOverlay), findsNothing);
  });
}
