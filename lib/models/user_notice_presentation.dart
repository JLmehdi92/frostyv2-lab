import 'package:flutter/foundation.dart';
import 'package:onset/models/user_notice.dart';

/// The row a notice is drawn in.
enum NoticeLayout {
  /// Subs, gifts and most paid events: a tinted row with an accent bar.
  special,

  /// Announcements and milestones: no tint, the accent in the text colour.
  generic,

  /// A sub that counts towards a sub goal: the special row plus the goal's
  /// progress.
  subGoal,

  /// A raid, led by the raiding channel's avatar.
  raid,
}

/// The icon at the start of a notice row. Most subs and gifts have none.
enum NoticeGlyph {
  /// A gift from Twitch's anonymous gifter.
  anonymousGift,

  /// A sub in another channel of a shared chat: that channel's avatar with a
  /// star.
  sharedChat,

  /// An announcement.
  megaphone,

  /// The raiding channel's avatar.
  raider,

  /// A charity donation.
  charity,

  /// A sponsored or reward gift.
  gift,

  /// A viewer milestone.
  milestone,
}

/// How a notice is drawn: its row, its icon, and where the icon sits.
@immutable
class NoticePresentation {
  final NoticeLayout layout;
  final NoticeGlyph? icon;

  /// Where the icon sits between the top (0) and the bottom (1) of the row.
  /// Twitch centres the anonymous gift icon and sets every other icon a little
  /// above the middle.
  final double iconBias;

  const NoticePresentation(
    this.layout, {
    this.icon,
    this.iconBias = defaultIconBias,
  });

  static const defaultIconBias = 0.3;
  static const centredIconBias = 0.5;

  @override
  bool operator ==(Object other) =>
      other is NoticePresentation &&
      other.layout == layout &&
      other.icon == icon &&
      other.iconBias == iconBias;

  @override
  int get hashCode => Object.hash(layout, icon, iconBias);

  @override
  String toString() => 'NoticePresentation($layout, $icon, $iconBias)';
}

/// Picks a notice's row and icon.
///
/// A named sub or gift has no icon: the green accent bar alone marks it.
/// Rarer kinds are kept, in the special row without an icon.
NoticePresentation noticePresentation(UserNotice notice) {
  switch (notice.kind) {
    case UserNoticeKind.announcement:
      return const NoticePresentation(
        NoticeLayout.generic,
        icon: NoticeGlyph.megaphone,
      );
    case UserNoticeKind.raid:
      return const NoticePresentation(
        NoticeLayout.raid,
        icon: NoticeGlyph.raider,
      );
    case UserNoticeKind.unraid:
      return const NoticePresentation(NoticeLayout.generic);
    case UserNoticeKind.viewerMilestone:
      return const NoticePresentation(
        NoticeLayout.generic,
        icon: NoticeGlyph.milestone,
      );
    case UserNoticeKind.charityDonation:
      return const NoticePresentation(
        NoticeLayout.special,
        icon: NoticeGlyph.charity,
      );
    case UserNoticeKind.giftSubBaseMatch || UserNoticeKind.rewardGift:
      return const NoticePresentation(
        NoticeLayout.special,
        icon: NoticeGlyph.gift,
      );
    case UserNoticeKind.subGift ||
        UserNoticeKind.communityGift ||
        UserNoticeKind.anonSubGift ||
        UserNoticeKind.anonCommunityGift:
      if (notice.hasGoal) return const NoticePresentation(NoticeLayout.subGoal);
      if (notice.isAnonymous) {
        return const NoticePresentation(
          NoticeLayout.special,
          icon: NoticeGlyph.anonymousGift,
          iconBias: NoticePresentation.centredIconBias,
        );
      }
      return const NoticePresentation(NoticeLayout.special);
    case UserNoticeKind.sub || UserNoticeKind.resub:
      if (notice.hasGoal) return const NoticePresentation(NoticeLayout.subGoal);
      final source = notice.sourceRoomId;
      if (source != null && source != notice.roomId) {
        return const NoticePresentation(
          NoticeLayout.special,
          icon: NoticeGlyph.sharedChat,
        );
      }
      return const NoticePresentation(NoticeLayout.special);
    case UserNoticeKind.extendSub ||
        UserNoticeKind.giftPaidUpgrade ||
        UserNoticeKind.anonGiftPaidUpgrade ||
        UserNoticeKind.primePaidUpgrade ||
        UserNoticeKind.bitsBadgeTier ||
        UserNoticeKind.payItForward ||
        UserNoticeKind.unknown:
      return const NoticePresentation(NoticeLayout.special);
  }
}
