import 'package:flutter/foundation.dart';
import 'package:frosty/models/user_notice.dart';
import 'package:frosty/utils/https_url.dart';

/// A channel raiding the one being watched, as its chat announced it (or
/// as the viewer brought it along, following the raid from that channel).
@immutable
class IncomingRaid {
  const IncomingRaid({
    required this.raiderName,
    required this.viewers,
    this.raiderLogin,
    this.avatarUrl,
  });

  /// From a live raid notice of [channelId]'s chat, or null: not a raid,
  /// replayed history, another channel of a shared chat, or no name.
  static IncomingRaid? fromNotice(
    UserNotice notice, {
    required String channelId,
  }) {
    if (notice.kind != UserNoticeKind.raid || notice.isHistorical) {
      return null;
    }
    final source = notice.sourceRoomId;
    if (source != null && source != channelId) return null;
    final name = notice.raiderDisplayName ?? notice.displayName ?? notice.login;
    if (name == null || name.trim().isEmpty) return null;
    return IncomingRaid(
      raiderName: name.trim(),
      raiderLogin: notice.login?.toLowerCase(),
      viewers: notice.raidViewerCount ?? 0,
      avatarUrl: httpsOrNull(notice.raiderAvatarUrl),
    );
  }

  final String raiderName;
  final String? raiderLogin;
  final int viewers;

  /// The raiding channel's picture (https only).
  final String? avatarUrl;

  /// Who raided, to tell one raid heard twice apart from another.
  String get raiderKey => (raiderLogin ?? raiderName).toLowerCase();
}

/// An incoming raid pinned above chat for a few seconds.
@immutable
class IncomingRaidBanner {
  const IncomingRaidBanner({
    required this.raid,
    required this.id,
    required this.endsAt,
  });

  final IncomingRaid raid;

  /// Its id in the highlight stack.
  final String id;
  final DateTime endsAt;
}
