import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/details/chat_mode_controls.dart';
import 'package:frosty/screens/channel/chat/moderation.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';

void main() {
  final commands = <ModerationCommand>[];
  late Completer<ModerationOutcome?> answer;

  setUp(commands.clear);

  Future<void> pump(WidgetTester tester, ROOMSTATE room) {
    // Made in the test's zone, so its answer arrives on pump.
    answer = Completer();
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatModeControls(
            roomState: room,
            onModerate: (command) {
              commands.add(command);
              return answer.future;
            },
          ),
        ),
      ),
    );
  }

  Finder switchOf(String label) => find.byWidgetPredicate(
    (widget) => widget is OnsetSwitch && widget.semanticsLabel == label,
  );

  OnsetSwitch tile(WidgetTester tester, String label) =>
      tester.widget<OnsetSwitch>(switchOf(label));

  testWidgets('the switches show the room as Twitch has it', (tester) async {
    await pump(
      tester,
      const ROOMSTATE(slowMode: '10', followersOnly: '0', subMode: '1'),
    );

    expect(tile(tester, 'Slow mode').value, isTrue);
    expect(tile(tester, 'Followers-only mode').value, isTrue);
    expect(tile(tester, 'Subscribers-only mode').value, isTrue);
    expect(tile(tester, 'Emote-only mode').value, isFalse);
    expect(tile(tester, 'Unique chat mode').value, isFalse);
    // The active wait and follow age are shown.
    expect(find.text('10s between messages'), findsOneWidget);
    expect(find.text('Any follower'), findsOneWidget);
  });

  testWidgets('a switch turns its mode on with the chosen length', (
    tester,
  ) async {
    await pump(tester, const ROOMSTATE());

    await tester.tap(switchOf('Slow mode'));
    await tester.pump();

    final slow = commands.single as ChatModeCommand;
    expect(slow.mode, ChatMode.slow);
    expect(slow.on, isTrue);
    expect(slow.duration, const Duration(seconds: 30));
    // Busy until Twitch answers.
    expect(tile(tester, 'Emote-only mode').onChanged, isNull);

    answer.complete((ok: true, message: 'Slow mode on (30 seconds).'));
    await tester.pump();
    expect(find.text('Slow mode on (30 seconds).'), findsOneWidget);
    expect(tile(tester, 'Emote-only mode').onChanged, isNotNull);
  });

  testWidgets('a mode change that throws says so and frees the switches', (
    tester,
  ) async {
    await pump(tester, const ROOMSTATE());
    await tester.tap(switchOf('Slow mode'));
    await tester.pump();
    expect(tile(tester, 'Emote-only mode').onChanged, isNull);
    answer.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text(moderationFailed.message), findsOneWidget);
    expect(tile(tester, 'Emote-only mode').onChanged, isNotNull);
  });

  testWidgets('turning a mode off sends no length', (tester) async {
    await pump(tester, const ROOMSTATE(emoteOnly: '1'));

    await tester.tap(switchOf('Emote-only mode'));
    await tester.pump();

    final emote = commands.single as ChatModeCommand;
    expect(emote.mode, ChatMode.emoteOnly);
    expect(emote.on, isFalse);
    expect(emote.duration, isNull);
  });

  testWidgets('a new follow age applies at once while the mode is on', (
    tester,
  ) async {
    await pump(tester, const ROOMSTATE(followersOnly: '10'));
    expect(find.text('10 minutes'), findsOneWidget);

    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 week').last);
    await tester.pump(const Duration(milliseconds: 500));

    final followers = commands.single as ChatModeCommand;
    expect(followers.mode, ChatMode.followers);
    expect(followers.on, isTrue);
    expect(followers.duration, const Duration(days: 7));
  });

  testWidgets('a tap on the title of a mode with a length changes nothing', (
    tester,
  ) async {
    await pump(tester, const ROOMSTATE());
    await tester.tap(find.text('Slow mode'));
    await tester.pump();
    expect(commands, isEmpty);
  });

  testWidgets('a refused length goes back to what the room has', (
    tester,
  ) async {
    await pump(tester, const ROOMSTATE(slowMode: '30'));

    await tester.tap(find.text('30s between messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60s between messages').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      (commands.single as ChatModeCommand).duration,
      const Duration(seconds: 60),
    );

    answer.complete((ok: false, message: "Couldn't turn slow mode on."));
    await tester.pumpAndSettle();
    expect(find.text('30s between messages'), findsOneWidget);
    expect(find.text('60s between messages'), findsNothing);
  });

  testWidgets('clearing the chat asks first', (tester) async {
    await pump(tester, const ROOMSTATE());

    await tester.tap(find.text('Clear chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commands, isEmpty);

    await tester.tap(find.text('Clear chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(commands.single, isA<ClearChatCommand>());
  });

  testWidgets('board rows: 56 dp modes, a red clear row, no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, const ROOMSTATE(slowMode: '30'));
    expect(tester.takeException(), isNull);
    expect(find.text('Chat modes'), findsOneWidget);
    expect(find.text('Moderator'), findsOneWidget);
    expect(switchOf('Slow mode'), findsOneWidget);
    expect(find.byType(OnsetSwitch), findsNWidgets(5));
    expect(
      tester.widget<Text>(find.text('Clear chat')).style?.color,
      SheetColors.light.danger,
    );
  });
}
