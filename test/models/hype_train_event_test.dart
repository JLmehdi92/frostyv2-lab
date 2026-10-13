import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';

import '../fixtures/hype_train_payloads.dart';
import '../fixtures/hype_train_payloads_tbc.dart';

void main() {
  test('progression (captured)', () {
    final event = HypeTrainEvent.parse(htProgression) as HtProgressionEvent;

    expect(event.sequenceId, 3000);
    expect(event.sequenceId, event.progress.total);
    expect(event.action.raw, 'TIER_1_SUB');
    expect(event.action.subTier, 1);
    expect(event.source, HtSource.subs);
    expect(event.quantity, 1);
    expect(event.userId, '900007');
    expect(event.login, 'viewer_4');
    expect(event.progress.level.value, 2);
    expect(event.progress.value, 1000);
    expect(event.progress.goal, 2500);
    expect(event.expiresAt, DateTime.utc(2026, 10, 13, 16, 3, 1, 796, 946));
    expect(event.isLarge, isFalse);
    expect(event.id, isNotNull);
  });

  test('an unknown action keeps its name', () {
    final event =
        HypeTrainEvent.parse(
              htProgression.replaceFirst('"TIER_1_SUB"', '"EXTENSION"'),
            )
            as HtProgressionEvent;

    expect(event.action.raw, 'EXTENSION');
    expect(event.action.isKnown, isFalse);
  });

  test('the duplicated progression keeps its id for dedupe', () {
    final event =
        HypeTrainEvent.parse(htProgressionDuplicate) as HtProgressionEvent;

    expect(event.id, '00000000-0000-4000-8000-000000000007');
    expect(event.sequenceId, 25000);
  });

  test('level-up: epoch ms expiry and the golden train', () {
    final event = HypeTrainEvent.parse(htLevelUp) as HtLevelUpEvent;

    expect(event.timeToExpire, DateTime.utc(2026, 10, 13, 16, 5, 26));
    expect(event.progress.level.value, 2);
    expect(event.train?.variant, HtVariant.goldenKappa);
    expect(event.train?.endReason, HtEndReason.inProgress);
  });

  test('conductor update map', () {
    final event = HypeTrainEvent.parse(htConductorUpdate) as HtConductorEvent;

    expect(event.conductor.source, HtSource.subs);
    expect(event.conductor.user.login, 'viewer_6');
    expect(event.conductor.participations, {
      'TIER_1_GIFTED_SUB': 10,
      'TIER_1_SUB': 1,
    });
    expect(event.conductor.amount, 11);
  });

  test('a conductor without a user is unknown', () {
    final event = HypeTrainEvent.parse(
      '{"type":"hype-train-conductor-update","data":{"source":"BITS",'
      '"user":{"id":""},"participations":{}}}',
    );

    expect(event, isA<HtUnknownEvent>());
  });

  test('ends: completed with rewards, expired without', () {
    final completed = HypeTrainEvent.parse(htEndCompleted) as HtEndEvent;
    expect(completed.reason, HtEndReason.completed);
    expect(
      completed.endedAt,
      DateTime.fromMillisecondsSinceEpoch(1791907381000, isUtc: true),
    );
    expect(completed.totals.single.quantity, 6);
    expect(completed.totals.single.action.subTier, 1);
    expect(completed.rewards.first.token, 'chanHype7');

    final expired = HypeTrainEvent.parse(htEndExpired) as HtEndEvent;
    expect(expired.reason, HtEndReason.expired);
    expect(expired.rewards, isEmpty);
  });

  test('approaching, start, merge, channel left, conversion (TBC shapes)', () {
    expect(
      (HypeTrainEvent.parse(htTbcApproachingEvent) as HtApproachingEvent)
          .approaching
          .deadlines,
      {1: 286, 2: 120},
    );
    expect(
      (HypeTrainEvent.parse(htTbcStart) as HtStartEvent).train.variant,
      HtVariant.treasure,
    );
    final merge = HypeTrainEvent.parse(htTbcMerge) as HtMergeEvent;
    expect(merge.train.level, 4);
    expect(merge.previousProgress?.level.value, 2);
    expect(merge.previousChannels.single.login, 'streamer');
    expect(merge.joiningChannels.single.login, 'friend');
    final left = HypeTrainEvent.parse(htTbcChannelLeft) as HtChannelLeftEvent;
    expect(left.shouldEnd, isFalse);
    expect(left.continuesIn?.login, 'friend');
    expect(
      (HypeTrainEvent.parse(htTbcConversion) as HtStartEvent).train.id,
      'train-6',
    );
  });

  test('ignored and unknown types', () {
    expect(
      HypeTrainEvent.parse('{"type":"hype-train-cooldown-expiration"}'),
      isA<HtIgnoredEvent>(),
    );
    expect(
      (HypeTrainEvent.parse('{"type":"hype-train-new","data":{}}')
              as HtUnknownEvent)
          .type,
      'hype-train-new',
    );
  });

  test('garbage never throws', () {
    for (final bad in [
      '{',
      '[]',
      'null',
      '{"type":"hype-train-progression","data":{}}',
      '{"type":"hype-train-level-up","data":{"progress":{}}}',
      '{"type":"hype-train-start","data":"x"}',
      '{"type":5}',
    ]) {
      expect(HypeTrainEvent.parse(bad), isA<HtUnknownEvent>(), reason: bad);
    }
  });
}
