import 'package:flutter/material.dart';

/// The kinds of `USERNOTICE` Twitch sends over IRC.
///
/// Deliberately typed rather than matched by substring: the previous rendering
/// asked whether the `msg-id` *contained* "sub", which makes `submysterygift`,
/// `subgift`, `resub` and `giftsubbasematch` indistinguishable and picks the
/// same icon for all four.
///
/// Twitch's Android app reads the same tags: it parses `msg-id`, the
/// `msg-param-*` values and `system-msg` of every `USERNOTICE` it receives, and
/// words and lays out each kind from them.
enum UserNoticeKind {
  /// A brand-new subscription.
  sub,

  /// A renewed subscription. Carries the streak and cumulative totals.
  resub,

  /// One gifted subscription aimed at a named recipient.
  subGift,

  /// The header of a mass gift: "X is gifting N Tier 1 Subs to …".
  ///
  /// Twitch follows it with one [subGift] per recipient, all sharing the same
  /// `msg-param-community-gift-id`. Twitch's Android app shows the header and
  /// then every one of those gifts on its own line.
  communityGift,

  /// An anonymous gift.
  anonSubGift,

  /// An anonymous mass gift.
  anonCommunityGift,

  /// A gifted sub being continued by its recipient.
  giftPaidUpgrade,

  /// Same, where the original gifter was anonymous.
  anonGiftPaidUpgrade,

  /// A Prime sub converted to a paid tier.
  primePaidUpgrade,

  /// A subscription extended in advance, through a given month.
  extendSub,

  /// A reward gifted to chat on someone's behalf.
  rewardGift,

  /// A bonus sub paid for by a sponsor. Carries the advertiser's own name and
  /// brand colour, so it cannot be rendered like an ordinary gift.
  giftSubBaseMatch,

  /// Another channel sending its viewers over.
  raid,

  /// A raid that was called off.
  unraid,

  /// A moderator or broadcaster announcement, with its own colour.
  announcement,

  /// A viewer crossing a bits badge threshold.
  bitsBadgeTier,

  /// Passing a gifted sub forward.
  payItForward,

  /// A watch-streak or similar milestone.
  viewerMilestone,

  /// A charity donation notice.
  charityDonation,

  /// Anything Twitch adds later. Still renders, using its `system-msg`.
  unknown,
}

/// The user id of Twitch's anonymous gifter account (`ananonymousgifter`).
///
/// Modern IRC sends an anonymous gift as an ordinary `subgift` or
/// `submysterygift` from this account rather than with an `anon*` msg-id.
const anonymousGifterUserId = '274598607';

/// The login of Twitch's anonymous gifter account.
const anonymousGifterLogin = 'ananonymousgifter';

/// The colour a moderator picked for an announcement.
enum AnnouncementColor { primary, blue, green, orange, purple }

/// A parsed `USERNOTICE`.
///
/// [systemMessage] is Twitch's own wording, generated server-side. Like
/// Twitch's Android app, the chat words subs and gifts from the typed fields
/// instead (see `userNoticeText`), and keeps [systemMessage] for the kinds it
/// has no sentence of its own for. The typed fields also drive the
/// presentation: layout, icon, colour and gift bomb grouping.
@immutable
class UserNotice {
  final UserNoticeKind kind;

  /// Twitch's own sentence, unescaped. Empty for announcements, which put
  /// their text in the IRC message body instead.
  final String systemMessage;

  /// `Prime`, `Tier 1`, `Tier 2`, `Tier 3`, or null when not a subscription.
  final String? tier;

  /// True when the subscription was paid with Prime.
  final bool isPrime;

  /// Total months subscribed, all-time.
  final int? cumulativeMonths;

  /// Consecutive months. Only meaningful when [shouldShareStreak] is true —
  /// Twitch sends a streak value even for viewers who chose to hide it.
  final int? streakMonths;
  final bool shouldShareStreak;

  /// Who received a gift.
  final String? recipientDisplayName;

  /// The recipient's login, used to spell out a display name that is not
  /// written in Latin letters.
  final String? recipientLogin;

  /// How many months a single gift covers. Greater than 1 for a multi-month
  /// gift.
  final int? giftMonths;

  /// The month (1 to 12) an [UserNoticeKind.extendSub] runs through.
  final int? benefitEndMonth;

  /// How many subs a mass gift covers.
  final int? massGiftCount;

  /// How many subs this gifter has given in the channel, all-time.
  final int? senderCount;

  /// Ties a mass gift header to its individual gifts.
  final String? communityGiftId;

  /// Twitch's id for the purchase behind a gift. Shared by a mass gift header
  /// and its gifts, so it stands in for [communityGiftId] when that is absent.
  final String? originId;

  /// The sender's display name, login and user id, as sent in the tags.
  final String? displayName;
  final String? login;
  final String? userId;

  /// Whether the notice was replayed from the recent-messages history rather
  /// than received live.
  final bool isHistorical;

  /// The channel the chat belongs to, and, in a shared chat, the channel the
  /// notice actually happened in.
  final String? roomId;
  final String? sourceRoomId;

  /// The sub goal a subscription counts towards, when it counts towards one.
  final int? goalCurrentContributions;
  final int? goalTargetContributions;
  final String? goalContributionType;
  final String? goalDescription;

  /// Who gave the gift that a [UserNoticeKind.giftPaidUpgrade] continues.
  final String? senderLogin;
  final String? senderName;

  /// Viewers brought over by a raid.
  final int? raidViewerCount;

  /// The raiding channel's avatar, at 70 by 70 pixels.
  final String? raiderAvatarUrl;

  /// The raiding channel's display name.
  final String? raiderDisplayName;

  /// The announcement's colour.
  final AnnouncementColor? announcementColor;

  /// The sponsor behind a [UserNoticeKind.giftSubBaseMatch], and its brand
  /// colour, both supplied by Twitch.
  final String? sponsorName;
  final Color? sponsorColor;

  const UserNotice({
    required this.kind,
    required this.systemMessage,
    this.tier,
    this.isPrime = false,
    this.cumulativeMonths,
    this.streakMonths,
    this.shouldShareStreak = false,
    this.recipientDisplayName,
    this.recipientLogin,
    this.giftMonths,
    this.benefitEndMonth,
    this.massGiftCount,
    this.senderCount,
    this.communityGiftId,
    this.originId,
    this.displayName,
    this.login,
    this.userId,
    this.isHistorical = false,
    this.roomId,
    this.sourceRoomId,
    this.goalCurrentContributions,
    this.goalTargetContributions,
    this.goalContributionType,
    this.goalDescription,
    this.senderLogin,
    this.senderName,
    this.raidViewerCount,
    this.raiderAvatarUrl,
    this.raiderDisplayName,
    this.announcementColor,
    this.sponsorName,
    this.sponsorColor,
  });

  /// Whether this notice is one of the individual gifts belonging to the mass
  /// gift identified by [communityGiftId].
  bool get isPartOfMassGift =>
      (kind == UserNoticeKind.subGift || kind == UserNoticeKind.anonSubGift) &&
      communityGiftId != null;

  /// Whether this notice announces a mass gift.
  bool get isMassGiftHeader =>
      kind == UserNoticeKind.communityGift ||
      kind == UserNoticeKind.anonCommunityGift;

  /// Whether the gifter chose to stay anonymous: a legacy `anon*` msg-id, or
  /// an ordinary one sent from Twitch's anonymous gifter account.
  bool get isAnonymous =>
      kind == UserNoticeKind.anonSubGift ||
      kind == UserNoticeKind.anonCommunityGift ||
      kind == UserNoticeKind.anonGiftPaidUpgrade ||
      userId == anonymousGifterUserId ||
      login == anonymousGifterLogin;

  /// The id that ties a mass gift header to its gifts:
  /// [communityGiftId], or [originId] when Twitch left the former out.
  String? get giftBombKey => communityGiftId ?? originId;

  /// Whether the subscription counts towards a sub goal.
  bool get hasGoal =>
      goalCurrentContributions != null && goalTargetContributions != null;

  static UserNoticeKind _kindFrom(String? msgId) => switch (msgId) {
    'sub' => UserNoticeKind.sub,
    'resub' => UserNoticeKind.resub,
    'subgift' => UserNoticeKind.subGift,
    'submysterygift' => UserNoticeKind.communityGift,
    'anonsubgift' => UserNoticeKind.anonSubGift,
    'anonsubmysterygift' => UserNoticeKind.anonCommunityGift,
    'giftpaidupgrade' => UserNoticeKind.giftPaidUpgrade,
    'anongiftpaidupgrade' => UserNoticeKind.anonGiftPaidUpgrade,
    'primepaidupgrade' => UserNoticeKind.primePaidUpgrade,
    'extendsub' => UserNoticeKind.extendSub,
    'rewardgift' => UserNoticeKind.rewardGift,
    'giftsubbasematch' => UserNoticeKind.giftSubBaseMatch,
    'raid' => UserNoticeKind.raid,
    'unraid' => UserNoticeKind.unraid,
    'announcement' => UserNoticeKind.announcement,
    'bitsbadgetier' => UserNoticeKind.bitsBadgeTier,
    'standardpayforward' || 'communitypayforward' => UserNoticeKind.payItForward,
    'viewermilestone' => UserNoticeKind.viewerMilestone,
    'charitydonation' => UserNoticeKind.charityDonation,
    _ => UserNoticeKind.unknown,
  };

  /// Maps Twitch's `msg-param-sub-plan` to the wording Twitch itself uses.
  ///
  /// The wire values are `Prime`, `1000`, `2000` and `3000`; anything else is
  /// passed through untouched so a new tier still shows something truthful
  /// rather than nothing.
  static String? _tierFrom(String? subPlan) => switch (subPlan) {
    null => null,
    'Prime' => 'Prime',
    '1000' => 'Tier 1',
    '2000' => 'Tier 2',
    '3000' => 'Tier 3',
    final other => other,
  };

  static AnnouncementColor? _announcementColorFrom(String? color) =>
      switch (color?.toUpperCase()) {
        'PRIMARY' => AnnouncementColor.primary,
        'BLUE' => AnnouncementColor.blue,
        'GREEN' => AnnouncementColor.green,
        'ORANGE' => AnnouncementColor.orange,
        'PURPLE' => AnnouncementColor.purple,
        _ => null,
      };

  /// Parses `#RRGGBB` as sent in `msg-param-advertiser-hex-color`.
  static Color? _hexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// IRC escapes tag values: spaces become `\s`, and `\`, `;`, `\r`, `\n` get
  /// their own sequences. Without this the system message reads
  /// "user\ssubscribed\swith\sPrime.".
  static String unescapeTag(String? value) {
    if (value == null || value.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (value[i] != r'\' || i + 1 >= value.length) {
        buffer.write(value[i]);
        continue;
      }

      i++;
      buffer.write(switch (value[i]) {
        's' => ' ',
        'n' => '\n',
        'r' => '\r',
        ':' => ';',
        r'\' => r'\',
        final other => other,
      });
    }
    return buffer.toString();
  }

  /// The notice's real `msg-id`. In a shared chat, a notice from a partner
  /// channel arrives as `sharedchatnotice`, with its own kind in
  /// `source-msg-id`.
  static String? msgIdOf(Map<String, String> tags) {
    final msgId = tags['msg-id'];
    return msgId == 'sharedchatnotice' ? tags['source-msg-id'] : msgId;
  }

  /// Builds a notice from raw IRC tags. Never throws: a malformed or unknown
  /// notice still renders through [systemMessage].
  factory UserNotice.fromTags(Map<String, String> tags) {
    final subPlan = tags['msg-param-sub-plan'];

    return UserNotice(
      kind: _kindFrom(msgIdOf(tags)),
      systemMessage: unescapeTag(tags['system-msg']),
      tier: _tierFrom(subPlan),
      isPrime: subPlan == 'Prime',
      cumulativeMonths: int.tryParse(
        tags['msg-param-cumulative-months'] ?? '',
      ),
      streakMonths: int.tryParse(tags['msg-param-streak-months'] ?? ''),
      shouldShareStreak: tags['msg-param-should-share-streak'] == '1',
      recipientDisplayName: unescapeTag(
        tags['msg-param-recipient-display-name'],
      ).nullIfEmpty,
      recipientLogin: tags['msg-param-recipient-user-name']?.nullIfEmpty,
      giftMonths: int.tryParse(tags['msg-param-gift-months'] ?? ''),
      benefitEndMonth: int.tryParse(
        tags['msg-param-sub-benefit-end-month'] ?? '',
      ),
      // Never negative: a malformed count reads as none (no collapse, no
      // banner) rather than "-5 recipients".
      massGiftCount: switch (int.tryParse(
        tags['msg-param-mass-gift-count'] ?? '',
      )) {
        final count? when count < 0 => 0,
        final count => count,
      },
      senderCount: int.tryParse(tags['msg-param-sender-count'] ?? ''),
      communityGiftId: tags['msg-param-community-gift-id']?.nullIfEmpty,
      originId: unescapeTag(tags['msg-param-origin-id']).nullIfEmpty,
      displayName: unescapeTag(tags['display-name']).nullIfEmpty,
      login: tags['login']?.nullIfEmpty,
      userId: tags['user-id']?.nullIfEmpty,
      isHistorical: tags['historical'] == '1',
      roomId: tags['room-id']?.nullIfEmpty,
      sourceRoomId: tags['source-room-id']?.nullIfEmpty,
      goalCurrentContributions: int.tryParse(
        tags['msg-param-goal-current-contributions'] ?? '',
      ),
      goalTargetContributions: int.tryParse(
        tags['msg-param-goal-target-contributions'] ?? '',
      ),
      goalContributionType:
          tags['msg-param-goal-contribution-type']?.nullIfEmpty,
      goalDescription: unescapeTag(
        tags['msg-param-goal-description'],
      ).nullIfEmpty,
      senderLogin: tags['msg-param-sender-login']?.nullIfEmpty,
      senderName: unescapeTag(tags['msg-param-sender-name']).nullIfEmpty,
      raidViewerCount: int.tryParse(tags['msg-param-viewerCount'] ?? ''),
      // Twitch leaves a `%s` where the size goes.
      raiderAvatarUrl: tags['msg-param-profileImageURL']?.nullIfEmpty
          ?.replaceAll('%s', '70x70'),
      raiderDisplayName: unescapeTag(
        tags['msg-param-displayName'],
      ).nullIfEmpty,
      announcementColor: _announcementColorFrom(tags['msg-param-color']),
      sponsorName: unescapeTag(
        tags['msg-param-advertiser-name'],
      ).nullIfEmpty,
      sponsorColor: _hexColor(tags['msg-param-advertiser-hex-color']),
    );
  }
}

extension on String? {
  /// Treats an empty tag as absent. Twitch sends `key=` rather than omitting
  /// the key, so `''` and "not sent" mean the same thing.
  String? get nullIfEmpty => (this == null || this!.isEmpty) ? null : this;
}
