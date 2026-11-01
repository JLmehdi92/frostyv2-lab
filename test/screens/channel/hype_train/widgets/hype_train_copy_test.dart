import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_countdown.dart';

/// The hype train's English copy, as it always read (the ARB messages
/// must give the same English).
void main() {
  final copy = HtCopy(L10n.english);

  group('banner', () {
    test("numbers are grouped in the copy's language, whatever Intl holds", () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      Intl.defaultLocale = 'en';
      expect(
        HtCopy(lookupAppLocalizations(const Locale('fr'))).number(1200),
        '1\u202f200',
      );
      Intl.defaultLocale = 'fr';
      expect(copy.number(1200), '1,200');
    });

    test('the golden Kappa card reads the variant by its name', () {
      expect(copy.goldenCard, startsWith('You’ll have a limited time to earn'));
    });

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
        'About to beat the channel’s record. Keep up the support.',
      );
      expect(
        copy.athReached(),
        'Setting a new record! Keep going until the clock runs out.',
      );
      expect(copy.athReached(shared: true), contains('new shared record'));
      expect(
        copy.treasureLocked(3, 50),
        'Reach level 3 to unlock 50% off gift subs!',
      );
      expect(
        copy.treasureUnlockedSubtitle(50),
        '50% off 5+ gift subs for the rest of this Hype Train',
      );
      expect(
        copy.communityLocked(5),
        'Hit level 5 and chat will receive emotes too!',
      );
      expect(copy.communityUnlockedSubtitle(1), '1 emote for chat');
      expect(copy.communityUnlockedSubtitle(30), '30 emotes for chat');
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
      expect(copy.started(HtVariant.treasure), 'Treasure Train incoming!');
      expect(
        copy.started(HtVariant.regular, shared: true),
        'Shared Hype Train starting!',
      );
      expect(copy.levelUp, 'hyyyyypeeee');
      expect(copy.completed(HtVariant.regular), 'Hype Train success!');
      expect(copy.completed(HtVariant.mythic), 'Mythic Train success!');
      expect(
        copy.completed(HtVariant.regular, shared: true),
        'Shared Hype Train success!',
      );
      expect(copy.treasureUnlockedMarquee, 'TREASURE TRAIN UNLOCKED!');
      expect(copy.communityUnlockedMarquee, 'COMMUNITY REWARDS UNLOCKED!');
    });

    test('level complete and summary', () {
      expect(copy.levelComplete(2), 'Level 2 complete!');
      expect(copy.summary(4), 'Such strong support!\nLevel 4 completed!');
      expect(
        copy.summary(4, variant: HtVariant.treasure),
        'Such strong support!\nTreasure Train level 4 completed!',
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
        'Ann just gifted 1 Tier 1 sub!',
      );
      expect(
        copy.contribution('Ann', const HtAction('TIER_2_GIFTED_SUB'), 50),
        'Ann just gifted 50 Tier 2 subs!',
      );
      expect(
        copy.contribution('Ann', const HtAction('TIER_3_SUB'), 1),
        'Ann just subscribed at Tier 3!',
      );
      expect(
        copy.contribution(null, const HtAction('CHEER'), 2),
        'Someone just used 2 Bits!',
      );
    });

    test('totals with plurals', () {
      expect(copy.subsTotal(1), '1 sub');
      expect(copy.subsTotal(1200), '1,200 subs');
      expect(copy.bitsTotal(1), '1 Bit');
      expect(copy.bitsTotal(5000), '5,000 Bits');
    });

    test('instructions', () {
      expect(
        copy.instruction('start', const {}),
        'You’ll have a limited time to earn exclusive emotes',
      );
      expect(
        copy.instruction('treasureReachLevel', const {
          'level': 3,
        }, discount: 50),
        'Reach level 3 during this train to unlock 50% off gift subs!',
      );
      expect(
        copy.instruction('treasureOneAway', const {}),
        'One more level unlocks a discount for the rest of this train. '
        'Keep going!',
      );
      expect(
        copy.instruction('treasureUnlocked', const {}, discount: 20),
        'You’ve unlocked 20% off 5+ gift subs! Don’t miss out!',
      );
      expect(
        copy.instruction('communityReachLevel', const {'level': 5}),
        'Hit level 5 and chat will receive emotes too!',
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
        'See you next time in a Shared Hype Train!',
      );
    });

    test('shared trains', () {
      expect(copy.sharedLevel(4, 50), 'LVL 4, 50%');
      expect(copy.sharedLevelReached, 'Shared Train level reached');
      expect(copy.sharedNew, 'New Shared Hype Train');
      expect(copy.continuesIn(4), 'LVL 4 train continues in');
      expect(
        copy.otherChannelRecord('Ann'),
        'Ann’s new all-time shared record!',
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
        '1 more person needs to sub, gift, or use Bits',
      );
      expect(
        copy.approachingMore(3),
        '3 more people need to sub, gift, or use Bits',
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
      expect(copy.goldenRewards, endsWith('for 24 hours'));
      expect(copy.expired, 'You missed the train. Better luck next time!');
    });
  });

  group('details', () {
    test('headers', () {
      expect(copy.conductorsHeader, 'HYPE CONDUCTORS');
      expect(copy.rewardsHeader, 'AVAILABLE REWARDS');
      expect(copy.contributionsHeader, 'CONTRIBUTIONS');
      expect(copy.levelEmotes(7), 'Level 7 emotes');
      expect(copy.moreInfo, 'More info');
    });

    test('level target with plurals', () {
      expect(
        copy.levelTarget(7, 10, 4700),
        'Level 7 needs 10 Tier 1 subs or 4,700 Bits in total',
      );
      expect(
        copy.levelTarget(1, 1, 1),
        'Level 1 needs 1 Tier 1 sub or 1 Bit in total',
      );
    });

    test('conductors', () {
      expect(copy.subsConductor('Fan', 5), 'Fan has contributed 5 subs!');
      expect(copy.subsConductor('Fan', 1), 'Fan has contributed 1 sub!');
      expect(copy.bitsConductor('Fan', 1500), 'Fan has used 1,500 Bits');
      expect(copy.bitsConductor('Fan', 1), 'Fan has used 1 Bit');
      expect(copy.noSubsConductor, 'Sub or gift to take over this spot!');
      expect(copy.noBitsConductor, 'Use Bits to take over this spot!');
    });

    test('channel record', () {
      expect(
        copy.channelRecord(50, 9),
        'Channel all-time record! Level 9 at 50%',
      );
    });

    test('variant cards', () {
      expect(
        copy.treasureCard(3, 50, unlocked: false),
        'Unlock a limited-time 50% discount on gift subs at level 3 during '
        'this train!',
      );
      expect(
        copy.treasureCard(3, 50, unlocked: true),
        'Save 50% on 5 or more gift subs, only during this train. '
        'All aboard!',
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
    expect(copy.cardLevel(4), 'Hype Train level 4');
    expect(
      copy.cardLevel(4, variant: HtVariant.goldenKappa),
      'Golden Kappa Train level 4',
    );
    expect(copy.cardLevel(4, ath: true), 'All-time record · Level 4');
  });
}
