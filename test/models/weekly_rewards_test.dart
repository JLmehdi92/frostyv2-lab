import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/weekly_rewards.dart';

import '../fixtures/weekly_rewards_payloads.dart';

void main() {
  group('weekly rewards', () {
    test('reads the week, the levels in order and the resets', () {
      final rewards = WeeklyRewards.fromBody(weeklyRewardsResponse())!;

      expect(rewards.daysShown, 2);
      expect(rewards.daysRequiredPerWeek, 3);
      expect(rewards.currentTier!.tier, 1);
      expect(rewards.tiers.map((tier) => tier.tier), [1, 2]);
      expect(rewards.tiers.last.badgeUrl, isNull);
      expect(rewards.endsAt, DateTime.utc(2026, 12));
      expect(
        rewards.nextResetAfter(DateTime.utc(2026, 11, 10)),
        DateTime.utc(2026, 11, 15),
      );
      expect(rewards.isComplete, isFalse);
    });

    test('the top level earned this week is complete', () {
      final rewards = WeeklyRewards.fromBody(
        weeklyRewardsResponse(visited: 5, currentTier: 2, earned: true),
      )!;

      expect(rewards.isComplete, isTrue);
      expect(rewards.daysShown, 3);
    });

    test('no event, no card', () {
      expect(WeeklyRewards.fromBody(noWeeklyRewardsResponse), isNull);
      expect(WeeklyRewards.fromBody(null), isNull);
      expect(WeeklyRewards.fromBody({'data': {}}), isNull);
    });
  });

  group('community moments', () {
    test('a moment needs a usable id', () {
      final moment = CommunityMoment.fromEvent({
        'moment_id': 'm-1',
        'channel_id': '1000',
        'clip_slug': 'Clip',
      })!;
      expect(moment.id, 'm-1');
      expect(moment.clipSlug, 'Clip');
      expect(CommunityMoment.fromEvent({'moment_id': 'bad id'}), isNull);
      expect(CommunityMoment.fromEvent({}), isNull);
    });

    test('a claim maps what Twitch answers', () {
      Map<String, Object?> body(Object? error) => {
        'data': {
          'claimCommunityMoment': {
            'moment': error == null ? {'id': 'm'} : null,
            'error': error,
          },
        },
      };
      expect(MomentClaimResult.fromBody(body(null)), MomentClaimResult.claimed);
      expect(
        MomentClaimResult.fromBody(body('ALREADY_CLAIMED')),
        MomentClaimResult.alreadyClaimed,
      );
      expect(
        MomentClaimResult.fromBody(body('CLAIM_PERIOD_EXPIRED')),
        MomentClaimResult.expired,
      );
      expect(
        MomentClaimResult.fromBody(body('INVALID_MOMENT_ID')),
        MomentClaimResult.invalid,
      );
      expect(
        MomentClaimResult.fromBody(body('UNKNOWN')),
        MomentClaimResult.failed,
      );
      expect(
        MomentClaimResult.fromBody({
          'errors': [
            {'message': 'failed integrity check'},
          ],
        }),
        MomentClaimResult.integrityRefused,
      );
      expect(MomentClaimResult.fromBody('x'), MomentClaimResult.failed);
    });
  });

  group('unlockable emotes', () {
    test('only valid tier 1 emotes are offered', () {
      final emotes = UnlockableEmote.listFrom(unlockableEmotesResponse)!;

      expect(emotes.map((e) => e.token), ['chanHi', 'chanGg']);
      expect(emotes.first.modifiedId('BW'), 'emotesv2_aaa_BW');
      expect(emotes.first.imageUrl, startsWith('https://static-cdn.jtvnw.net'));
      expect(UnlockableEmote.listFrom(null), isNull);
    });
  });
}
