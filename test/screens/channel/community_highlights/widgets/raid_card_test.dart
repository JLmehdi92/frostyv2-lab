import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/celebrations/onset_rocket.dart';

final _start = DateTime.utc(2026, 10, 13, 20);

RaidState _raid({
  bool gone = false,
  bool cancelled = false,
  DateTime? createdAt,
}) => RaidState(
  OutgoingRaid(
    id: 'r',
    sourceId: '1',
    targetId: '2',
    targetLogin: 'friend',
    targetDisplayName: 'Friend',
    viewerCount: 1204,
    createdAt: createdAt ?? _start,
  ),
  gone: gone,
  cancelled: cancelled,
);

void main() {
  var now = _start;

  setUpAll(() => debugSetRocketArt(File(kRocketAsset).readAsStringSync()));
  tearDownAll(() => debugSetRocketArt(null));
  setUp(() => now = _start);

  Future<void> pump(
    WidgetTester tester,
    RaidCard card, {
    double width = 390,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1280, 1280)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? themes.dark : themes.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width - 24, child: card),
          ),
        ),
      ),
    );
  }

  RaidCard card({
    RaidState? raid,
    VoidCallback? onWatch,
    VoidCallback? onStay,
    VoidCallback? onDismiss,
    VoidCallback? onOpen,
    bool staying = false,
    bool leaving = false,
    bool compact = false,
  }) => RaidCard(
    raid: raid ?? _raid(),
    sourceName: 'Nisqyy',
    now: () => now,
    onWatch: onWatch ?? () {},
    onStay: onStay,
    onDismiss: onDismiss,
    onOpen: onOpen,
    staying: staying,
    leaving: leaving,
    compact: compact,
  );

  testWidgets('who raids whom, viewers, the countdown and Go now', (
    tester,
  ) async {
    var watched = 0;
    await pump(tester, card(onWatch: () => watched++, onStay: () {}));
    expect(find.text('RAID'), findsOneWidget);
    expect(find.text('Nisqyy is raiding Friend', findRichText: true), findsOne);
    expect(
      find.text('1,204 viewers · you go along automatically'),
      findsOneWidget,
    );
    expect(find.text('1:30'), findsOneWidget);
    expect(find.byKey(RaidCard.ringKey), findsOneWidget);
    expect(find.byKey(RaidCard.trackKey), findsOneWidget);

    final go = find.ancestor(
      of: find.text('Go now'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(go).height, 44);
    await tester.tap(go);
    expect(watched, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('the rocket rides the track as the time runs out', (
    tester,
  ) async {
    await pump(tester, card(onStay: () {}));
    await tester.pumpAndSettle();
    final track = tester.getRect(find.byKey(RaidCard.trackKey));
    final atStart = tester.getTopLeft(find.byKey(RaidCard.rocketKey)).dx;
    expect(atStart, closeTo(track.left + 36, 0.5));

    now = _start.add(const Duration(seconds: 45));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('0:45'), findsOneWidget);
    final halfway = tester.getTopLeft(find.byKey(RaidCard.rocketKey)).dx;
    final travel = track.width - 72 - 24;
    expect(halfway - atStart, closeTo(travel * 0.5, 2));
  });

  testWidgets('Stay here, then the staying line keeps Watch', (tester) async {
    var stayed = 0;
    var watched = 0;
    await pump(tester, card(onStay: () => stayed++));
    await tester.tap(find.text('Stay here'));
    expect(stayed, 1);

    await pump(
      tester,
      card(onStay: () {}, onWatch: () => watched++, staying: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('You stay on Nisqyy'), findsOneWidget);
    expect(find.text('The raid goes to Friend without you'), findsOneWidget);
    expect(find.text('Stay here'), findsNothing);
    expect(find.byKey(RaidCard.trackKey), findsNothing);
    await tester.tap(find.text('Watch'));
    expect(watched, 1);
  });

  testWidgets('without go-along: Go now alone, no promise to go', (
    tester,
  ) async {
    await pump(tester, card());
    expect(find.text('1,204 viewers'), findsOneWidget);
    expect(find.text('Stay here'), findsNothing);
    expect(find.text('Go now'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('once it left without the viewer: a line and Watch', (
    tester,
  ) async {
    var watched = 0;
    await pump(tester, card(raid: _raid(gone: true), onWatch: () => watched++));
    await tester.pumpAndSettle();
    expect(find.text('The raid left for Friend'), findsOneWidget);
    expect(find.text('1,204 viewers went along'), findsOneWidget);
    await tester.tap(find.text('Watch'));
    expect(watched, 1);
  });

  testWidgets('called off: a line, nothing to press', (tester) async {
    await pump(tester, card(raid: _raid(cancelled: true), onStay: () {}));
    await tester.pumpAndSettle();
    expect(find.text('Raid cancelled'), findsOneWidget);
    expect(find.text('Nisqyy stays live'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('leaving: full track, the hit on the target, heading out', (
    tester,
  ) async {
    await pump(tester, card(onStay: () {}, leaving: true));
    expect(find.text('Heading out…'), findsOneWidget);
    expect(find.text('Go now'), findsNothing);
    expect(find.byKey(RaidCard.hitKey), findsOneWidget);
    expect(find.bySemanticsLabel('Heading to Friend'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion: no hit, nothing keeps moving', (tester) async {
    await pump(tester, card(onStay: () {}, leaving: true), reduceMotion: true);
    expect(find.byKey(RaidCard.hitKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('compact: no track, a tap opens the details', (tester) async {
    var opened = 0;
    await pump(
      tester,
      card(onStay: () {}, compact: true, onOpen: () => opened++),
    );
    expect(find.byKey(RaidCard.trackKey), findsNothing);
    expect(find.text('Go now'), findsOneWidget);
    await tester.tap(find.text('RAID'));
    expect(opened, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('dismissible when the stack allows it', (tester) async {
    var dismissed = 0;
    await pump(tester, card(onStay: () {}, onDismiss: () => dismissed++));
    await tester.tap(find.byTooltip('Hide'));
    expect(dismissed, 1);
    await tester.pumpAndSettle();
  });

  for (final width in [390.0, 400.0, 560.0, 854.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('fits $width dp, ${brightness.name}, large text', (
        tester,
      ) async {
        for (final raid in [
          card(onStay: () {}, onDismiss: () {}),
          card(onStay: () {}, staying: true),
          card(raid: _raid(gone: true)),
          card(raid: _raid(cancelled: true)),
          card(onStay: () {}, compact: true),
        ]) {
          await pump(
            tester,
            raid,
            width: width,
            brightness: brightness,
            textScale: 2,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('staying and gone stay dismissible', (tester) async {
    var dismissed = 0;
    await pump(
      tester,
      card(onStay: () {}, staying: true, onDismiss: () => dismissed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide'));
    expect(dismissed, 1);

    await pump(
      tester,
      card(raid: _raid(gone: true), onDismiss: () => dismissed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide'));
    expect(dismissed, 2);
  });

  testWidgets("a picture off Twitch's host is not loaded", (tester) async {
    await pump(
      tester,
      card(
        raid: RaidState(
          const OutgoingRaid(
            id: 'r',
            sourceId: '1',
            targetId: '2',
            targetLogin: 'friend',
            targetDisplayName: 'Friend',
            viewerCount: -3,
            targetProfileImage: 'https://evil.example.com/a.png',
          ),
        ),
      ),
    );
    expect(find.text('0 viewers'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpAndSettle();
  });
}
