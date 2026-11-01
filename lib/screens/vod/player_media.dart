import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/vod/vod_time.dart';

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
    this.kindLabel,
  });

  /// [vod]'s, its labels in [l]'s language.
  PlayerMedia.vod(Vod vod, AppLocalizations l)
    : this(
        title: vod.title,
        ownerId: vod.ownerId,
        ownerLogin: vod.ownerLogin,
        ownerDisplayName: vod.ownerDisplayName,
        shareLabel: l.vodCopyLinkAtTime,
        shareLink: (at) => vodShareLink(vod, at),
        kindLabel: vodKindLabel(vod.type, l),
      );

  final String title;
  final String ownerId;
  final String ownerLogin;
  final String ownerDisplayName;

  /// The settings sheet's copy-link tile.
  final String shareLabel;

  /// The link copied for the current playback position.
  final String Function(Duration position) shareLink;

  /// What kind of video it is ("Past broadcast"), in the tablet's top row;
  /// null when unknown.
  final String? kindLabel;
}

/// "Past broadcast", "Highlight" or "Upload" in [l]'s language (null when
/// unknown).
String? vodKindLabel(VodType? type, AppLocalizations l) => switch (type) {
  VodType.archive => l.vodKindArchive,
  VodType.highlight => l.vodKindHighlight,
  VodType.upload => l.vodKindUpload,
  null => null,
};
