import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';

import '../fixtures/community_highlights_payloads.dart';

Map<String, dynamic> _json(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

void main() {
  group('helpers', () {
    test('dates: epoch seconds, epoch ms and ISO; nonsense is null', () {
      final seconds = chDate(1791923577);
      expect(
        seconds,
        DateTime.fromMillisecondsSinceEpoch(1791923577000, isUtc: true),
      );
      expect(chDate(1791923577000), seconds);
      expect(chDate('1791923577'), seconds);
      expect(chDate('2026-10-13T20:44:19.570364857Z')!.year, 2026);
      for (final bad in [null, 'soon', 12, -5, double.nan, true, <int>[]]) {
        expect(chDate(bad), isNull, reason: '$bad');
      }
    });

    test('ints accept strings; reject the rest', () {
      expect(chInt('154'), 154);
      expect(chInt(3.9), 3);
      expect(chInt(double.infinity), isNull);
      expect(chInt('x'), isNull);
      expect(chInt(null), isNull);
    });
  });

  group('polls', () {
    test('GQL active poll', () {
      final poll = Poll.fromGql(
        _json(gqlGetViewablePollACTIVE)['data']['user']['viewablePoll'] as Map,
      )!;
      expect(poll.status, PollStatus.active);
      expect(poll.title, '?');
      expect(poll.choices.map((c) => c.title), contains('outlast 2'));
      expect(poll.totalVotes, 584);
      expect(poll.duration, const Duration(seconds: 300));
      expect(poll.remaining, const Duration(milliseconds: 17707));
      expect(poll.choices.first.votes, 172);
    });

    test('GQL archived poll is null', () {
      final user =
          _json(gqlGetViewablePollAfterArchiveNull)['data']['user'] as Map;
      expect(Poll.fromGql(user['viewablePoll']), isNull);
    });

    test('Hermes update and GQL read the same fields', () {
      final event =
          ChEvent.parse(HighlightTopic.polls, hermesPollsPOLLUPDATE)
              as PollEvent;
      expect(event.kind, PollEventKind.update);
      expect(event.poll.id, '2c3ee78e-807a-4b01-ae20-c1a977fd3c9c');
      expect(event.poll.status, PollStatus.active);
      expect(event.poll.duration, const Duration(seconds: 60));
      expect(event.poll.choices.first.title, 'yes');
      expect(event.poll.choices.first.votes, 1);
      expect(event.poll.multiChoice, isTrue);
      expect(event.poll.channelId, '1263412413');
    });

    test('every poll event kind', () {
      expect(
        {
          for (final (text, kind) in [
            (hermesPollsPOLLCREATE, PollEventKind.create),
            (hermesPollsPOLLCOMPLETE, PollEventKind.complete),
            (hermesPollsPOLLTERMINATE, PollEventKind.terminate),
            (hermesPollsPOLLARCHIVE, PollEventKind.archive),
          ])
            (ChEvent.parse(HighlightTopic.polls, text) as PollEvent).kind: kind,
        }.entries.every((e) => e.key == e.value),
        isTrue,
      );
      final terminated =
          ChEvent.parse(HighlightTopic.polls, hermesPollsPOLLTERMINATE)
              as PollEvent;
      expect(terminated.poll.status, PollStatus.terminated);
    });

    test('titles are capped', () {
      final poll = Poll.fromGql({
        'id': 'p',
        'title': 'x' * 1000,
        'status': 'ACTIVE',
        'choices': [
          {'id': 'c', 'title': 'y' * 1000},
        ],
      })!;
      expect(poll.title.length, 200);
      expect(poll.choices.single.title.length, 100);
    });
  });

  group('predictions', () {
    test('GQL active prediction', () {
      final channel =
          _json(gqlGetActivePredictionACTIVE)['data']['user']['channel'] as Map;
      final prediction = Prediction.fromGql(
        (channel['activePredictionEvents'] as List).first as Map,
      )!;
      expect(prediction.title, 'TOP 10?');
      expect(prediction.status, PredictionStatus.active);
      expect(prediction.outcomes, hasLength(greaterThanOrEqualTo(2)));
      expect(prediction.outcomes.first.color, PredictionColor.blue);
      expect(prediction.window.inSeconds, greaterThan(0));
    });

    test('Hermes resolved: winner and the winners top predictors', () {
      final event =
          ChEvent.parse(
                HighlightTopic.predictions,
                hermesPredictionsChannelV1EventUpdatedRESOLVED,
              )
              as PredictionEvent;
      final prediction = event.prediction;
      expect(prediction.status, PredictionStatus.resolved);
      expect(prediction.winningOutcomeId, isNotNull);
      expect(prediction.channelId, '182714869');
      final first = prediction.outcomes.first;
      expect(first.points, 1044059);
      expect(first.users, 214);
      expect(first.topPredictors.first.pointsWon, 508030);
      expect(event.timestamp!.year, 2026);
    });

    test('every status', () {
      for (final (text, status) in [
        (hermesPredictionsChannelV1EventCreatedACTIVE, PredictionStatus.active),
        (hermesPredictionsChannelV1EventUpdatedLOCKED, PredictionStatus.locked),
        (
          hermesPredictionsChannelV1EventUpdatedRESOLVEPENDING,
          PredictionStatus.resolvePending,
        ),
        (
          hermesPredictionsChannelV1EventUpdatedCANCELPENDING,
          PredictionStatus.cancelPending,
        ),
        (
          hermesPredictionsChannelV1EventUpdatedCANCELED,
          PredictionStatus.canceled,
        ),
      ]) {
        expect(
          (ChEvent.parse(HighlightTopic.predictions, text) as PredictionEvent)
              .prediction
              .status,
          status,
        );
      }
    });

    test('an unknown colour or status does not break the outcome', () {
      final prediction = Prediction.fromPubsub({
        'id': 'e',
        'title': 'Will it?',
        'status': 'SOMETHING_NEW',
        'outcomes': [
          {'id': 'a', 'title': 'Yes', 'color': 'GREEN', 'total_points': '10'},
        ],
      })!;
      expect(prediction.status, PredictionStatus.unknown);
      expect(prediction.outcomes.single.color, PredictionColor.unknown);
      expect(prediction.outcomes.single.points, 10);
    });
  });

  group('pinned messages', () {
    test('GQL pin: sender, badges, fragments, null end', () {
      final edge =
          (_json(
                        gqlGetPinnedChat0,
                      )['data']['channel']['pinnedChatMessages']['edges']
                      as List)
                  .first
              as Map;
      final pin = PinnedChatMessage.fromGql(edge['node'] as Map)!;
      expect(pin.senderLogin, 'nightbot');
      expect(pin.senderDisplayName, 'Nightbot');
      expect(pin.color, '#7C7CE1');
      expect(pin.endsAt, isNull);
      expect(pin.text, contains('boozt.com'));
      expect(pin.fragments, hasLength(3));
      expect(pin.badges, isNotEmpty);
    });

    test('Hermes pin in epoch seconds', () {
      final event =
          ChEvent.parse(
                HighlightTopic.pinned,
                hermesPinnedChatUpdatesV1PinMessage,
              )
              as PinEvent;
      final pin = event.message;
      expect(pin.id, '9d4b2624-caa6-41ca-bdd2-6d0d18eba3a8');
      expect(pin.senderLogin, 'streamelements');
      expect(pin.badges.map((b) => b.setId), ['moderator', 'bot-badge']);
      expect(
        pin.endsAt,
        DateTime.fromMillisecondsSinceEpoch(1791924777000, isUtc: true),
      );
      expect(pin.text, startsWith('Meta Is NIET'));
    });

    test('update and unpin carry the pin id', () {
      final update =
          ChEvent.parse(
                HighlightTopic.pinned,
                hermesPinnedChatUpdatesV1UpdateMessage,
              )
              as PinUpdateEvent;
      expect(update.id, '9d4b2624-caa6-41ca-bdd2-6d0d18eba3a8');
      final unpin =
          ChEvent.parse(
                HighlightTopic.pinned,
                hermesPinnedChatUpdatesV1UnpinMessage,
              )
              as UnpinEvent;
      expect(unpin.id, 'b1ac8358-c515-47d2-a82b-272ed0a7c987');
    });

    test('messages are capped', () {
      final pin = PinnedChatMessage.fromPubsub({
        'id': 'p',
        'message': {
          'sender': {'login': 'a'},
          'content': {'text': 'z' * 2000},
        },
      })!;
      expect(pin.text.length, 500);
    });
  });

  group('raids', () {
    test('update, go and cancel without a data wrapper', () {
      final update =
          ChEvent.parse(HighlightTopic.raid, hermesRaidRaidUpdateV2)
              as RaidEvent;
      expect(update.kind, RaidEventKind.update);
      final raid = update.raid;
      expect(raid.targetLogin, 'raidtarget1');
      expect(raid.targetDisplayName, 'RaidTarget1');
      expect(raid.targetId, '38581005');
      expect(raid.sourceId, '136558367');
      expect(raid.viewerCount, 1);
      expect(raid.targetViewerCount, 154);
      expect(raid.goAt, raid.createdAt!.add(const Duration(seconds: 90)));

      expect(
        (ChEvent.parse(HighlightTopic.raid, hermesRaidRaidGoV2) as RaidEvent)
            .kind,
        RaidEventKind.go,
      );
      expect(
        (ChEvent.parse(HighlightTopic.raid, hermesRaidRaidCancelV2)
                as RaidEvent)
            .kind,
        RaidEventKind.cancel,
      );
    });

    test('a target that is not a login or id is refused', () {
      expect(
        OutgoingRaid.fromPubsub({
          'id': 'r',
          'source_id': '1',
          'target_id': '2',
          'target_login': '../evil',
        }),
        isNull,
      );
      expect(
        OutgoingRaid.fromPubsub({
          'id': 'r',
          'source_id': '1',
          'target_id': 'x',
          'target_login': 'ok',
        }),
        isNull,
      );
    });
  });

  test('garbage never throws', () {
    for (final topic in HighlightTopic.values) {
      for (final text in [
        '',
        'not json',
        '[]',
        '42',
        '{}',
        '{"type": 5}',
        '{"type": "POLL_UPDATE", "data": []}',
        '{"type": "event-updated", "data": {"event": "x"}}',
        '{"type": "pin-message", "data": {"message": 3}}',
        '{"type": "raid_update_v2", "raid": null}',
      ]) {
        expect(ChEvent.parse(topic, text), isA<ChEvent>(), reason: text);
      }
    }
    expect(ChEvent.parse(HighlightTopic.polls, 'x'), isA<ChUnknown>());
  });

  group('hostile payloads', () {
    test('a cut never splits an emoji; lone surrogates are replaced', () {
      final cut = chString('${'a' * 499}😀b')!;
      expect(cut, 'a' * 499);
      expect(chString('x\ud83dy'), 'x�y');
      expect(chString('\udc00'), '�');
      expect(chString('ok 😀'), 'ok 😀');
      expect(chWellFormed('😀😀'), '😀😀');
    });

    test('absurd dates and durations never throw', () {
      expect(chDate(1e16), isNull);
      expect(chDate('9000000000000000'), isNull);
      expect(chDate('2400-01-01T00:00:00Z'), isNull);
      expect(chDate(1760385600), DateTime.utc(2025, 10, 13, 20));

      final poll = Poll.fromPubsub({
        'poll_id': 'p',
        'title': 'Q',
        'status': 'ACTIVE',
        'started_at': '2026-10-13T20:00:00Z',
        'ended_at': 8640000000000000,
        'duration_seconds': 8640000000000,
        'choices': const [],
      })!;
      expect(poll.endedAt, isNull);
      expect(poll.endsAt, DateTime.utc(2026, 10, 14, 20));

      final raid = OutgoingRaid.fromPubsub({
        'id': 'r',
        'source_id': '1',
        'target_id': '2',
        'target_login': 'friend',
        'raid_created_at': 1760385600,
        'force_raid_now_seconds': 8640000000000,
      })!;
      expect(raid.goAt, DateTime.utc(2025, 10, 13, 20, 10));
    });

    test('lists and pinned text are bounded', () {
      final poll = Poll.fromPubsub({
        'poll_id': 'p',
        'title': 'Q',
        'status': 'ACTIVE',
        'choices': [
          for (var i = 0; i < 1000; i++) {'choice_id': 'c$i', 'title': 'C$i'},
        ],
      })!;
      expect(poll.choices.length, lessThanOrEqualTo(20));

      final pin = PinnedChatMessage.fromPubsub({
        'id': 'pin',
        'message': {
          'id': 'm',
          'sender': {'id': '7', 'login': 'mod', 'display_name': 'Mod'},
          'content': {
            'text': 'x' * 100000,
            'fragments': [
              for (var i = 0; i < 1000; i++) {'text': 'y' * 100000},
            ],
          },
        },
      })!;
      expect(pin.text.length, lessThanOrEqualTo(500));
      expect(pin.fragments.length, lessThanOrEqualTo(200));
      expect(
        pin.fragments.fold(0, (sum, f) => sum + f.text.length),
        lessThanOrEqualTo(500),
      );
    });
  });
}
