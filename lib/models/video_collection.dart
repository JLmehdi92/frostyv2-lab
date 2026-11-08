import 'package:onset/apis/base_api_client.dart';

class VideoCollection {
  const VideoCollection({
    required this.id,
    required this.title,
    required this.itemCount,
    required this.firstVideoId,
    this.thumbnailUrl,
    this.updatedAt,
    this.lengthSeconds = 0,
  });

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _videoId = RegExp(r'^[0-9]{1,20}$');

  static VideoCollection? tryParse(Object? node) {
    if (node is! Map) return null;
    final id = node['id'];
    final items = node['items'];
    final count = items is Map ? items['totalCount'] : null;
    final edges = items is Map ? items['edges'] : null;
    final firstEdge = edges is List && edges.isNotEmpty ? edges.first : null;
    final firstNode = firstEdge is Map ? firstEdge['node'] : null;
    final firstId = firstNode is Map ? firstNode['id'] : null;
    if (id is! String ||
        !_id.hasMatch(id) ||
        firstId is! String ||
        !_videoId.hasMatch(firstId)) {
      return null;
    }
    final title = node['title'];
    final thumbnail = node['thumbnailURL'];
    final length = node['lengthSeconds'];
    return VideoCollection(
      id: id,
      title: title is String ? title : '',
      itemCount: count is num && count.isFinite && count > 0
          ? count.toInt()
          : 1,
      firstVideoId: firstId,
      thumbnailUrl: thumbnail is String && thumbnail.startsWith('https://')
          ? thumbnail
          : null,
      updatedAt: DateTime.tryParse('${node['updatedAt']}'),
      lengthSeconds: length is num && length.isFinite && length > 0
          ? length.toInt()
          : 0,
    );
  }

  static List<VideoCollection> listFrom(JsonMap data) {
    final user = data['user'];
    final collections = user is Map ? user['collections'] : null;
    final edges = collections is Map ? collections['edges'] : null;
    return [
      if (edges is List)
        for (final edge in edges)
          if (edge is Map) ?tryParse(edge['node']),
    ];
  }

  final String id;
  final String title;
  final int itemCount;
  final String firstVideoId;
  final String? thumbnailUrl;
  final DateTime? updatedAt;
  final int lengthSeconds;
}
