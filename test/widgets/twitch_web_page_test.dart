import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/twitch_web_page.dart';

void main() {
  setUp(
    () =>
        TwitchWebPage.debugBody = () =>
            const ColoredBox(key: ValueKey('web'), color: Color(0xFFFFFFFF)),
  );
  tearDown(() => TwitchWebPage.debugBody = null);

  testWidgets('the header never blurs while the page slides over a channel '
      'or away from it', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        // Stands for the channel's live video under the page.
        home: const ColoredBox(
          key: ValueKey('video'),
          color: Color(0xFF00FF00),
        ),
      ),
    );
    unawaited(
      TwitchWebPage.open(
        navigator.currentContext!,
        title: 'Follow',
        url: Uri.parse('https://www.twitch.tv/streamer'),
      ),
    );
    bool blurring() => tester
        .widgetList<BackdropFilter>(
          find.descendant(
            of: find.byType(TwitchWebPage),
            matching: find.byType(BackdropFilter),
          ),
        )
        .any((filter) => filter.enabled);

    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(blurring(), isFalse, reason: 'sliding in, frame $i');
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('web')), findsOneWidget);
    expect(blurring(), isTrue, reason: 'in place');

    navigator.currentState!.pop();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.byType(TwitchWebPage).evaluate().isEmpty) break;
      expect(blurring(), isFalse, reason: 'sliding out, frame $i');
    }
    await tester.pumpAndSettle();
  });
}
