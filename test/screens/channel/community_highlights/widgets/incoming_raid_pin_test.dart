import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/celebrations/onset_rocket.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/community_highlights/widgets/incoming_raid_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_avatar.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

const _raid = IncomingRaid(
  raiderName: 'Nisqyy',
  raiderLogin: 'nisqyy',
  viewers: 1204,
);

void main() {
  setUpAll(() => debugSetRocketArt(File(kRocketAsset).readAsStringSync()));
  tearDownAll(() => debugSetRocketArt(null));

  Future<void> pump(
    WidgetTester tester, {
    double width = 390,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
    double textScale = 1,
    VoidCallback? onDismiss,
  }) async {
    tester.view
      ..physicalSize = const Size(1280, 854)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark
            : const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).light,
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
              width: width - 24,
              child: IncomingRaidPin(raid: _raid, onDismiss: onDismiss),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('who raids with how many, the picture and the rocket', (
    tester,
  ) async {
    var dismissed = 0;
    await pump(tester, onDismiss: () => dismissed++);
    expect(find.textContaining('is raiding with 1,204 viewers'), findsOne);
    expect(find.text('Say hi in chat'), findsOne);
    expect(find.byType(RaidAvatar), findsOne);
    expect(find.byType(OnsetRocket), findsOne);
    expect(
      find.bySemanticsLabel('Nisqyy is raiding with 1,204 viewers'),
      findsOne,
    );
    final pin = tester.getSize(
      find
          .descendant(
            of: find.byType(IncomingRaidPin),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(pin.height, 54);

    await tester.tap(find.byTooltip('Hide'));
    expect(dismissed, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('one viewer is one viewer; no close without dismiss', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomingRaidPin(
            raid: const IncomingRaid(raiderName: 'Solo', viewers: 1),
          ),
        ),
      ),
    );
    expect(find.textContaining('with 1 viewer'), findsOne);
    expect(find.byTooltip('Hide'), findsNothing);
    await tester.pumpAndSettle();
  });

  for (final width in [390.0, 400.0, 560.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('fits $width dp, ${brightness.name}, large text', (
        tester,
      ) async {
        await pump(
          tester,
          width: width,
          brightness: brightness,
          textScale: 2,
          onDismiss: () {},
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('light theme reads on the light sheet', (tester) async {
    await pump(tester, brightness: Brightness.light);
    final title = tester.widget<Text>(find.textContaining('is raiding with'));
    expect(title.style!.color, SheetColors.light.text);
    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion: the rocket is simply there', (tester) async {
    await pump(tester, reduceMotion: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the rocket flies in, then everything settles', (tester) async {
    await pump(tester);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
