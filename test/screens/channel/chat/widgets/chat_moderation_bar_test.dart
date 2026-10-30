import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/widgets/chat_moderation_bar.dart';

void main() {
  final commands = <ModerationCommand>[];
  late Completer<ModerationOutcome?> answer;

  setUp(commands.clear);

  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Made in the test's zone, so its answer arrives on pump.
    answer = Completer();
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Where the user card puts it: in the lower half of the screen.
          body: Align(
            alignment: const Alignment(0, 0.4),
            child: ChatModerationBar(
              login: 'troll',
              name: 'Troll',
              onModerate: (command) {
                commands.add(command);
                return answer.future;
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a timeout length is one tap from the menu', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Timeout'));
    await tester.pumpAndSettle();
    expect(find.text('1 second (purge)'), findsOneWidget);
    await tester.tap(find.text('10 minutes'));
    // The progress bar never settles. The menu runs its item once closed,
    // so the busy state draws a frame later.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

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
    // The last pill scrolls in on a phone.
    await tester.ensureVisible(find.text('Warn'));
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

  testWidgets('an action that throws says so and frees the buttons', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Unban'));
    await tester.pump();
    answer.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(moderationFailed.message), findsOneWidget);
    expect(
      tester
          .widget<ModerationPill>(find.widgetWithText(ModerationPill, 'Unban'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a refusal shows, and the buttons come back', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Unban'));
    await tester.pump();
    expect(commands.single, isA<UnbanCommand>());
    expect(
      tester
          .widget<ModerationPill>(find.widgetWithText(ModerationPill, 'Unban'))
          .onPressed,
      isNull,
    );

    answer.complete((ok: false, message: "Couldn't unban: not banned"));
    await tester.pump();
    expect(find.text("Couldn't unban: not banned"), findsOneWidget);
    expect(
      tester
          .widget<ModerationPill>(find.widgetWithText(ModerationPill, 'Unban'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('pills: 44 dp, the menu opens above the timeout', (tester) async {
    await pump(tester);
    for (final label in ['Timeout', 'Ban', 'Unban', 'Warn']) {
      expect(
        tester.getSize(find.widgetWithText(ModerationPill, label)).height,
        44,
        reason: label,
      );
    }
    final pill = tester.getRect(find.widgetWithText(ModerationPill, 'Timeout'));
    await tester.tap(find.text('Timeout'));
    await tester.pumpAndSettle();
    final first = tester.getRect(find.text('1 second (purge)'));

    final last = tester.getRect(find.text('2 weeks'));
    expect(last.bottom, lessThan(pill.top));
    expect(first.top, lessThan(last.top));
    // The chevron says the menu is open.
    expect(
      tester
          .widget<ModerationPill>(
            find.widgetWithText(ModerationPill, 'Timeout'),
          )
          .expanded,
      isTrue,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('2 weeks'), findsNothing);
  });

  testWidgets('the ban reason counts to 500', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ban'));
    await tester.pumpAndSettle();
    expect(find.text('Reason (optional)'), findsOneWidget);
    expect(find.text('0 / 500'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'x' * 600);
    await tester.pump();
    expect(find.text('500 / 500'), findsOneWidget);
  });
}
