import 'package:frosty/models/hype_train.dart';
import 'package:intl/intl.dart';

/// The hype train's English copy, in the official app's wording (a
/// personal build: decision S1).
abstract final class HtCopy {
  static final _number = NumberFormat.decimalPattern();

  static String number(int value) => _number.format(value);

  static String _plural(int n, String one, String other) =>
      n == 1 ? one : other;

  // --- Names -----------------------------------------------------------------

  static const title = 'Hype Train';

  /// The train's name: its variant, "Shared" when several channels run it.
  static String trainTitle(HtVariant variant, {bool shared = false}) {
    if (shared) {
      return switch (variant) {
        HtVariant.goldenKappa => 'Shared Golden Kappa Train',
        HtVariant.community => 'Shared Community Train',
        HtVariant.mythic => 'Shared Mythic Train',
        HtVariant.regular || HtVariant.treasure => 'Shared Hype Train',
      };
    }
    return switch (variant) {
      HtVariant.goldenKappa => 'Golden Kappa Train',
      HtVariant.treasure => 'Treasure Train',
      HtVariant.community => 'Community Train',
      HtVariant.mythic => 'Mythic Train',
      HtVariant.regular => title,
    };
  }

  // --- Banner ----------------------------------------------------------------

  static String level(int level) => 'LVL $level';

  static String percent(int value) => '$value%';

  /// `m:ss`, or `h:mm:ss` from an hour.
  static String countdown(Duration remaining) {
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    final hours = total ~/ 3600;
    final minutes = total % 3600 ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  static const subtitle = 'Sub, gift, or use Bits!';
  static const finalLevel = 'Final level!';
  static const athApproaching =
      'About to beat your last record. Keep up the support.';
  static const athApproachingCompact = 'About to beat your last record.';

  static String athReached({bool shared = false}) => shared
      ? 'Setting a new shared record! Keep going until the clock runs out.'
      : 'Setting a new record! Keep going until the clock runs out.';

  static String treasureLocked(int level, int discount) =>
      'Reach Level $level to unlock $discount% OFF Gift Subs!';

  static String treasureUnlockedSubtitle(int discount) =>
      '$discount% OFF 5+ Gift Subs for the rest of this Hype Train';

  static String communityLocked(int level) =>
      'Hit Level $level and chat will receive emotes too!';

  static String communityUnlockedSubtitle(int emotes) =>
      '${number(emotes)} ${_plural(emotes, 'Emote', 'Emotes')} for Chat';

  // --- Announcements ---------------------------------------------------------

  static String levelComplete(int level) => 'Level $level Complete!';

  /// The start marquee (three callout emotes follow it).
  static String started(HtVariant variant, {bool shared = false}) {
    if (shared) {
      return variant == HtVariant.goldenKappa
          ? 'Shared Golden Kappa Train starting!'
          : 'Shared Hype Train starting!';
    }
    return switch (variant) {
      HtVariant.regular => 'Hype Train starting!',
      HtVariant.goldenKappa => 'Golden Kappa Train starting!',
      HtVariant.treasure => 'Treasure Train Incoming!',
      HtVariant.community => 'Community Train Incoming!',
      HtVariant.mythic => 'Mythic Train Incoming!',
    };
  }

  /// The level-up marquee.
  static const levelUp = 'hyyyyypeeee';

  /// The completed marquee.
  static String completed(HtVariant variant, {bool shared = false}) {
    if (shared) {
      return variant == HtVariant.goldenKappa
          ? 'Shared Golden Kappa Train success!'
          : 'Shared Hype Train success!';
    }
    return switch (variant) {
      HtVariant.regular => 'Hype Train success!',
      HtVariant.goldenKappa => 'Golden Kappa Train success!',
      HtVariant.treasure => 'Treasure Train Success!',
      HtVariant.community => 'Community Train Success!',
      HtVariant.mythic => 'Mythic Train Success!',
    };
  }

  static const treasureUnlockedMarquee = 'TREASURE TRAIN UNLOCKED!';
  static const communityUnlockedMarquee = 'COMMUNITY REWARDS UNLOCKED!';
  static const merging =
      'Get excited! Your powers are combining and levels are getting a boost!';

  static String summary(
    int level, {
    bool ath = false,
    HtVariant variant = HtVariant.regular,
  }) {
    if (ath) {
      return "All-time record shattered!\nYou've reached new levels of "
          'support!';
    }
    final name = switch (variant) {
      HtVariant.treasure => 'Treasure Train ',
      HtVariant.community => 'Community Train ',
      HtVariant.mythic => 'Mythic Train ',
      HtVariant.regular || HtVariant.goldenKappa => '',
    };
    return 'Such strong support\n${name}Level $level completed!';
  }

  static const athReachedTitle = 'All-time record shattered!';

  static String contribution(String? name, HtAction action, int quantity) {
    final who = name ?? 'Someone';
    final amount = number(quantity);
    if (action.isCheer) {
      return '$who just used $amount ${_plural(quantity, 'Bit', 'Bits')}!';
    }
    if (action.subTier case final tier?) {
      if (action.isGift) {
        return '$who just gifted $amount Tier $tier '
            '${_plural(quantity, 'Sub', 'Subs')}!';
      }
      return '$who just subscribed with a Tier $tier Sub!';
    }
    return '$who just boosted the train!';
  }

  static String subsTotal(int subs) =>
      '${number(subs)} ${_plural(subs, 'Sub', 'Subs')}';

  static String bitsTotal(int bits) =>
      '${number(bits)} ${_plural(bits, 'Bit', 'Bits')}';

  /// An instruction step's text; [discount] for treasure trains, [amount]
  /// for community emotes or the mythic pool.
  static String instruction(
    String key,
    Map<String, Object?> data, {
    HtVariant variant = HtVariant.regular,
    int discount = 35,
    int amount = 0,
  }) {
    final level = data['level'];
    return switch (key) {
      'start' => switch (variant) {
        HtVariant.goldenKappa =>
          "You'll have a limited time to earn an exclusive golden Kappa "
              'emote for 24 hrs',
        HtVariant.community => 'Whoa, this is a rare Community Train!',
        HtVariant.mythic => 'Whoa, this is a rare Mythic Train!',
        HtVariant.regular || HtVariant.treasure =>
          "You'll have a limited time to earn exclusive emotes",
      },
      'treasureReachLevel' =>
        'Reach Level $level during this train to unlock $discount% OFF Gift '
            'Subs!',
      'treasureOneAway' =>
        'One more level unlocks a discount for the rest of this train, keep '
            'going!',
      'treasureUnlocked' =>
        "You've unlocked $discount% OFF on 5+ Gift Subs! Don't miss out!",
      'communityReachLevel' => communityLocked(level is int ? level : 0),
      'communityUnlocked' =>
        'You unlocked ${number(amount)} '
            '${_plural(amount, 'emote', 'emotes')} for chat! Level up to give '
            'away more emotes.',
      'communityRewards' => 'Emotes for chat are on their way!',
      'mythicPool' => mythicCard(amount),
      'seeYouNextTime' => 'See you next time in Shared Hype Train!',
      _ => title,
    };
  }

  // --- Shared trains ---------------------------------------------------------

  static String sharedLevel(int level, int percent) => 'LVL $level, $percent%';
  static const sharedLevelReached = 'Shared Train level reached';
  static String continuesIn(Object? level) => 'LVL $level train continues in';
  static String otherChannelRecord(String name) =>
      "$name's new all-time Shared record!";
  static const sharedRecordReached = 'Shared Train Record Broken!';
  static const sharedNew = 'New Shared Hype Train';

  // --- Approaching -----------------------------------------------------------

  static String approachingTitle(HtVariant variant) => switch (variant) {
    HtVariant.regular => 'A Hype Train is approaching!',
    HtVariant.goldenKappa => 'Golden Kappa Train approaching!',
    HtVariant.treasure => 'A Treasure Train is close!',
    HtVariant.community => 'A Community Train is close!',
    HtVariant.mythic => 'A Mythic Train is close!',
  };

  static String approachingSubtitle(HtVariant variant) =>
      'Sub, gift, or use Bits now to start a ${trainTitle(variant)}';

  /// The viewer already took part: how many others are needed.
  static String approachingMore(int people) => people == 1
      ? '1 more person needs to sub, gift or use Bits'
      : '$people more people need to sub, gift or use Bits';

  /// The landscape pill.
  static const approachingShort = 'Approaching';

  static String approachingQuestion(HtVariant variant) =>
      variant == HtVariant.goldenKappa
      ? 'What is a Golden Kappa Train?'
      : 'What is a Hype Train?';

  static String approachingExplanationFirst(HtVariant variant) =>
      'A ${variant == HtVariant.goldenKappa ? 'Golden Kappa Train' : title} '
      'starts when multiple people subscribe, use Bits, or gift '
      'subscriptions to the community.';

  static String approachingExplanationSecond(HtVariant variant) =>
      variant == HtVariant.goldenKappa
      ? 'Once a Golden Kappa Train is underway, the community fills up the '
            'Hype Meter with more subs, gifts or Bits. Everyone who '
            'contributes enough to be eligible for rewards will receive the '
            'Golden Kappa emote for 24 hours in addition to the regular emote '
            'rewards.'
      : 'Once a Hype Train is underway, the community fills up the Hype '
            'Meter with more subs, gifts or Bits. Everyone who contributes '
            'receives one unique emote based on the highest level completed.';

  // --- End strips ------------------------------------------------------------

  static const rewards = 'Great work! Emotes are being delivered to supporters';
  static const goldenRewards =
      'Great work! Supporters can enjoy the exclusive Golden Kappa emote for '
      '24 hrs';
  static const expired = 'You missed the Train. Better luck next time!';
  static const goldenExpired =
      'The Golden Kappa Train is long gone. Better luck next time!';

  // --- Details ---------------------------------------------------------------

  static const conductorsHeader = 'HYPE CONDUCTORS';
  static const conductorsDescription = 'Current Hype Train top supporters.';
  static const rewardsHeader = 'AVAILABLE REWARDS';
  static const rewardsDescription =
      'You can earn one emote per train by subbing, gifting, or using more '
      'than 100 Bits in total during the event. Exclusive emotes are given '
      'out at the end of the Hype Train event and will stick around until '
      'the end of the current season.';
  static const goldenRewardsDescription =
      'Contribute by subbing, gifting, or using more than 100 Bits in total '
      'during the event to earn an exclusive golden Kappa emote for 24 hours '
      'in addition to the regular emote rewards.';
  static const contributionsHeader = 'CONTRIBUTIONS';
  static String levelEmotes(int level) => 'Level $level emotes';
  static const moreInfo = 'More Info';
  static const learnMore = 'learn more';
  static const unlockedSoFar = 'Unlocked so far';
  static const comingUp = 'Coming up';
  static const nothingMore = 'Nothing more to show yet';

  static String levelTarget(int level, int subs, int bits) =>
      'Completing Level $level requires combined support events totaling '
      '${number(subs)} Tier 1 ${_plural(subs, 'Sub', 'Subs')} or '
      '${bitsTotal(bits)}';

  /// After the conductor's name (drawn bold).
  static String subsConductor(int subs) =>
      'has contributed ${number(subs)} ${_plural(subs, 'Sub', 'Subs')}!';

  /// After the conductor's name (drawn bold).
  static String bitsConductor(int bits) => 'has used ${bitsTotal(bits)}';

  static const noSubsConductor = 'Sub or Gift to take over this spot!';
  static const noBitsConductor = 'Use Bits to take over this spot!';

  /// After a trophy.
  static String channelRecord(Object? percent, Object? level) =>
      'Channel all-time record! $percent% Level $level';

  static String treasureCard(
    int level,
    int discount, {
    required bool unlocked,
  }) => unlocked
      ? 'Save $discount% on 5 or more Gift Subs exclusively during this '
            'train. All Aboard!'
      : 'Unlock a limited-time $discount% OFF Gift Subs at Level $level '
            'during this train!';

  static String communityCard(
    int level,
    int emotes, {
    required bool unlocked,
  }) => unlocked
      ? 'You unlocked ${number(emotes)} ${_plural(emotes, 'emote', 'emotes')} '
            'for chat! Level up to give away more emotes.'
      : communityLocked(level);

  static String mythicCard(int pool) =>
      'Unlock 1 of $pool exclusive ${_plural(pool, 'emote', 'emotes')} for 24 '
      'hours!';

  static const goldenCard =
      "You'll have a limited time to earn an exclusive golden Kappa emote for "
      '24 hrs';

  // --- Followed streams ------------------------------------------------------

  /// The indicator on a followed stream's card.
  static String cardLevel(
    int level, {
    HtVariant variant = HtVariant.regular,
    bool ath = false,
  }) {
    if (ath) return 'All-Time High Train Level $level';
    return '${trainTitle(variant)} Level $level';
  }

  // --- Accessibility ---------------------------------------------------------

  static const collapse = 'Collapse Hype Train';
  static const expand = 'Show Hype Train';
  static const detailsHint = 'Double tap to show details';
}
