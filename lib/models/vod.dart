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

  /// Parses a GQL `Video` node. Optional fields are tolerated; a node without
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
      title: node['title'] as String? ?? '',
      lengthSeconds: length.toInt(),
      createdAt: createdAt,
      viewCount: (node['viewCount'] as num?)?.toInt() ?? 0,
      ownerId: ownerNode?['id'] as String? ?? '',
      ownerLogin: ownerNode?['login'] as String? ?? '',
      ownerDisplayName: ownerNode?['displayName'] as String? ?? '',
      previewThumbnailUrl: node['previewThumbnailURL'] as String?,
      gameId: game?['id'] as String?,
      gameName: game?['name'] as String?,
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

/// One page of a channel's videos.
class VodPage {
  const VodPage({
    required this.items,
    required this.cursor,
    required this.hasNextPage,
  });

  final List<Vod> items;

  /// Cursor of the last item, to request the next page.
  final String? cursor;
  final bool hasNextPage;
}

/// A copyright-muted part of a VOD, in seconds from the start.
class MutedSegment {
  const MutedSegment({required this.offset, required this.duration});

  final int offset;
  final int duration;
}
