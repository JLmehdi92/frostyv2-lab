import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/screens/channel/celebrations/onset_rocket.dart';
import 'package:onset/screens/channel/chat/widgets/raid_welcome_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

import '../../../../helpers/chat_message_harness.dart';

final _at = DateTime.utc(2026, 10, 28, 20);

final _arrival = RaidArrival(
  fromName: 'Nisqyy',
  fromLogin: 'nisqyy',
  targetName: 'Splinter',
  viewers: 1204,
  at: _at,
);

void main() {
  setUpAll(() => debugSetRocketArt(File(kRocketAsset).readAsStringSync()));
  tearDownAll(() => debugSetRocketArt(null));

  Future<void> pump(
    WidgetTester tester, {
    Duration age = Duration.zero,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
    double width = 390,
    double textScale = 1,
  }) {
    const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    return tester.pumpWidget(
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
            child: SizedBox(
              width: width,
              child: RaidWelcomeCard(
                arrival: _arrival,
                now: () => _at.add(age),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('who the viewer followed, and where they are', (tester) async {
    await pump(tester);
    expect(
      find.text("You followed Nisqyy's raid", findRichText: true),
      findsOneWidget,
    );
    expect(find.text("Welcome to Splinter's chat"), findsOneWidget);
    expect(find.byType(OnsetRocket), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        "You followed Nisqyy's raid. Welcome to Splinter's chat",
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byKey(RaidWelcomeCard.ruleKey)).width, 2.5);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('scrolled back to later, it is just there', (tester) async {
    await pump(tester, age: const Duration(minutes: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('fresh from when it joined the chat, not from the departure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RaidWelcomeCard(
          arrival: _arrival,
          shownAt: _at.add(const Duration(seconds: 10)),
          now: () => _at.add(const Duration(seconds: 11)),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('under reduce motion, it is just there', (tester) async {
    await pump(tester, reduceMotion: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('light theme: the light text', (tester) async {
    await pump(tester, brightness: Brightness.light);
    final detail = tester.widget<Text>(find.text("Welcome to Splinter's chat"));
    expect(detail.style!.color, SheetColors.light.secondary);
    await tester.pumpAndSettle();
  });

  for (final width in [390.0, 400.0, 854.0]) {
    testWidgets('fits $width dp with large text', (tester) async {
      await pump(tester, width: width, textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chat draws the welcome message as this card', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.raidWelcome(_arrival),
      fakeChatStore(),
    );
    expect(find.byType(RaidWelcomeCard), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
