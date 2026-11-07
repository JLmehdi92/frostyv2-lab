import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/details/chat_modes.dart';
import 'package:onset/theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, ROOMSTATE state) => tester.pumpWidget(
    MaterialApp(
      theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
      home: Scaffold(
        body: Center(child: ChatModes(roomState: state)),
      ),
    ),
  );

  testWidgets('tapping a mode pill explains the mode', (tester) async {
    await pump(
      tester,
      const ROOMSTATE(slowMode: '30', followersOnly: '10', r9k: '1'),
    );
    await tester.tap(find.text('Slow mode'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Everyone waits the time shown between two messages.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message ==
                'Only followers can chat, once they’ve followed for the time '
                    'shown.',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message ==
                'Each message must be unique: repeated messages are refused.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('followers-only with no wait says just that', (tester) async {
    await pump(
      tester,
      const ROOMSTATE(followersOnly: '0', subMode: '1', emoteOnly: '1'),
    );
    for (final message in [
      'Only followers can chat.',
      'Only subscribers can chat.',
      'Messages can only contain emotes.',
    ]) {
      expect(
        find.byWidgetPredicate((w) => w is Tooltip && w.message == message),
        findsOneWidget,
        reason: message,
      );
    }
  });
}
