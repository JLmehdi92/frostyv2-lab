import 'package:frosty/apis/base_api_client.dart';

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
  });

  /// Parses a GQL `Video` node. Optional fields that are missing or of the
  /// wrong type fall back to defaults; a node without
  /// `id`, `lengthSeconds` or `createdAt` throws a [FormatException].
  /// [owner] is used when the node itself has no owner (channel lists).
  factory Vod.fromGql(JsonMap node, {JsonMap? owner}) {
    final id = node['id'];
    final length = node['lengthSeconds'];
    final createdAt = DateTime.tryParse('${node['createdAt']}');
    if (id is! String || length is! num || createdAt == null) {
      throw const FormatException('Invalid video node');
    }
    final ownerNode = node['owner'] is Map ? node['owner'] as Map : owner;
    final game = node['game'] is Map ? node['game'] as Map : null;
    final self = node['self'] is Map ? node['self'] as Map : null;
    return Vod(
      id: id,
      title: _as<String>(node['title']) ?? '',
      lengthSeconds: length.toInt(),
      createdAt: createdAt,
      viewCount: _as<num>(node['viewCount'])?.toInt() ?? 0,
      ownerId: _as<String>(ownerNode?['id']) ?? '',
      ownerLogin: _as<String>(ownerNode?['login']) ?? '',
      ownerDisplayName: _as<String>(ownerNode?['displayName']) ?? '',
      previewThumbnailUrl: _as<String>(node['previewThumbnailURL']),
      gameId: _as<String>(game?['id']),
      gameName: _as<String>(game?['name']),
      type: VodType.fromGql(node['broadcastType']),
      isRecording: node['status'] == 'RECORDING',
      isRestricted: self?['isRestricted'] == true,
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

/// A copyright-muted part of a VOD, in seconds from the start.
class MutedSegment {
  const MutedSegment({required this.offset, required this.duration});

  final int offset;
  final int duration;
}

/// [value] when it is a [T], else null (GQL data is never trusted to match).
T? _as<T>(Object? value) => value is T ? value : null;
