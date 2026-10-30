import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hype_train.dart';

import '../fixtures/hype_train_payloads.dart';
import '../fixtures/hype_train_payloads_tbc.dart';

Map _execution(String gql) =>
    ((jsonDecode(gql) as Map)['data']['user']['channel']['hypeTrain']
            as Map)['execution']
        as Map;

void main() {
  group('HypeTrainExecution from GQL', () {
    late HypeTrainExecution train;

    setUp(() => train = HypeTrainExecution.parse(_execution(htGqlActive))!);

    test('reads level and in-level progress (verified semantics)', () {
      expect(train.level, 7);
      expect(train.progress.value, 1540);
      expect(train.progress.goal, 4700);
      expect(train.progress.total, 16040);
      expect(train.progress.level.cumulativeGoal, 19200);
      expect(train.progress.level.rewards, isNotEmpty);
      expect(train.config.maxLevel, 392);
      expect(train.config.difficulty, 'EASY');
      expect(train.expiresAt, DateTime.utc(2026, 10, 13, 15, 54, 8, 880, 704));
      expect(train.variant, HtVariant.regular);
      expect(train.endReason, HtEndReason.inProgress);
    });

    test('conversion rates drop the junk entries', () {
      expect(train.config.conversionRates['TIER_1_SUB'], 500);
      expect(train.config.conversionRates['TIER_3_GIFTED_SUB'], 2500);
      expect(train.config.conversionRates['CHEER'], 1);
      expect(train.config.conversionRates.containsKey('UNKNOWN'), isFalse);
    });

    test('conductor badges come from the CURRENT rewards only', () {
      expect(
        train.config.conductorBadges.keys,
        containsAll([HtSource.bits, HtSource.subs]),
      );
      expect(
        train.config.conductorBadges[HtSource.subs],
        startsWith('https://static-cdn.jtvnw.net/badges/'),
      );
    });

    test('conductors', () {
      expect(train.conductors.map((c) => c.source), [
        HtSource.bits,
        HtSource.subs,
      ]);
      expect(train.conductors.first.user.displayName, isNotEmpty);
    });

    test('the golden kappa train and its record', () {
      final golden = HypeTrainExecution.parse(_execution(htGqlGolden))!;

      expect(golden.variant, HtVariant.goldenKappa);
      expect(golden.level, 2);
      expect(golden.ath?.level, 10);
      expect(golden.ath?.total, 32500);
      expect(golden.config.calloutEmote?.token, 'Kappa');
      expect(golden.config.kickoffMinPoints, 100);
    });

    test('a realtime start (camelCase) with a treasure in snake_case', () {
      final train = HypeTrainExecution.parse(
        (jsonDecode(htTbcStart) as Map)['data'],
      )!;

      expect(train.variant, HtVariant.treasure);
      expect(train.treasure?.discountPercentage, 35);
      expect(train.treasure?.threshold, 3);
      expect(train.treasure?.status, HtUnlockStatus.approaching);
      expect(train.config.calloutEmote?.id, '25');
      expect(train.progress.value, 1500);
      expect(train.endReason, HtEndReason.inProgress);
    });

    test('community, mythic and shared details', () {
      final community = HypeTrainExecution.parse(jsonDecode(htTbcCommunity))!;
      expect(community.variant, HtVariant.community);
      expect(community.community?.threshold, 5, reason: 'null → default 5');
      expect(community.community?.next, 20);
      expect(community.progress.athState, HtAthState.approaching);

      final mythic = HypeTrainExecution.parse(jsonDecode(htTbcMythic))!;
      expect(mythic.variant, HtVariant.mythic);
      expect(mythic.mythic?.pool.map((e) => e.token), [
        'chanHype1',
        'chanHype2',
      ]);
      expect(mythic.mythic?.selectedEmote, isNull);

      final shared = HypeTrainExecution.parse(jsonDecode(htTbcShared))!;
      final channels = shared.shared!.channels;
      expect(channels.map((c) => c.user.login), ['streamer', 'friend']);
      expect(channels.first.progress?.total, 3000);
      expect(channels.first.ath?.level, 8);
      expect(channels.last.ath, isNull);
    });

    test('pinata renders as regular; garbage is null', () {
      expect(htVariantOf({'hypeTrainType': 'PINATA'}), HtVariant.regular);
      expect(HypeTrainExecution.parse(null), isNull);
      expect(HypeTrainExecution.parse({'id': 'x'}), isNull);
      expect(HypeTrainExecution.parse({'progress': {}}), isNull);
    });
  });

  group('HypeTrainApproaching', () {
    test('from the realtime map (bad keys skipped)', () {
      final approaching = HypeTrainApproaching.parse(
        (jsonDecode(htTbcApproachingEvent) as Map)['data'],
      )!;

      expect(approaching.id, 'approach-1');
      expect(approaching.goal, 3);
      expect(approaching.deadlines, {1: 286, 2: 120});
      expect(approaching.participants, {'900001'});
      expect(approaching.levelOneRewards.single.token, 'chanHype1');
    });

    test('from the GQL list', () {
      final approaching = HypeTrainApproaching.parse(
        (jsonDecode(htTbcGqlApproaching)
            as Map)['data']['user']['channel']['hypeTrain']['approaching'],
      )!;

      expect(approaching.deadlines, {1: 250});
      expect(approaching.variant, HtVariant.treasure);
      expect(approaching.levelOneRewards.single.emoteUrl, isNotNull);
    });
  });

  group('safety', () {
    test('emote URLs only for well-formed ids', () {
      HtReward emote(String id) => HtReward(type: HtRewardType.emote, id: id);

      expect(
        emote('emotesv2_00000000000000000000000000000001').emoteUrl.toString(),
        'https://static-cdn.jtvnw.net/emoticons/v2/'
        'emotesv2_00000000000000000000000000000001/default/dark/3.0',
      );
      expect(emote('../x').emoteUrl, isNull);
      expect(emote('25?x=1').emoteUrl, isNull);
    });

    test('badge and avatar URLs only from the Twitch CDN over https', () {
      const ok = 'https://static-cdn.jtvnw.net/badges/v1/x/2';
      expect(htCdnUrl(ok).toString(), ok);
      expect(htCdnUrl('http://static-cdn.jtvnw.net/badges/v1/x/2'), isNull);
      expect(htCdnUrl('https://evil.example/x.png'), isNull);
      expect(htCdnUrl('https://static-cdn.jtvnw.net.evil.example/x'), isNull);
      expect(htCdnUrl(null), isNull);
    });

    test('wrongly typed fields fall back instead of throwing', () {
      final train = HypeTrainExecution.parse({
        'id': 'x',
        'progress': {
          'level': {'value': 2, 'goal': []},
          'goal': '1',
          'progression': null,
          'total': 3.7,
        },
        'conductors': 'nope',
        'config': {'participationConversionRates': 5},
        'expiresAt': 12,
      })!;

      expect(train.level, 2);
      expect(train.progress.total, 3);
      expect(
        HypeTrainExecution.parse({
          'id': 'x',
          'progress': {
            'level': {'value': 'two'},
            'total': 3,
          },
        }),
        isNull,
        reason: 'no usable level, no train',
      );
      expect(train.conductors, isEmpty);
      expect(train.config.conversionRates, isEmpty);
    });

    test('hostile numbers and dates never throw', () {
      Map<String, Object?> train(Map<String, Object?> extra) => {
        'id': 'x',
        'progress': {
          'total': 1,
          'level': {'value': 1},
        },
        ...extra,
      };

      final epoch = HypeTrainExecution.parse(train({'startedAt': 9e15}));
      expect(epoch!.startedAt, isNull);
      expect(
        HypeTrainExecution.parse(
          train({'startedAt': '+999999-01-01T00:00:00Z'}),
        )!.startedAt,
        isNull,
      );
      expect(
        HypeTrainExecution.parse(
          train({'endedAt': '0001-01-01T00:00:00Z'}),
        )!.endedAt,
        isNull,
        reason: "Go's zero time means unset",
      );

      final infinite = jsonDecode(
        '{"source":"SUBS","user":{"id":"1","login":"a"},'
        '"participations":{"SUBS.TIER_1_SUB":1e400,"SUBS.CHEER":1e20}}',
      );
      expect(HtConductor.parse(infinite)!.participations, isEmpty);

      final approaching = HypeTrainApproaching.parse({
        'approaching_hype_train_id': 'a',
        'events_remaining_durations': jsonDecode('{"1":1e400,"2":30}'),
      });
      expect(approaching!.deadlines, {2: 30});
    });

    test('an empty progress is no progress', () {
      expect(HtProgress.parse(const {}), isNull);
      expect(
        HtProgress.parse(const {
          'total': 5,
          'level': {'value': 0},
        }),
        isNull,
      );
      final negative = HtProgress.parse(const {
        'total': -5,
        'goal': -1,
        'progression': -2,
        'level': {'value': 2},
      })!;
      expect([negative.total, negative.goal, negative.value], [0, 0, 0]);
    });

    test('participations of the same action add up', () {
      final conductor = HtConductor.parse({
        'source': 'BITS',
        'user': {'id': '1', 'login': 'a'},
        'participations': {'BITS.CHEER': 5, 'X.CHEER': 7},
      })!;

      expect(conductor.participations, {'CHEER': 12});
    });

    test('lists are capped', () {
      final rewards = [
        for (var i = 0; i < 5000; i++)
          {
            'id': 'e$i',
            'type': 'EMOTE',
            'emote': {'id': 'e$i', 'token': 't'},
          },
      ];

      expect(htRewards(htList({'r': rewards}, ['r'])), hasLength(200));
    });

    test('CDN URLs refuse userinfo and ports', () {
      expect(htCdnUrl('https://x@static-cdn.jtvnw.net/a.png'), isNull);
      expect(htCdnUrl('https://static-cdn.jtvnw.net:8443/a.png'), isNull);
      expect(htCdnUrl('https://static-cdn.jtvnw.net/a.png'), isNotNull);
    });

    test('a running GQL train without a reason is in progress', () {
      final train = HypeTrainExecution.parse({
        'id': 'x',
        'isActive': true,
        'endReason': null,
        'progress': {
          'total': 1,
          'level': {'value': 1},
        },
      })!;

      expect(train.endReason, HtEndReason.inProgress);
    });
  });
}
