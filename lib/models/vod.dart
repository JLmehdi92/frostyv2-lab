import 'package:onset/apis/base_api_client.dart';

/// Kind of past video, as named by Twitch GQL `BroadcastType`.
enum VodType {
  archive('ARCHIVE'),
  highlight('HIGHLIGHT'),
  upload('UPLOAD');

  const VodType(this.gqlName);

  final String gqlName;

  static VodType? fromGql(Object? name) {
    for (final type in values) {
      if (type.gqlName == name) return type;
    }
    return null;
  }
}

/// A past broadcast, highlight or upload (GQL `Video`).
class Vod {
  const Vod({
    required this.id,
    required this.title,
    required this.lengthSeconds,
    required this.createdAt,
    required this.viewCount,
    required this.ownerId,
    required this.ownerLogin,
    required this.ownerDisplayName,
    this.previewThumbnailUrl,
    this.gameId,
    this.gameName,
    this.type,
    this.isRecording = false,
    this.isRestricted = false,
    this.broadcastId,
  });

  /// Parses a GQL `Video` node. Optional fields that are missing or of the
  /// wrong type fall back to defaults; a node without
  /// `id`, `lengthSeconds` or `createdAt` throws a [FormatException].
  /// [owner] is used when the node itself has no owner (channel lists).
  factory Vod.fromGql(JsonMap node, {JsonMap? owner}) {
    final id = node['id'];
    final length = node['lengthSeconds'];
    final createdAt = DateTime.tryParse('${node['createdAt']}');
    // An infinite or NaN number would throw an UnsupportedError on toInt.
    if (id is! String ||
        length is! num ||
        !length.isFinite ||
        createdAt == null) {
      throw const FormatException('Invalid video node');
    }
    final views = _as<num>(node['viewCount']);
    final ownerNode = node['owner'] is Map ? node['owner'] as Map : owner;
    final game = node['game'] is Map ? node['game'] as Map : null;
    final self = node['self'] is Map ? node['self'] as Map : null;
    final broadcast = node['broadcast'] is Map
        ? node['broadcast'] as Map
        : null;
    final broadcastId = _as<String>(broadcast?['id']);
    return Vod(
      id: id,
      title: _as<String>(node['title']) ?? '',
      lengthSeconds: length.toInt(),
      createdAt: createdAt,
      viewCount: views != null && views.isFinite ? views.toInt() : 0,
      ownerId: _as<String>(ownerNode?['id']) ?? '',
      ownerLogin: _as<String>(ownerNode?['login']) ?? '',
      ownerDisplayName: _as<String>(ownerNode?['displayName']) ?? '',
      previewThumbnailUrl: _as<String>(node['previewThumbnailURL']),
      gameId: _as<String>(game?['id']),
      gameName: _as<String>(game?['name']),
      type: VodType.fromGql(node['broadcastType']),
      isRecording: node['status'] == 'RECORDING',
      isRestricted: self?['isRestricted'] == true,
      broadcastId:
          broadcastId != null && RegExp(r'^[0-9]{1,20}$').hasMatch(broadcastId)
          ? broadcastId
          : null,
    );
  }

  final String id;
  final String title;
  final int lengthSeconds;
  final DateTime createdAt;
  final int viewCount;
  final String ownerId;
  final String ownerLogin;
  final String ownerDisplayName;
  final String? previewThumbnailUrl;
  final String? gameId;
  final String? gameName;
  final VodType? type;

  /// The broadcast is still live and this archive keeps growing.
  final bool isRecording;

  /// Subscriber-only for the current (anonymous) viewer.
  final bool isRestricted;

  /// The id of the live broadcast this video recorded (the live stream's
  /// id), null when Twitch did not say.
  final String? broadcastId;

  Duration get duration => Duration(seconds: lengthSeconds);
}

/// A channel's newest videos of one type.
///
/// Anonymous clients cannot page further (cursor paging is integrity-gated),
/// so this is a single page of up to 100 videos.
class VodPage {
  const VodPage({required this.items, required this.hasMore});

  final List<Vod> items;

  /// Twitch has older videos than the ones returned.
  final bool hasMore;
}

/// One page of video search results, and where the next one starts.
class VodSearchPage {
  const VodSearchPage({required this.items, this.cursor, this.hasMore = false});

  final List<Vod> items;

  /// Twitch's cursor for the next page (null: this was the last one).
  final String? cursor;

  final bool hasMore;
}

/// What a watch position is about, as named by Twitch GQL `VideoType`: a
/// live broadcast (named by its stream id) or a VOD.
enum WatchedVideoType {
  live('LIVE'),
  vod('VOD');

  const WatchedVideoType(this.gqlName);

  final String gqlName;
}

/// Where the viewer stopped in a video, as Twitch remembers it for their
/// account (`video.self.viewingHistory`), live sessions included.
class ViewingHistory {
  const ViewingHistory({required this.positionSec, this.updatedAt});

  final int positionSec;

  /// When it was saved (null when Twitch did not say).
  final DateTime? updatedAt;
}

/// A video the viewer started on Twitch (any device), and where they left
/// it: an entry of their "Continue watching" shelf.
class ResumeWatchingEntry {
  const ResumeWatchingEntry({required this.vod, required this.history});

  final Vod vod;
  final ViewingHistory history;
}

/// The videos asked by id, and the ids Twitch said have no video.
class VideoLookup {
  const VideoLookup({required this.videos, required this.missing});

  final List<Vod> videos;

  /// Answered with no video and no error: deleted.
  final Set<String> missing;
}

/// A copyright-muted part of a VOD, in seconds from the start.
class MutedSegment {
  const MutedSegment({required this.offset, required this.duration});

  final int offset;
  final int duration;
}

/// [value] when it is a [T], else null (GQL data is never trusted to match).
T? _as<T>(Object? value) => value is T ? value : null;
