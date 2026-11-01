import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_countdown.dart';

/// The hype train's English copy, as it always read (the ARB messages
/// must give the same English).
void main() {
  final copy = HtCopy(L10n.english);

  group('banner', () {
    test('level pill, percentage and countdown', () {
      expect(copy.level(7), 'LVL 7');
      expect(copy.percent(33), '33%');
      expect(HtCopy.countdown(const Duration(seconds: 16)), '0:16');
      expect(HtCopy.countdown(const Duration(seconds: 75)), '1:15');
      expect(HtCopy.countdown(const Duration(seconds: 3725)), '1:02:05');
      expect(HtCopy.countdown(Duration.zero), '0:00');
      expect(HtCopy.countdown(const Duration(seconds: -3)), '0:00');
      expect(HypeTrainCountdown.format(const Duration(seconds: 16)), '0:16');
    });

    test('subtitles', () {
      expect(copy.subtitle, 'Sub, gift, or use Bits!');
      expect(copy.finalLevel, 'Final level!');
      expect(
        copy.athApproaching,
        'About to beat your last record. Keep up the support.',
      );
      expect(
        copy.athReached(),
        'Setting a new record! Keep going until the clock runs out.',
      );
      expect(copy.athReached(shared: true), contains('new shared record'));
      expect(
        copy.treasureLocked(3, 50),
        'Reach Level 3 to unlock 50% OFF Gift Subs!',
      );
      expect(
        copy.treasureUnlockedSubtitle(50),
        '50% OFF 5+ Gift Subs for the rest of this Hype Train',
      );
      expect(
        copy.communityLocked(5),
        'Hit Level 5 and chat will receive emotes too!',
      );
      expect(copy.communityUnlockedSubtitle(1), '1 Emote for Chat');
      expect(copy.communityUnlockedSubtitle(30), '30 Emotes for Chat');
    });

    test('train titles per variant', () {
      expect(copy.trainTitle(HtVariant.regular), 'Hype Train');
      expect(copy.trainTitle(HtVariant.goldenKappa), 'Golden Kappa Train');
      expect(copy.trainTitle(HtVariant.treasure), 'Treasure Train');
      expect(copy.trainTitle(HtVariant.community), 'Community Train');
      expect(copy.trainTitle(HtVariant.mythic), 'Mythic Train');
      expect(
        copy.trainTitle(HtVariant.regular, shared: true),
        'Shared Hype Train',
      );
      expect(
        copy.trainTitle(HtVariant.treasure, shared: true),
        'Shared Hype Train',
      );
      expect(
        copy.trainTitle(HtVariant.community, shared: true),
        'Shared Community Train',
      );
      expect(
        copy.trainTitle(HtVariant.mythic, shared: true),
        'Shared Mythic Train',
      );
      expect(
        copy.trainTitle(HtVariant.goldenKappa, shared: true),
        'Shared Golden Kappa Train',
      );
    });
  });

  group('announcements', () {
    test('marquees', () {
      expect(copy.started(HtVariant.regular), 'Hype Train starting!');
      expect(
        copy.started(HtVariant.goldenKappa),
        'Golden Kappa Train starting!',
      );
      expect(copy.started(HtVariant.treasure), 'Treasure Train Incoming!');
      expect(
        copy.started(HtVariant.regular, shared: true),
        'Shared Hype Train starting!',
      );
      expect(copy.levelUp, 'hyyyyypeeee');
      expect(copy.completed(HtVariant.regular), 'Hype Train success!');
      expect(copy.completed(HtVariant.mythic), 'Mythic Train Success!');
      expect(
        copy.completed(HtVariant.regular, shared: true),
        'Shared Hype Train success!',
      );
      expect(copy.treasureUnlockedMarquee, 'TREASURE TRAIN UNLOCKED!');
      expect(copy.communityUnlockedMarquee, 'COMMUNITY REWARDS UNLOCKED!');
    });

    test('level complete and summary', () {
      expect(copy.levelComplete(2), 'Level 2 Complete!');
      expect(copy.summary(4), 'Such strong support\nLevel 4 completed!');
      expect(
        copy.summary(4, variant: HtVariant.treasure),
        'Such strong support\nTreasure Train Level 4 completed!',
      );
      expect(copy.summary(4, ath: true), startsWith('All-time record'));
    });

    test('large contributions with plurals', () {
      expect(
        copy.contribution('Ann', const HtAction('CHEER'), 1),
        'Ann just used 1 Bit!',
      );
      expect(
        copy.contribution('Ann', const HtAction('CHEER'), 1500),
        'Ann just used 1,500 Bits!',
      );
      expect(
        copy.contribution('Ann', const HtAction('TIER_1_GIFTED_SUB'), 1),
        'Ann just gifted 1 Tier 1 Sub!',
      );
      expect(
        copy.contribution('Ann', const HtAction('TIER_2_GIFTED_SUB'), 50),
        'Ann just gifted 50 Tier 2 Subs!',
      );
      expect(
        copy.contribution('Ann', const HtAction('TIER_3_SUB'), 1),
        'Ann just subscribed with a Tier 3 Sub!',
      );
      expect(
        copy.contribution(null, const HtAction('CHEER'), 2),
        'Someone just used 2 Bits!',
      );
    });

    test('totals with plurals', () {
      expect(copy.subsTotal(1), '1 Sub');
      expect(copy.subsTotal(1200), '1,200 Subs');
      expect(copy.bitsTotal(1), '1 Bit');
      expect(copy.bitsTotal(5000), '5,000 Bits');
    });

    test('instructions', () {
      expect(
        copy.instruction('start', const {}),
        "You'll have a limited time to earn exclusive emotes",
      );
      expect(
        copy.instruction('treasureReachLevel', const {
          'level': 3,
        }, discount: 50),
        'Reach Level 3 during this train to unlock 50% OFF Gift Subs!',
      );
      expect(
        copy.instruction('treasureOneAway', const {}),
        'One more level unlocks a discount for the rest of this train, '
        'keep going!',
      );
      expect(
        copy.instruction('treasureUnlocked', const {}, discount: 20),
        "You've unlocked 20% OFF on 5+ Gift Subs! Don't miss out!",
      );
      expect(
        copy.instruction('communityReachLevel', const {'level': 5}),
        'Hit Level 5 and chat will receive emotes too!',
      );
      expect(
        copy.instruction('communityUnlocked', const {}, amount: 1),
        'You unlocked 1 emote for chat! Level up to give away more emotes.',
      );
      expect(
        copy.instruction('mythicPool', const {}, amount: 6),
        'Unlock 1 of 6 exclusive emotes for 24 hours!',
      );
      expect(
        copy.instruction('seeYouNextTime', const {}),
        'See you next time in Shared Hype Train!',
      );
    });

    test('shared trains', () {
      expect(copy.sharedLevel(4, 50), 'LVL 4, 50%');
      expect(copy.sharedLevelReached, 'Shared Train level reached');
      expect(copy.sharedNew, 'New Shared Hype Train');
      expect(copy.continuesIn(4), 'LVL 4 train continues in');
      expect(
        copy.otherChannelRecord('Ann'),
        "Ann's new all-time Shared record!",
      );
    });
  });

  group('approaching', () {
    test('title and subtitle', () {
      expect(
        copy.approachingTitle(HtVariant.regular),
        'A Hype Train is approaching!',
      );
      expect(
        copy.approachingTitle(HtVariant.goldenKappa),
        'Golden Kappa Train approaching!',
      );
      expect(
        copy.approachingSubtitle(HtVariant.regular),
        'Sub, gift, or use Bits now to start a Hype Train',
      );
      expect(
        copy.approachingMore(1),
        '1 more person needs to sub, gift or use Bits',
      );
      expect(
        copy.approachingMore(3),
        '3 more people need to sub, gift or use Bits',
      );
      expect(copy.approachingShort, 'Approaching');
    });
  });

  group('strips', () {
    test('rewards and expired', () {
      expect(
        copy.rewards,
        'Great work! Emotes are being delivered to supporters',
      );
      expect(copy.goldenRewards, endsWith('for 24 hrs'));
      expect(copy.expired, 'You missed the Train. Better luck next time!');
    });
  });

  group('details', () {
    test('headers', () {
      expect(copy.conductorsHeader, 'HYPE CONDUCTORS');
      expect(copy.rewardsHeader, 'AVAILABLE REWARDS');
      expect(copy.contributionsHeader, 'CONTRIBUTIONS');
      expect(copy.levelEmotes(7), 'Level 7 emotes');
      expect(copy.moreInfo, 'More Info');
    });

    test('level target with plurals', () {
      expect(
        copy.levelTarget(7, 10, 4700),
        'Completing Level 7 requires combined support events totaling '
        '10 Tier 1 Subs or 4,700 Bits',
      );
      expect(
        copy.levelTarget(1, 1, 1),
        'Completing Level 1 requires combined support events totaling '
        '1 Tier 1 Sub or 1 Bit',
      );
    });

    test('conductors', () {
      expect(copy.subsConductor('Fan', 5), 'Fan has contributed 5 Subs!');
      expect(copy.subsConductor('Fan', 1), 'Fan has contributed 1 Sub!');
      expect(copy.bitsConductor('Fan', 1500), 'Fan has used 1,500 Bits');
      expect(copy.bitsConductor('Fan', 1), 'Fan has used 1 Bit');
      expect(copy.noSubsConductor, 'Sub or Gift to take over this spot!');
      expect(copy.noBitsConductor, 'Use Bits to take over this spot!');
    });

    test('channel record', () {
      expect(copy.channelRecord(50, 9), 'Channel all-time record! 50% Level 9');
    });

    test('variant cards', () {
      expect(
        copy.treasureCard(3, 50, unlocked: false),
        'Unlock a limited-time 50% OFF Gift Subs at Level 3 during this '
        'train!',
      );
      expect(
        copy.treasureCard(3, 50, unlocked: true),
        'Save 50% on 5 or more Gift Subs exclusively during this train. '
        'All Aboard!',
      );
      expect(
        copy.communityCard(5, 30, unlocked: true),
        'You unlocked 30 emotes for chat! Level up to give away more '
        'emotes.',
      );
      expect(copy.mythicCard(1), 'Unlock 1 of 1 exclusive emote for 24 hours!');
    });
  });

  test('followed card', () {
    expect(copy.cardLevel(4), 'Hype Train Level 4');
    expect(
      copy.cardLevel(4, variant: HtVariant.goldenKappa),
      'Golden Kappa Train Level 4',
    );
    expect(copy.cardLevel(4, ath: true), 'All-Time High Train Level 4');
  });
}
