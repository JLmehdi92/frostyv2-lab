import 'package:flutter/material.dart';

/// The kinds of `USERNOTICE` Twitch sends over IRC.
///
/// Deliberately typed rather than matched by substring: the previous rendering
/// asked whether the `msg-id` *contained* "sub", which makes `submysterygift`,
/// `subgift`, `resub` and `giftsubbasematch` indistinguishable and picks the
/// same icon for all four.
///
/// The list was built from a live capture of `irc.chat.twitch.tv` rather than
/// from the decompiled Android app: that app never reads these tags, because it
/// receives subscription events over PubSub instead of IRC.
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
  /// `msg-param-community-gift-id`. The official clients show this header only.
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

/// The colour a moderator picked for an announcement.
enum AnnouncementColor { primary, blue, green, orange, purple }

/// A parsed `USERNOTICE`.
///
/// [systemMessage] is Twitch's own wording, generated server-side and already
/// localised for the channel — it is never rebuilt here. The typed fields exist
/// to drive the *presentation* (icon, tier badge, colour, grouping), not to
/// re-word what Twitch already said.
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

  /// How many subs a mass gift covers.
  final int? massGiftCount;

  /// How many subs this gifter has given in the channel, all-time.
  final int? senderCount;

  /// Ties a mass gift header to its individual gifts.
  final String? communityGiftId;

  /// Viewers brought over by a raid.
  final int? raidViewerCount;

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
    this.massGiftCount,
    this.senderCount,
    this.communityGiftId,
    this.raidViewerCount,
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

  /// Builds a notice from raw IRC tags. Never throws: a malformed or unknown
  /// notice still renders through [systemMessage].
  factory UserNotice.fromTags(Map<String, String> tags) {
    final subPlan = tags['msg-param-sub-plan'];

    return UserNotice(
      kind: _kindFrom(tags['msg-id']),
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
      massGiftCount: int.tryParse(tags['msg-param-mass-gift-count'] ?? ''),
      senderCount: int.tryParse(tags['msg-param-sender-count'] ?? ''),
      communityGiftId: tags['msg-param-community-gift-id']?.nullIfEmpty,
      raidViewerCount: int.tryParse(tags['msg-param-viewerCount'] ?? ''),
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
