import 'package:frosty/models/hype_train.dart';
import 'package:intl/intl.dart';

/// Our own English copy for the hype train (not Twitch's strings).
abstract final class HtCopy {
  static final _number = NumberFormat.decimalPattern();

  static String number(int value) => _number.format(value);

  static const title = 'Hype Train';
  static const approaching = 'Hype Train approaching';
  static const collapse = 'Collapse Hype Train';
  static const expand = 'Show Hype Train';
  static const detailsHint = 'Double tap to show details';
  static const rewardsOnTheWay = 'Rewards are on their way';
  static const goldenRewards = 'Golden Kappa unlocked for 24 hours';
  static const ended = 'This Hype Train has ended';
  static const finalLevel = 'Final level!';

  static String levelTarget(int subs, int bits) =>
      'About ${number(subs)} ${subs == 1 ? 'sub' : 'subs'} or '
      '${number(bits)} Bits completes this level';

  static String approachingSubtitle(int remaining, {required bool nMore}) =>
      nMore
      ? 'Just $remaining more to start the train!'
      : '$remaining ${remaining == 1 ? 'event' : 'events'} '
            'start a Hype Train';

  static String levelComplete(int level) => 'Level $level complete!';

  static String levelRewards(int level) => 'Level $level rewards unlocked';

  static String instruction(String key, Map<String, Object?> data) {
    final level = data['level'];
    return switch (key) {
      'start' => 'A Hype Train has started! Cheer or subscribe to fuel it.',
      'treasureReachLevel' => 'Reach level $level to unlock the treasure',
      'treasureOneAway' => 'One more level to unlock the treasure!',
      'treasureUnlocked' => 'Treasure unlocked: gift subs are discounted',
      'communityReachLevel' => 'Reach level $level for community emotes',
      'communityUnlocked' => 'Community emotes unlocked!',
      'communityRewards' => 'Community emotes go to the chat',
      'mythicPool' => 'One of these emotes will be the Mythic reward',
      'seeYouNextTime' => 'See you on the next Hype Train!',
      _ => title,
    };
  }

  static String contribution(String? name, HtAction action, int quantity) {
    final who = name ?? 'Someone';
    if (action.isCheer) return '$who cheered ${number(quantity)} Bits!';
    if (action.isGift) {
      return '$who gifted ${number(quantity)} '
          '${quantity == 1 ? 'sub' : 'subs'}!';
    }
    if (action.subTier != null) return '$who subscribed!';
    return '$who boosted the train!';
  }

  static String totals(int bits, int subs) =>
      '${number(bits)} Bits and ${number(subs)} '
      '${subs == 1 ? 'sub' : 'subs'} in total';

  static String summary(int level, {required bool ath}) => ath
      ? 'New record: level $level!'
      : 'Hype Train completed at level $level';

  static String merged(Object? from, Object? to) =>
      'Trains merged: level $from → $to';

  static String treasureDiscount(Object? percent) =>
      '$percent% off gift subs unlocked!';

  static String communityAmount(Object? amount) =>
      '$amount viewers get a community emote!';
}
