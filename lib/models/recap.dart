import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/clip.dart';

class Recap {
  const Recap({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channelLogin,
    required this.channelDisplayName,
    required this.clips,
    this.streamStartAt,
    this.postedAt,
  });

  static final _id = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  static bool isValidId(String id) => _id.hasMatch(id);

  static Recap? tryParse(Object? node) {
    if (node is! Map) return null;
    final id = node['id'];
    if (id is! String || !isValidId(id)) return null;
    if (node['state'] != 'PUBLISHED') return null;
    final channel = node['channel'] is Map ? node['channel'] as Map : null;
    final owner = <String, Object?>{
      'id': channel?['id'],
      'login': channel?['login'],
      'displayName': channel?['displayName'],
    };
    final entries = node['clips'] is List ? node['clips'] as List : const [];
    final positioned = <(int, int, Clip)>[];
    for (final (index, entry) in entries.indexed) {
      if (entry is! Map || entry['clip'] is! Map) continue;
      try {
        final clip = Clip.fromGql(
          JsonMap.from(entry['clip'] as Map),
          broadcaster: owner,
        );
        final position = entry['position'];
        positioned.add((position is int ? position : index, index, clip));
      } on FormatException {
        continue;
      }
    }
    if (positioned.isEmpty) return null;
    positioned.sort((a, b) {
      final byPosition = a.$1.compareTo(b.$1);
      return byPosition != 0 ? byPosition : a.$2.compareTo(b.$2);
    });
    final login = owner['login'];
    final displayName = owner['displayName'];
    final title = node['title'];
    return Recap(
      id: id,
      title: title is String ? title.trim() : '',
      channelId: owner['id'] is String ? owner['id']! as String : '',
      channelLogin: login is String ? login : '',
      channelDisplayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : (login is String ? login : ''),
      clips: [for (final (_, _, clip) in positioned) clip],
      streamStartAt: DateTime.tryParse('${node['streamStartAt']}'),
      postedAt: DateTime.tryParse('${node['postedAt']}'),
    );
  }

  final String id;
  final String title;
  final String channelId;
  final String channelLogin;
  final String channelDisplayName;
  final List<Clip> clips;
  final DateTime? streamStartAt;
  final DateTime? postedAt;

  Duration get duration =>
      clips.fold(Duration.zero, (total, clip) => total + clip.duration);

  String? get thumbnailUrl => clips.first.thumbnailUrl;
}

class RecapUnavailableException implements Exception {
  const RecapUnavailableException();
}
