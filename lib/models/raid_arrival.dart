import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/utils/https_url.dart';

/// The viewer followed a raid: from the channel they were watching
/// ([fromName]) to the one they arrive on ([targetName]).
@immutable
class RaidArrival {
  const RaidArrival({
    required this.fromName,
    required this.targetName,
    required this.viewers,
    required this.at,
    this.fromLogin,
    this.targetAvatarUrl,
  });

  /// Leaving [fromName]'s channel with its outgoing [raid], at [at].
  factory RaidArrival.leaving(
    OutgoingRaid raid, {
    required String fromName,
    required DateTime at,
    String? fromLogin,
  }) {
    return RaidArrival(
      fromName: fromName,
      fromLogin: fromLogin,
      targetName: raid.targetDisplayName,
      targetAvatarUrl: twitchImageOrNull(raid.targetProfileImage),
      viewers: math.max(0, raid.viewerCount),
      at: at,
    );
  }

  final String fromName;
  final String? fromLogin;
  final String targetName;

  /// The target's picture (Twitch's image host only).
  final String? targetAvatarUrl;

  /// Viewers going along.
  final int viewers;

  /// When the viewer left with it.
  final DateTime at;
}
