import 'package:onset/apis/base_api_client.dart';

/// Part of a replayed chat message: plain text or a Twitch emote.
class VodFragment {
  const VodFragment({required this.text, this.emoteId});

  final String text;

  /// Twitch emote id when this fragment is an emote.
  final String? emoteId;
}

/// A chat message recorded with a VOD (GQL `VideoComment`).
///
/// Only Twitch emotes come as fragments; 7TV/BTTV/FFZ emotes are plain text
/// and are matched client-side like in live chat.
class VodComment {
  const VodComment({
    required this.id,
    required this.offsetSeconds,
    required this.fragments,
    required this.badges,
    this.commenterId,
    this.commenterLogin,
    this.commenterDisplayName,
    this.color,
  });

  /// Parses a GQL `VideoComment` node. Fields that are missing or of the
  /// wrong type fall back to null/empty instead of throwing.
  factory VodComment.fromGql(JsonMap node) {
    final commenter = node['commenter'] is Map
        ? node['commenter'] as Map
        : null;
    final message = node['message'] is Map ? node['message'] as Map : const {};
    final fragments = <VodFragment>[
      for (final f in _as<List>(message['fragments']) ?? const [])
        if (f is Map)
          VodFragment(
            text: _as<String>(f['text']) ?? '',
            emoteId: f['emote'] is Map
                ? _as<String>((f['emote'] as Map)['emoteID'])
                : null,
          ),
    ];
    final badges = <({String setId, String version})>[
      for (final b in _as<List>(message['userBadges']) ?? const [])
        if (b is Map && b['setID'] is String && b['version'] is String)
          (setId: b['setID'] as String, version: b['version'] as String),
    ];
    return VodComment(
      id: _as<String>(node['id']),
      offsetSeconds: _as<num>(node['contentOffsetSeconds'])?.toInt() ?? 0,
      fragments: fragments,
      badges: badges,
      commenterId: _as<String>(commenter?['id']),
      commenterLogin: _as<String>(commenter?['login']),
      commenterDisplayName: _as<String>(commenter?['displayName']),
      color: _as<String>(message['userColor']),
    );
  }

  final String? id;
  final int offsetSeconds;
  final List<VodFragment> fragments;
  final List<({String setId, String version})> badges;
  final String? commenterId;
  final String? commenterLogin;
  final String? commenterDisplayName;
  final String? color;

  String get text => fragments.map((f) => f.text).join();

  /// Stable identity for de-duplicating overlapping pages.
  String get key => id ?? '$offsetSeconds|$commenterId|$text';
}

/// One page of replayed chat, starting just before the requested offset.
class VodCommentPage {
  const VodCommentPage({required this.comments, required this.hasNextPage});

  final List<VodComment> comments;
  final bool hasNextPage;
}

/// [value] when it is a [T], else null (GQL data is never trusted to match).
T? _as<T>(Object? value) => value is T ? value : null;
