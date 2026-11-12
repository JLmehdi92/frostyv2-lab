import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/vod/vod_time.dart';

/// The hype train's words, in [l]'s language (the ARB files' `ht…`
/// messages): what turns its variants, levels and steps into text.
@immutable
final class HtCopy {
  const HtCopy(this.l);

  /// The words of the language [context] shows.
  factory HtCopy.of(BuildContext context) => HtCopy(context.l10n);

  final AppLocalizations l;

  /// [value] with the grouping of [l]'s language (« 1 200 »).
  String number(int value) =>
      NumberFormat.decimalPattern(l.localeName).format(value);

  // --- Names -----------------------------------------------------------------

  String get title => l.htTitle;

  /// The train's name: its variant, "Shared" when several channels run it.
  String trainTitle(HtVariant variant, {bool shared = false}) => shared
      ? l.htSharedTrainTitle(variant: variant.name)
      : l.htTrainTitle(variant: variant.name);

  // --- Banner ----------------------------------------------------------------

  String level(int level) => l.htLevelShort(level: level);

  String percent(int value) => l.commonPercent(value: value);

  /// `m:ss`, or `h:mm:ss` from an hour (figures only, in every language).
  static String countdown(Duration remaining) => formatVodTime(remaining);

  String get subtitle => l.htSubtitle;
  String get finalLevel => l.htFinalLevel;
  String get athApproaching => l.htAthApproaching;
  String get athApproachingCompact => l.htAthApproachingCompact;

  String athReached({bool shared = false}) =>
      shared ? l.htAthReachedShared : l.htAthReached;

  String treasureLocked(int level, int discount) =>
      l.htTreasureLocked(level: level, discount: discount);

  String treasureUnlockedSubtitle(int discount) =>
      l.htTreasureUnlockedSubtitle(discount: discount);

  String communityLocked(int level) => l.htCommunityLocked(level: level);

  String communityUnlockedSubtitle(int emotes) =>
      l.htCommunityUnlockedSubtitle(count: emotes);

  // --- Announcements ---------------------------------------------------------

  String levelComplete(int level) => l.htLevelComplete(level: level);

  /// The start marquee (three callout emotes follow it).
  String started(HtVariant variant, {bool shared = false}) => shared
      ? l.htSharedStarted(variant: variant.name)
      : l.htStarted(variant: variant.name);

  /// The level-up marquee.
  String get levelUp => l.htLevelUp;

  /// The completed marquee.
  String completed(HtVariant variant, {bool shared = false}) => shared
      ? l.htSharedCompleted(variant: variant.name)
      : l.htCompleted(variant: variant.name);

  String get treasureUnlockedMarquee => l.htTreasureUnlockedMarquee;
  String get communityUnlockedMarquee => l.htCommunityUnlockedMarquee;
  String get merging => l.htMerging;

  /// Two lines: a cheer, then the level completed (or the record).
  String summary(
    int level, {
    bool ath = false,
    HtVariant variant = HtVariant.regular,
  }) => ath
      ? l.htSummaryRecord
      : l.htSummary(variant: variant.name, level: level);

  String get athReachedTitle => l.htAthReachedTitle;

  String contribution(String? name, HtAction action, int quantity) {
    final who = name ?? l.htSomeone;
    if (action.isCheer) {
      return l.htContributionBits(name: who, count: quantity);
    }
    if (action.subTier case final tier?) {
      if (action.isGift) {
        return l.htContributionGift(name: who, count: quantity, tier: tier);
      }
      return l.htContributionSub(name: who, tier: tier);
    }
    return l.htContributionOther(name: who);
  }

  String subsTotal(int subs) => l.htSubs(count: subs);

  String bitsTotal(int bits) => l.htBits(count: bits);

  /// An instruction step's text; [discount] for treasure trains, [amount]
  /// for community emotes or the mythic pool.
  String instruction(
    String key,
    Map<String, Object?> data, {
    HtVariant variant = HtVariant.regular,
    int discount = 35,
    int amount = 0,
  }) {
    final level = data['level'];
    return switch (key) {
      'start' => l.htInstructionStart(variant: variant.name),
      'treasureReachLevel' => l.htInstructionTreasureReachLevel(
        level: level is int ? level : 0,
        discount: discount,
      ),
      'treasureOneAway' => l.htInstructionTreasureOneAway,
      'treasureUnlocked' => l.htInstructionTreasureUnlocked(discount: discount),
      'communityReachLevel' => communityLocked(level is int ? level : 0),
      'communityUnlocked' => l.htCommunityUnlocked(count: amount),
      'communityRewards' => l.htInstructionCommunityRewards,
      'mythicPool' => mythicCard(amount),
      'seeYouNextTime' => l.htInstructionSeeYouNextTime,
      _ => title,
    };
  }

  // --- Shared trains ---------------------------------------------------------

  String sharedLevel(int level, int percent) =>
      l.htSharedLevel(level: level, percent: percent);
  String get sharedLevelReached => l.htSharedLevelReached;
  String continuesIn(int level) => l.htContinuesIn(level: level);
  String otherChannelRecord(String name) => l.htOtherChannelRecord(name: name);
  String get sharedRecordReached => l.htSharedRecordReached;
  String get sharedNew => l.htSharedNew;

  // --- Approaching -----------------------------------------------------------

  String approachingTitle(HtVariant variant) =>
      l.htApproachingTitle(variant: variant.name);

  String approachingSubtitle(HtVariant variant) =>
      l.htApproachingSubtitle(train: trainTitle(variant));

  /// The viewer already took part: how many others are needed.
  String approachingMore(int people) => l.htApproachingMore(count: people);

  /// The landscape pill.
  String get approachingShort => l.htApproachingShort;

  String approachingQuestion(HtVariant variant) =>
      l.htApproachingQuestion(variant: variant.name);

  String approachingExplanationFirst(HtVariant variant) =>
      l.htApproachingExplanationFirst(variant: variant.name);

  String approachingExplanationSecond(HtVariant variant) =>
      l.htApproachingExplanationSecond(variant: variant.name);

  // --- End strips ------------------------------------------------------------

  String get rewards => l.htRewards;
  String get goldenRewards => l.htGoldenRewards;
  String get expired => l.htExpired;
  String get goldenExpired => l.htGoldenExpired;

  // --- Details ---------------------------------------------------------------

  String get conductorsHeader => l.htConductorsHeader;
  String get conductorsDescription => l.htConductorsDescription;
  String get rewardsHeader => l.htRewardsHeader;
  String get rewardsDescription => l.htRewardsDescription;
  String get goldenRewardsDescription => l.htGoldenRewardsDescription;
  String get contributionsHeader => l.htContributionsHeader;
  String levelEmotes(int level) => l.htLevelEmotes(level: level);
  String get moreInfo => l.htMoreInfo;
  String get learnMore => l.htLearnMore;
  String get unlockedSoFar => l.htUnlockedSoFar;
  String get comingUp => l.htComingUp;
  String get nothingMore => l.htNothingMore;

  String levelTarget(int level, int subs, int bits) =>
      l.htLevelTarget(level: level, subs: subs, bits: bits);

  /// The conductor's line: [name] (drawn bold by the caller, who passes a
  /// mark of [l10nSpans]) and their subs.
  String subsConductor(String name, int subs) =>
      l.htSubsConductor(name: name, count: subs);

  /// The conductor's line: [name] (see [subsConductor]) and their Bits.
  String bitsConductor(String name, int bits) =>
      l.htBitsConductor(name: name, count: bits);

  String get noSubsConductor => l.htNoSubsConductor;
  String get noBitsConductor => l.htNoBitsConductor;

  /// After a trophy.
  String channelRecord(int percent, int level) =>
      l.htChannelRecord(percent: percent, level: level);

  String treasureCard(int level, int discount, {required bool unlocked}) =>
      unlocked
      ? l.htTreasureCardUnlocked(discount: discount)
      : l.htTreasureCardLocked(level: level, discount: discount);

  String communityCard(int level, int emotes, {required bool unlocked}) =>
      unlocked ? l.htCommunityUnlocked(count: emotes) : communityLocked(level);

  String mythicCard(int pool) => l.htMythicCard(count: pool);

  String get goldenCard =>
      l.htInstructionStart(variant: HtVariant.goldenKappa.name);

  // --- Followed streams ------------------------------------------------------

  /// The indicator on a followed stream's card.
  String cardLevel(
    int level, {
    HtVariant variant = HtVariant.regular,
    bool ath = false,
  }) => ath
      ? l.htCardLevelRecord(level: level)
      : l.htCardLevel(train: trainTitle(variant), level: level);

  // --- Accessibility ---------------------------------------------------------

  String get collapse => l.htCollapse;
  String get expand => l.htExpand;
  String get detailsHint => l.htDetailsHint;

  /// What a screen reader says for [store]'s train, in one line. Minutes
  /// until the last one: a label that changes every second would keep
  /// screen readers busy.
  String summaryLabel(HypeTrainStore store) {
    switch (store.phase) {
      case HtPhase.hidden:
        return '';
      case HtPhase.approaching:
        return l.htSemanticsApproaching;
      case HtPhase.ongoing:
        // Minutes until the last one: a label that changes every second
        // would keep screen readers busy (and rebuild its readers).
        final time = switch (store.summaryTime) {
          (minutes: final minutes, seconds: _) when minutes > 0 =>
            l.htSemanticsMinutes(minutes: minutes),
          (minutes: _, :final seconds) => l.htSemanticsSeconds(count: seconds),
        };
        return l.htSemanticsOngoing(
          level: store.level,
          percent: store.percent,
          time: time,
        );
      case HtPhase.ending || HtPhase.rewards:
        return l.htSemanticsEnded(
          level: store.endSummary?.level ?? store.level,
        );
      case HtPhase.expired:
        return l.htSemanticsExpired;
    }
  }
}
