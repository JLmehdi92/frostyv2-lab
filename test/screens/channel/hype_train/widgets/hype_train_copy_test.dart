import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_countdown.dart';

void main() {
  group('banner', () {
    test('level pill, percentage and countdown', () {
      expect(HtCopy.level(7), 'LVL 7');
      expect(HtCopy.percent(33), '33%');
      expect(HtCopy.countdown(const Duration(seconds: 16)), '0:16');
      expect(HtCopy.countdown(const Duration(seconds: 75)), '1:15');
      expect(HtCopy.countdown(const Duration(seconds: 3725)), '1:02:05');
      expect(HtCopy.countdown(Duration.zero), '0:00');
      expect(HtCopy.countdown(const Duration(seconds: -3)), '0:00');
      expect(HypeTrainCountdown.format(const Duration(seconds: 16)), '0:16');
    });

    test('subtitles', () {
      expect(HtCopy.subtitle, 'Sub, gift, or use Bits!');
      expect(HtCopy.finalLevel, 'Final level!');
      expect(
        HtCopy.athApproaching,
        'About to beat your last record. Keep up the support.',
      );
      expect(
        HtCopy.athReached(),
        'Setting a new record! Keep going until the clock runs out.',
      );
      expect(HtCopy.athReached(shared: true), contains('new shared record'));
      expect(
        HtCopy.treasureLocked(3, 50),
        'Reach Level 3 to unlock 50% OFF Gift Subs!',
      );
      expect(
        HtCopy.treasureUnlockedSubtitle(50),
        '50% OFF 5+ Gift Subs for the rest of this Hype Train',
      );
      expect(
        HtCopy.communityLocked(5),
        'Hit Level 5 and chat will receive emotes too!',
      );
      expect(HtCopy.communityUnlockedSubtitle(1), '1 Emote for Chat');
      expect(HtCopy.communityUnlockedSubtitle(30), '30 Emotes for Chat');
    });

    test('train titles per variant', () {
      expect(HtCopy.trainTitle(HtVariant.regular), 'Hype Train');
      expect(HtCopy.trainTitle(HtVariant.goldenKappa), 'Golden Kappa Train');
      expect(HtCopy.trainTitle(HtVariant.treasure), 'Treasure Train');
      expect(HtCopy.trainTitle(HtVariant.community), 'Community Train');
      expect(HtCopy.trainTitle(HtVariant.mythic), 'Mythic Train');
      expect(
        HtCopy.trainTitle(HtVariant.regular, shared: true),
        'Shared Hype Train',
      );
      expect(
        HtCopy.trainTitle(HtVariant.treasure, shared: true),
        'Shared Hype Train',
      );
      expect(
        HtCopy.trainTitle(HtVariant.community, shared: true),
        'Shared Community Train',
      );
      expect(
        HtCopy.trainTitle(HtVariant.mythic, shared: true),
        'Shared Mythic Train',
      );
      expect(
        HtCopy.trainTitle(HtVariant.goldenKappa, shared: true),
        'Shared Golden Kappa Train',
      );
    });
  });

  group('announcements', () {
    test('marquees', () {
      expect(HtCopy.started(HtVariant.regular), 'Hype Train starting!');
      expect(
        HtCopy.started(HtVariant.goldenKappa),
        'Golden Kappa Train starting!',
      );
      expect(HtCopy.started(HtVariant.treasure), 'Treasure Train Incoming!');
      expect(
        HtCopy.started(HtVariant.regular, shared: true),
        'Shared Hype Train starting!',
      );
      expect(HtCopy.levelUp, 'hyyyyypeeee');
      expect(HtCopy.completed(HtVariant.regular), 'Hype Train success!');
      expect(HtCopy.completed(HtVariant.mythic), 'Mythic Train Success!');
      expect(
        HtCopy.completed(HtVariant.regular, shared: true),
        'Shared Hype Train success!',
      );
      expect(HtCopy.treasureUnlockedMarquee, 'TREASURE TRAIN UNLOCKED!');
      expect(HtCopy.communityUnlockedMarquee, 'COMMUNITY REWARDS UNLOCKED!');
    });

    test('level complete and summary', () {
      expect(HtCopy.levelComplete(2), 'Level 2 Complete!');
      expect(HtCopy.summary(4), 'Such strong support\nLevel 4 completed!');
      expect(
        HtCopy.summary(4, variant: HtVariant.treasure),
        'Such strong support\nTreasure Train Level 4 completed!',
      );
      expect(HtCopy.summary(4, ath: true), startsWith('All-time record'));
    });

    test('large contributions with plurals', () {
      expect(
        HtCopy.contribution('Ann', const HtAction('CHEER'), 1),
        'Ann just used 1 Bit!',
      );
      expect(
        HtCopy.contribution('Ann', const HtAction('CHEER'), 1500),
        'Ann just used 1,500 Bits!',
      );
      expect(
        HtCopy.contribution('Ann', const HtAction('TIER_1_GIFTED_SUB'), 1),
        'Ann just gifted 1 Tier 1 Sub!',
      );
      expect(
        HtCopy.contribution('Ann', const HtAction('TIER_2_GIFTED_SUB'), 50),
        'Ann just gifted 50 Tier 2 Subs!',
      );
      expect(
        HtCopy.contribution('Ann', const HtAction('TIER_3_SUB'), 1),
        'Ann just subscribed with a Tier 3 Sub!',
      );
      expect(
        HtCopy.contribution(null, const HtAction('CHEER'), 2),
        'Someone just used 2 Bits!',
      );
    });

    test('totals with plurals', () {
      expect(HtCopy.subsTotal(1), '1 Sub');
      expect(HtCopy.subsTotal(1200), '1,200 Subs');
      expect(HtCopy.bitsTotal(1), '1 Bit');
      expect(HtCopy.bitsTotal(5000), '5,000 Bits');
    });

    test('instructions', () {
      expect(
        HtCopy.instruction('start', const {}),
        "You'll have a limited time to earn exclusive emotes",
      );
      expect(
        HtCopy.instruction('treasureReachLevel', const {
          'level': 3,
        }, discount: 50),
        'Reach Level 3 during this train to unlock 50% OFF Gift Subs!',
      );
      expect(
        HtCopy.instruction('treasureOneAway', const {}),
        'One more level unlocks a discount for the rest of this train, '
        'keep going!',
      );
      expect(
        HtCopy.instruction('treasureUnlocked', const {}, discount: 20),
        "You've unlocked 20% OFF on 5+ Gift Subs! Don't miss out!",
      );
      expect(
        HtCopy.instruction('communityReachLevel', const {'level': 5}),
        'Hit Level 5 and chat will receive emotes too!',
      );
      expect(
        HtCopy.instruction('communityUnlocked', const {}, amount: 1),
        'You unlocked 1 emote for chat! Level up to give away more emotes.',
      );
      expect(
        HtCopy.instruction('mythicPool', const {}, amount: 6),
        'Unlock 1 of 6 exclusive emotes for 24 hours!',
      );
      expect(
        HtCopy.instruction('seeYouNextTime', const {}),
        'See you next time in Shared Hype Train!',
      );
    });

    test('shared trains', () {
      expect(HtCopy.sharedLevel(4, 50), 'LVL 4, 50%');
      expect(HtCopy.sharedLevelReached, 'Shared Train level reached');
      expect(HtCopy.sharedNew, 'New Shared Hype Train');
      expect(HtCopy.continuesIn(4), 'LVL 4 train continues in');
      expect(
        HtCopy.otherChannelRecord('Ann'),
        "Ann's new all-time Shared record!",
      );
    });
  });

  group('approaching', () {
    test('title and subtitle', () {
      expect(
        HtCopy.approachingTitle(HtVariant.regular),
        'A Hype Train is approaching!',
      );
      expect(
        HtCopy.approachingTitle(HtVariant.goldenKappa),
        'Golden Kappa Train approaching!',
      );
      expect(
        HtCopy.approachingSubtitle(HtVariant.regular),
        'Sub, gift, or use Bits now to start a Hype Train',
      );
      expect(
        HtCopy.approachingMore(1),
        '1 more person needs to sub, gift or use Bits',
      );
      expect(
        HtCopy.approachingMore(3),
        '3 more people need to sub, gift or use Bits',
      );
      expect(HtCopy.approachingShort, 'Approaching');
    });
  });

  group('strips', () {
    test('rewards and expired', () {
      expect(
        HtCopy.rewards,
        'Great work! Emotes are being delivered to supporters',
      );
      expect(HtCopy.goldenRewards, endsWith('for 24 hrs'));
      expect(HtCopy.expired, 'You missed the Train. Better luck next time!');
    });
  });

  group('details', () {
    test('headers', () {
      expect(HtCopy.conductorsHeader, 'HYPE CONDUCTORS');
      expect(HtCopy.rewardsHeader, 'AVAILABLE REWARDS');
      expect(HtCopy.contributionsHeader, 'CONTRIBUTIONS');
      expect(HtCopy.levelEmotes(7), 'Level 7 emotes');
      expect(HtCopy.moreInfo, 'More Info');
    });

    test('level target with plurals', () {
      expect(
        HtCopy.levelTarget(7, 10, 4700),
        'Completing Level 7 requires combined support events totaling '
        '10 Tier 1 Subs or 4,700 Bits',
      );
      expect(
        HtCopy.levelTarget(1, 1, 1),
        'Completing Level 1 requires combined support events totaling '
        '1 Tier 1 Sub or 1 Bit',
      );
    });

    test('conductors', () {
      expect(HtCopy.subsConductor(5), 'has contributed 5 Subs!');
      expect(HtCopy.subsConductor(1), 'has contributed 1 Sub!');
      expect(HtCopy.bitsConductor(1500), 'has used 1,500 Bits');
      expect(HtCopy.bitsConductor(1), 'has used 1 Bit');
      expect(HtCopy.noSubsConductor, 'Sub or Gift to take over this spot!');
      expect(HtCopy.noBitsConductor, 'Use Bits to take over this spot!');
    });

    test('channel record', () {
      expect(
        HtCopy.channelRecord(50, 9),
        'Channel all-time record! 50% Level 9',
      );
    });

    test('variant cards', () {
      expect(
        HtCopy.treasureCard(3, 50, unlocked: false),
        'Unlock a limited-time 50% OFF Gift Subs at Level 3 during this '
        'train!',
      );
      expect(
        HtCopy.treasureCard(3, 50, unlocked: true),
        'Save 50% on 5 or more Gift Subs exclusively during this train. '
        'All Aboard!',
      );
      expect(
        HtCopy.communityCard(5, 30, unlocked: true),
        'You unlocked 30 emotes for chat! Level up to give away more '
        'emotes.',
      );
      expect(
        HtCopy.mythicCard(1),
        'Unlock 1 of 1 exclusive emote for 24 hours!',
      );
    });
  });

  test('followed card', () {
    expect(HtCopy.cardLevel(4), 'Hype Train Level 4');
    expect(
      HtCopy.cardLevel(4, variant: HtVariant.goldenKappa),
      'Golden Kappa Train Level 4',
    );
    expect(HtCopy.cardLevel(4, ath: true), 'All-Time High Train Level 4');
  });
}
