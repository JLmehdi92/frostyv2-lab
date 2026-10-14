import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/moderation.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_moderation_bar.dart';

void main() {
  final commands = <ModerationCommand>[];
  late Completer<ModerationOutcome?> answer;

  setUp(commands.clear);

  Future<void> pump(WidgetTester tester) {
    // Made in the test's zone, so its answer arrives on pump.
    answer = Completer();
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatModerationBar(
            login: 'troll',
            name: 'Troll',
            onModerate: (command) {
              commands.add(command);
              return answer.future;
            },
          ),
        ),
      ),
    );
  }

  testWidgets('a timeout length is one tap from the menu', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(PopupMenuButton<Duration>));
    await tester.pumpAndSettle();
    expect(find.text('1 second (purge)'), findsOneWidget);
    await tester.tap(find.text('10 minutes'));
    // The progress bar never settles.
    await tester.pump(const Duration(milliseconds: 500));

    final timeout = commands.single as TimeoutCommand;
    expect(timeout.login, 'troll');
    expect(timeout.duration, const Duration(minutes: 10));

    // Busy until the answer, then says it.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    answer.complete((ok: true, message: 'You timed out Troll for 10 minutes.'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('You timed out Troll for 10 minutes.'), findsOneWidget);
  });

  testWidgets('ban asks first, with an optional reason', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ban'));
    await tester.pumpAndSettle();
    expect(find.text('Ban Troll?'), findsOneWidget);

    // Cancel does nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commands, isEmpty);

    await tester.tap(find.text('Ban'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  spam bot ');
    await tester.tap(find.widgetWithText(FilledButton, 'Ban').last);
    await tester.pump(const Duration(milliseconds: 500));

    final ban = commands.single as BanCommand;
    expect(ban.login, 'troll');
    expect(ban.reason, 'spam bot');
  });

  testWidgets('warn needs a reason', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Warn'));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Warn');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'no spam');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 500));

    expect((commands.single as WarnCommand).reason, 'no spam');
  });

  testWidgets('a refusal shows, and the buttons come back', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Unban'));
    await tester.pump();
    expect(commands.single, isA<UnbanCommand>());
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Unban'))
          .onPressed,
      isNull,
    );

    answer.complete((ok: false, message: "Couldn't unban: not banned"));
    await tester.pump();
    expect(find.text("Couldn't unban: not banned"), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Unban'))
          .onPressed,
      isNotNull,
    );
  });
}
