import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_card_shell.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_cards.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

final _start = DateTime.utc(2026, 10, 13, 20);

Poll _poll({PollStatus status = PollStatus.active}) => Poll(
  id: 'p',
  title: 'Which game next?',
  status: status,
  duration: const Duration(seconds: 60),
  startedAt: _start,
  totalVotes: 30,
  totalVoters: 30,
  choices: const [
    PollChoice(id: 'a', title: 'Outlast 2', votes: 20, voters: 20),
    PollChoice(id: 'b', title: 'Elden Ring', votes: 10, voters: 10),
  ],
);

Prediction _prediction({
  PredictionStatus status = PredictionStatus.active,
  String? winner,
}) => Prediction(
  id: 'e',
  title: 'Top 10?',
  status: status,
  createdAt: _start,
  window: const Duration(seconds: 120),
  winningOutcomeId: winner,
  outcomes: const [
    PredictionOutcome(
      id: 'yes',
      title: 'Yes',
      color: PredictionColor.blue,
      points: 300,
      users: 3,
      topPredictors: [TopPredictor(name: 'Big', points: 200)],
    ),
    PredictionOutcome(
      id: 'no',
      title: 'No',
      color: PredictionColor.pink,
      points: 150,
      users: 2,
    ),
  ],
);

void main() {
  var now = _start;
  var toggles = 0;

  setUp(() {
    now = _start;
    toggles = 0;
  });

  HighlightCardContext card({bool expanded = true}) => HighlightCardContext(
    expanded: expanded,
    onToggle: () => toggles++,
    onDismiss: () {},
    now: () => now,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 360,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  void expectNoVoting() {
    for (final text in ['Vote', 'Predict', 'Bet', 'Watch ad']) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FilledButton ||
            w is ElevatedButton ||
            w is OutlinedButton ||
            w is TextButton,
      ),
      findsNothing,
    );
  }

  group('poll voting', () {
    HighlightCardContext voting({
      required ValueChanged<String> onVote,
      String? voted,
      bool sending = false,
      bool expanded = true,
    }) => HighlightCardContext(
      expanded: expanded,
      onToggle: () {},
      now: () => now,
      onTakePart: () {},
      onVote: onVote,
      votedChoiceId: voted,
      voting: sending,
    );

    testWidgets('a choice is picked, then sent with Vote', (tester) async {
      final sent = <String>[];
      await pump(
        tester,
        PollCard(
          poll: _poll(),
          card: voting(onVote: sent.add),
        ),
      );

      final vote = find.byKey(PollCard.voteKey);
      expect(tester.widget<TextButton>(vote).onPressed, isNull);
      expect(find.text('Vote on Twitch'), findsNothing);

      await tester.tap(find.byKey(PollCard.choiceKey('b')));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      await tester.tap(find.byKey(PollCard.choiceKey('a')));
      await tester.pumpAndSettle();
      await tester.tap(vote);
      expect(sent, ['a']);
    });

    testWidgets('Vote sits inside the card padding, in line with the bars', (
      tester,
    ) async {
      await pump(
        tester,
        PollCard(
          poll: _poll(),
          card: voting(onVote: (_) {}),
        ),
      );
      final vote = tester.getRect(find.byKey(PollCard.voteKey));
      final bar = tester.getRect(find.byKey(PollCard.choiceKey('a')));
      expect(vote.right, lessThanOrEqualTo(bar.right));
    });

    testWidgets('the picked choice is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        PollCard(
          poll: _poll(),
          card: voting(onVote: (_) {}),
        ),
      );
      await tester.tap(find.byKey(PollCard.choiceKey('b')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(PollCard.choiceKey('b'))),
        matchesSemantics(
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          label: 'Elden Ring\n33%',
        ),
      );
      handle.dispose();
    });

    testWidgets('while sending, nothing more can be sent', (tester) async {
      final sent = <String>[];
      await pump(
        tester,
        PollCard(
          poll: _poll(),
          card: voting(onVote: sent.add, sending: true),
        ),
      );
      await tester.tap(find.byKey(PollCard.choiceKey('a')));
      await tester.pump();
      expect(
        tester.widget<TextButton>(find.byKey(PollCard.voteKey)).onPressed,
        isNull,
      );
    });

    testWidgets('once voted, the choice is named and no button is left', (
      tester,
    ) async {
      await pump(
        tester,
        PollCard(
          poll: _poll(),
          card: voting(onVote: (_) {}, voted: 'b'),
        ),
      );
      expect(find.textContaining('You voted for Elden Ring'), findsOneWidget);
      expect(find.byKey(PollCard.voteKey), findsNothing);
      expect(find.byKey(PollCard.choiceKey('a')), findsNothing);
      expect(find.text('Vote on Twitch'), findsNothing);
    });

    testWidgets('an ended poll offers no vote', (tester) async {
      await pump(
        tester,
        PollCard(
          poll: _poll(status: PollStatus.completed),
          card: voting(onVote: (_) {}),
        ),
      );
      expect(find.byKey(PollCard.voteKey), findsNothing);
    });
  });

  group('poll', () {
    testWidgets('shares, leader, votes and time left', (tester) async {
      await pump(tester, PollCard(poll: _poll(), card: card()));

      expect(find.text('Which game next?'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('30 votes'), findsOneWidget);
      expect(find.text('1:00 left'), findsOneWidget);

      now = _start.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:45 left'), findsOneWidget);
      expectNoVoting();
    });

    testWidgets('final results once it ended', (tester) async {
      await pump(
        tester,
        PollCard(
          poll: _poll(status: PollStatus.completed),
          card: card(),
        ),
      );
      expect(find.text('Final results'), findsOneWidget);
    });

    testWidgets('collapsed shows the question only; tap toggles', (
      tester,
    ) async {
      await pump(tester, PollCard(poll: _poll(), card: card(expanded: false)));
      expect(find.text('67%'), findsNothing);
      await tester.tap(find.text('Which game next?'));
      expect(toggles, 1);
    });

    testWidgets('one screen-reader summary', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, PollCard(poll: _poll(), card: card()));
      expect(
        find.bySemanticsLabel(
          RegExp('Poll, Which game next\\?, Outlast 2 leads with 67 percent'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('prediction', () {
    testWidgets('outcomes with shares, ratio and predictors', (tester) async {
      await pump(
        tester,
        PredictionCard(prediction: _prediction(), card: card()),
      );
      expect(find.text('Top 10?'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('1:1.5'), findsOneWidget);
      expect(find.text('1:3'), findsOneWidget);
      expect(find.text('3 predictors'), findsOneWidget);
      expect(find.text('Top: Big'), findsOneWidget);
      expect(find.text('2:00 to predict'), findsOneWidget);
      expectNoVoting();
    });

    testWidgets('locked, winner, refunded', (tester) async {
      await pump(
        tester,
        PredictionCard(
          prediction: _prediction(status: PredictionStatus.locked),
          card: card(),
        ),
      );
      expect(find.text('Predictions closed'), findsOneWidget);

      await pump(
        tester,
        PredictionCard(
          prediction: _prediction(
            status: PredictionStatus.resolved,
            winner: 'no',
          ),
          card: card(),
        ),
      );
      expect(find.text('Winner: No'), findsOneWidget);
      // The winner's bar carries the check.
      final winnerBar = find.ancestor(
        of: find.text('No'),
        matching: find.byType(HighlightBar),
      );
      expect(tester.widget<HighlightBar>(winnerBar).leading, isNotNull);
      final loserBar = find.ancestor(
        of: find.text('Yes'),
        matching: find.byType(HighlightBar),
      );
      expect(tester.widget<HighlightBar>(loserBar).leading, isNull);

      await pump(
        tester,
        PredictionCard(
          prediction: _prediction(status: PredictionStatus.canceled),
          card: card(),
        ),
      );
      expect(find.text('Canceled · points refunded'), findsOneWidget);
    });
  });

  group('pinned', () {
    final pin = PinnedChatMessage(
      id: 'pin',
      senderLogin: 'mod',
      senderDisplayName: 'Mod',
      color: '#FF0000',
      text: 'Be nice',
      fragments: const [],
      badges: const [],
      pinnedBy: 'Streamer',
    );

    testWidgets('plain text with the sender when no chat rendering', (
      tester,
    ) async {
      await pump(tester, PinnedCard(pin: pin, card: card()));
      expect(find.textContaining('Mod: '), findsOneWidget);
      expect(find.text('by Streamer'), findsOneWidget);
    });

    testWidgets('the chat rendering when given', (tester) async {
      await pump(
        tester,
        PinnedCard(
          pin: pin,
          card: card(),
          message: const Text('rendered like chat'),
        ),
      );
      expect(find.text('rendered like chat'), findsOneWidget);
    });

    testWidgets('a moderator gets Unpin under the message', (tester) async {
      var unpinned = 0;
      await pump(
        tester,
        PinnedCard(pin: pin, card: card(), onUnpin: () => unpinned++),
      );
      await tester.tap(find.text('Unpin'));
      expect(unpinned, 1);
    });

    testWidgets('no Unpin for viewers', (tester) async {
      await pump(tester, PinnedCard(pin: pin, card: card()));
      expect(find.text('Unpin'), findsNothing);
    });
  });

  testWidgets('large text fits a 360 dp phone', (tester) async {
    for (final child in [
      PollCard(poll: _poll(), card: card()),
      PredictionCard(prediction: _prediction(), card: card()),
    ]) {
      await pump(tester, child, textScale: 2);
      expect(tester.takeException(), isNull);
    }
  });

  group('taking part on twitch.tv', () {
    HighlightCardContext withTakePart(
      VoidCallback onTakePart, {
      bool expanded = true,
    }) => HighlightCardContext(
      expanded: expanded,
      onToggle: () {},
      now: () => now,
      onTakePart: onTakePart,
    );

    testWidgets('an open poll can be voted on twitch.tv', (tester) async {
      var opened = 0;
      await pump(
        tester,
        PollCard(poll: _poll(), card: withTakePart(() => opened++)),
      );

      await tester.tap(find.text('Vote on Twitch'));
      expect(opened, 1);
    });

    testWidgets('an open prediction can be made on twitch.tv', (tester) async {
      await pump(
        tester,
        PredictionCard(prediction: _prediction(), card: withTakePart(() {})),
      );
      expect(find.text('Predict on Twitch'), findsOneWidget);
    });

    testWidgets('nothing to take part in: no button', (tester) async {
      await pump(
        tester,
        PollCard(
          poll: _poll(status: PollStatus.completed),
          card: withTakePart(() {}),
        ),
      );
      expect(find.text('Vote on Twitch'), findsNothing);

      await pump(
        tester,
        PredictionCard(
          prediction: _prediction(status: PredictionStatus.locked),
          card: withTakePart(() {}),
        ),
      );
      expect(find.text('Predict on Twitch'), findsNothing);

      // Collapsed cards stay one line.
      await pump(
        tester,
        PollCard(poll: _poll(), card: withTakePart(() {}, expanded: false)),
      );
      expect(find.text('Vote on Twitch'), findsNothing);

      // No channel to open: no button.
      await pump(tester, PollCard(poll: _poll(), card: card()));
      expect(find.text('Vote on Twitch'), findsNothing);
    });
  });

  group('card chrome', () {
    testWidgets('a 16 dp card in the sheet tone, 36 dp bars', (tester) async {
      await pump(tester, PollCard(poll: _poll(), card: card()));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HighlightCardShell),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, SheetColors.light.sheet);
      expect(
        (material.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16),
      );
      for (final bar in tester.widgetList<HighlightBar>(
        find.byType(HighlightBar),
      )) {
        expect(bar.fill.a, greaterThan(0));
      }
      expect(
        tester.getSize(find.byType(HighlightBar).first).height,
        greaterThanOrEqualTo(36),
      );
    });

    testWidgets('the chevron turns with the card', (tester) async {
      await pump(tester, PollCard(poll: _poll(), card: card(expanded: false)));
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );
      await pump(tester, PollCard(poll: _poll(), card: card()));
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0.5,
      );
    });

    for (final width in [390.0 - 24, 560.0, 854.0 - 24]) {
      testWidgets('no overflow at $width dp', (tester) async {
        await pump(
          tester,
          PredictionCard(prediction: _prediction(), card: card()),
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
