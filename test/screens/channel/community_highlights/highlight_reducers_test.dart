import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_math.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_reducers.dart';

Poll poll({
  String id = 'p',
  PollStatus status = PollStatus.active,
  List<int> votes = const [1, 2],
}) => Poll(
  id: id,
  title: 'Which?',
  status: status,
  duration: const Duration(seconds: 60),
  totalVoters: 0,
  totalVotes: votes.fold(0, (a, b) => a + b),
  choices: [
    for (var i = 0; i < votes.length; i++)
      PollChoice(id: 'c$i', title: 'C$i', votes: votes[i], voters: votes[i]),
  ],
);

Prediction prediction({
  String id = 'e',
  PredictionStatus status = PredictionStatus.active,
  String? winner,
}) => Prediction(
  id: id,
  title: 'Win?',
  status: status,
  window: const Duration(seconds: 120),
  outcomes: const [
    PredictionOutcome(
      id: 'a',
      title: 'Yes',
      color: PredictionColor.blue,
      points: 300,
      users: 3,
    ),
    PredictionOutcome(
      id: 'b',
      title: 'No',
      color: PredictionColor.pink,
      points: 100,
      users: 1,
    ),
  ],
  winningOutcomeId: winner,
);

PinnedChatMessage pin(String id, {DateTime? endsAt}) => PinnedChatMessage(
  id: id,
  senderLogin: 'mod',
  senderDisplayName: 'Mod',
  text: 'Rules',
  fragments: const [],
  badges: const [],
  endsAt: endsAt,
);

OutgoingRaid raid({String id = 'r', String source = '1', int viewers = 10}) =>
    OutgoingRaid(
      id: id,
      sourceId: source,
      targetId: '2',
      targetLogin: 'target',
      targetDisplayName: 'Target',
      viewerCount: viewers,
    );

void main() {
  group('polls', () {
    test('create, updates, then completion', () {
      var current = reducePoll(null, PollEvent(PollEventKind.create, poll()));
      current = reducePoll(
        current,
        PollEvent(PollEventKind.update, poll(votes: [3, 4])),
      );
      expect(current!.totalVotes, 7);

      current = reducePoll(
        current,
        PollEvent(
          PollEventKind.complete,
          poll(status: PollStatus.completed, votes: [3, 4]),
        ),
      );
      expect(current!.status, PollStatus.completed);
    });

    test('a late update never reopens a finished poll', () {
      final done = poll(status: PollStatus.completed, votes: [5, 5]);
      expect(
        reducePoll(done, PollEvent(PollEventKind.update, poll(votes: [1, 1]))),
        same(done),
      );
    });

    test('votes never go backwards in the same status', () {
      final current = poll(votes: [5, 5]);
      expect(
        reducePoll(
          current,
          PollEvent(PollEventKind.update, poll(votes: [4, 5])),
        ),
        same(current),
      );
    });

    test('archive removes it; a new poll replaces the old one', () {
      expect(
        reducePoll(
          poll(),
          PollEvent(PollEventKind.archive, poll(status: PollStatus.archived)),
        ),
        isNull,
      );
      expect(
        reducePoll(
          poll(status: PollStatus.completed),
          PollEvent(PollEventKind.create, poll(id: 'q')),
        )!.id,
        'q',
      );
    });
  });

  group('predictions', () {
    test('an update before the creation still shows it', () {
      final next = reducePrediction(null, PredictionEvent(prediction()));
      expect(next.prediction!.id, 'e');
    });

    test('locked, pending, resolved with the winner', () {
      var state = reducePrediction(null, PredictionEvent(prediction()));
      for (final status in [
        PredictionStatus.locked,
        PredictionStatus.resolvePending,
      ]) {
        state = reducePrediction(
          state.prediction,
          PredictionEvent(prediction(status: status)),
          lastTimestamp: state.timestamp,
        );
      }
      state = reducePrediction(
        state.prediction,
        PredictionEvent(
          prediction(status: PredictionStatus.resolved, winner: 'a'),
        ),
        lastTimestamp: state.timestamp,
      );
      expect(state.prediction!.status, PredictionStatus.resolved);
      expect(state.prediction!.winningOutcomeId, 'a');
    });

    test('a stale or backwards update is ignored', () {
      final locked = prediction(status: PredictionStatus.locked);
      expect(
        reducePrediction(locked, PredictionEvent(prediction())).prediction,
        same(locked),
      );
      final at = DateTime.utc(2026, 10, 13, 20);
      final state = reducePrediction(
        prediction(),
        PredictionEvent(
          prediction(),
          timestamp: at.subtract(const Duration(seconds: 1)),
        ),
        lastTimestamp: at,
      );
      expect(state.timestamp, at);
    });

    test('a new prediction replaces a finished one', () {
      expect(
        reducePrediction(
          prediction(status: PredictionStatus.resolved),
          PredictionEvent(prediction(id: 'f')),
        ).prediction!.id,
        'f',
      );
    });
  });

  group('pinned', () {
    test('pin, unpin by id only, update asks to refetch', () {
      final first = reducePinned(null, PinEvent(pin('a')));
      expect(first.pin!.id, 'a');
      expect(
        reducePinned(first.pin, const UnpinEvent('b')).pin,
        same(first.pin),
      );
      expect(reducePinned(first.pin, const UnpinEvent('a')).pin, isNull);
      expect(
        reducePinned(first.pin, const PinUpdateEvent('a')).refetch,
        isTrue,
      );
      expect(
        reducePinned(first.pin, const PinUpdateEvent('z')).refetch,
        isFalse,
      );
    });

    test('expiry', () {
      final now = DateTime.utc(2026, 10, 13, 20);
      expect(pinExpired(pin('a'), now), isFalse);
      expect(
        pinExpired(pin('a', endsAt: now.add(const Duration(seconds: 1))), now),
        isFalse,
      );
      expect(pinExpired(pin('a', endsAt: now), now), isTrue);
    });
  });

  group('raids', () {
    test('update, go, cancel for this channel only', () {
      var state = reduceRaid(
        null,
        RaidEvent(RaidEventKind.update, raid()),
        channelId: '1',
      );
      expect(state!.gone, isFalse);
      state = reduceRaid(
        state,
        RaidEvent(RaidEventKind.update, raid(viewers: 12)),
        channelId: '1',
      );
      expect(state!.raid.viewerCount, 12);
      state = reduceRaid(
        state,
        RaidEvent(RaidEventKind.go, raid()),
        channelId: '1',
      );
      expect(state!.gone, isTrue);
      // The five repeated go events change nothing.
      expect(
        reduceRaid(state, RaidEvent(RaidEventKind.go, raid()), channelId: '1'),
        same(state),
      );
      expect(
        reduceRaid(
          state,
          RaidEvent(RaidEventKind.cancel, raid()),
          channelId: '1',
        ),
        isNull,
      );
      expect(
        reduceRaid(
          null,
          RaidEvent(RaidEventKind.update, raid(source: '9')),
          channelId: '1',
        ),
        isNull,
      );
    });
  });

  group('math', () {
    test('percentages always add up to 100', () {
      expect(percentages([1, 1, 1]), [34, 33, 33]);
      expect(percentages([172, 29, 142, 241]).fold(0, (a, b) => a + b), 100);
      expect(percentages([0, 0]), [0, 0]);
      expect(percentages([]), isEmpty);
    });

    test('leaders: ties share it, nobody leads with no votes', () {
      expect(leaders([3, 5, 5]), {1, 2});
      expect(leaders([0, 0]), isEmpty);
    });

    test('prediction return ratio', () {
      final p = prediction();
      expect(returnRatio(p, p.outcomes.first), closeTo(400 / 300, 1e-9));
      expect(formatRatio(returnRatio(p, p.outcomes.last)), '1:4');
      expect(formatRatio(4 / 3), '1:1.33');
      expect(formatRatio(null), '—');
    });
  });
}
