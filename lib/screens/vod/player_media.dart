import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_time.dart';

/// Link to [vod] at [at], as Twitch shares it.
String vodShareLink(Vod vod, Duration at) {
  final base = 'https://www.twitch.tv/videos/${vod.id}';
  return at.inSeconds <= 0 ? base : '$base?t=${formatVodTimeForShare(at)}';
}

/// What the VOD-style player overlay shows about what is playing (a VOD or
/// a clip): its title, its channel and how to share it.
class PlayerMedia {
  const PlayerMedia({
    required this.title,
    required this.ownerId,
    required this.ownerLogin,
    required this.ownerDisplayName,
    required this.shareLabel,
    required this.shareLink,
  });

  PlayerMedia.vod(Vod vod)
    : this(
        title: vod.title,
        ownerId: vod.ownerId,
        ownerLogin: vod.ownerLogin,
        ownerDisplayName: vod.ownerDisplayName,
        shareLabel: 'Copy link at current time',
        shareLink: (at) => vodShareLink(vod, at),
      );

  final String title;
  final String ownerId;
  final String ownerLogin;
  final String ownerDisplayName;

  /// The settings sheet's copy-link tile.
  final String shareLabel;

  /// The link copied for the current playback position.
  final String Function(Duration position) shareLink;
}
