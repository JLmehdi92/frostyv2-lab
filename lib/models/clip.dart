import 'dart:math' as math;

import 'package:onset/apis/base_api_client.dart';

/// How far back a channel's clips list looks (GQL `ClipsPeriod`; named in
/// lib/l10n/enum_labels.dart).
enum ClipPeriod {
  lastDay('LAST_DAY'),
  lastWeek('LAST_WEEK'),
  lastMonth('LAST_MONTH'),
  allTime('ALL_TIME');

  const ClipPeriod(this.gqlName);

  final String gqlName;
}

/// Order of a channel's clips list (GQL `ClipsSort`; named in
/// lib/l10n/enum_labels.dart). Anonymous clients get "server error" for the
/// other sorts (verified 2026-10-13).
enum ClipSort {
  top('VIEWS_DESC'),
  trending('TRENDING'),
  newest('VIEWS_DESC'),
  oldest('VIEWS_DESC');

  const ClipSort(this.gqlName);

  final String gqlName;

  ClipSort get fetched => this == trending ? trending : top;

  List<Clip> order(List<Clip> clips) => switch (this) {
    newest => [...clips]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    oldest => [...clips]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    top || trending => clips,
  };
}

typedef ClipDateRange = ({DateTime start, DateTime end});

final _slugPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$');

/// Whether [slug] looks like a Twitch clip slug: the old CamelCase ones and
/// the newer `Words-AbC123_x` ones. Slugs end up in URLs and GQL variables,
/// so anything else (slashes, dots, spaces, escapes) is refused.
bool isValidClipSlug(String slug) => _slugPattern.hasMatch(slug);

/// A clip (GQL `Clip`).
class Clip {
  const Clip({
    required this.id,
    required this.slug,
    required this.title,
    required this.viewCount,
    required this.createdAt,
    required this.durationSeconds,
    required this.broadcasterId,
    required this.broadcasterLogin,
    required this.broadcasterDisplayName,
    this.thumbnailUrl,
    this.curatorLogin,
    this.curatorDisplayName,
    this.gameId,
    this.gameName,
    this.vodId,
    this.vodOffsetSeconds,
    this.isFeatured = false,
  });

  /// Parses a GQL `Clip` node. Optional fields that are missing or of the
  /// wrong type are null; a node without `id`, a valid `slug`, `createdAt`
  /// or `durationSeconds` throws a [FormatException]. [broadcaster] is used
  /// when the node has none (channel lists).
  factory Clip.fromGql(JsonMap node, {JsonMap? broadcaster}) {
    final id = node['id'];
    final slug = node['slug'];
    final createdAt = DateTime.tryParse('${node['createdAt']}');
    final duration = node['durationSeconds'];
    if (id is! String ||
        slug is! String ||
        !isValidClipSlug(slug) ||
        createdAt == null ||
        duration is! num ||
        !duration.isFinite) {
      throw const FormatException('Invalid clip node');
    }
    final offset = _as<num>(node['videoOffsetSeconds']);
    final owner = node['broadcaster'] is Map
        ? node['broadcaster'] as Map
        : broadcaster;
    final curator = node['curator'] is Map ? node['curator'] as Map : null;
    final game = node['game'] is Map ? node['game'] as Map : null;
    final video = node['video'] is Map ? node['video'] as Map : null;
    final vodId = _as<String>(video?['id']);
    return Clip(
      id: id,
      slug: slug,
      title: _as<String>(node['title']) ?? '',
      viewCount: _nonNegative(_as<num>(node['viewCount'])) ?? 0,
      createdAt: createdAt,
      durationSeconds: _nonNegative(duration) ?? 0,
      broadcasterId: _as<String>(owner?['id']) ?? '',
      broadcasterLogin: _as<String>(owner?['login']) ?? '',
      broadcasterDisplayName: _as<String>(owner?['displayName']) ?? '',
      thumbnailUrl: _as<String>(node['thumbnailURL']),
      curatorLogin: _as<String>(curator?['login']),
      curatorDisplayName: _as<String>(curator?['displayName']),
      gameId: _as<String>(game?['id']),
      gameName: _as<String>(game?['name']),
      vodId: vodId,
      // An offset without its VOD is useless.
      vodOffsetSeconds: vodId == null || offset == null || offset < 0
          ? null
          : _nonNegative(offset),
      isFeatured: node['isFeatured'] == true,
    );
  }

  static Clip? tryHelix(Object? node, {String broadcasterLogin = ''}) {
    if (node is! Map) return null;
    final id = node['id'];
    final createdAt = DateTime.tryParse('${node['created_at']}');
    final duration = node['duration'];
    if (id is! String ||
        !isValidClipSlug(id) ||
        createdAt == null ||
        duration is! num ||
        !duration.isFinite) {
      return null;
    }
    final vodId = _as<String>(node['video_id']);
    final offset = _as<num>(node['vod_offset']);
    final hasVod = vodId != null && vodId.isNotEmpty;
    final thumbnail = _as<String>(node['thumbnail_url']);
    return Clip(
      id: id,
      slug: id,
      title: _as<String>(node['title']) ?? '',
      viewCount: _nonNegative(_as<num>(node['view_count'])) ?? 0,
      createdAt: createdAt,
      durationSeconds: _nonNegative(duration) ?? 0,
      broadcasterId: _as<String>(node['broadcaster_id']) ?? '',
      broadcasterLogin: broadcasterLogin,
      broadcasterDisplayName: _as<String>(node['broadcaster_name']) ?? '',
      thumbnailUrl: thumbnail != null && thumbnail.startsWith('https://')
          ? thumbnail
          : null,
      curatorDisplayName: _as<String>(node['creator_name']),
      gameId: _as<String>(node['game_id']),
      vodId: hasVod ? vodId : null,
      vodOffsetSeconds: hasVod && offset != null && offset >= 0
          ? _nonNegative(offset)
          : null,
      isFeatured: node['is_featured'] == true,
    );
  }

  final String id;
  final String slug;
  final String title;
  final int viewCount;
  final DateTime createdAt;
  final int durationSeconds;
  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterDisplayName;
  final String? thumbnailUrl;

  /// Who made the clip; null when their account is gone.
  final String? curatorLogin;
  final String? curatorDisplayName;
  final String? gameId;
  final String? gameName;

  /// The VOD the clip was cut from, while it still exists.
  final String? vodId;
  final int? vodOffsetSeconds;
  final bool isFeatured;

  Duration get duration => Duration(seconds: durationSeconds);

  /// Where the clip starts in [vodId].
  Duration? get vodOffset =>
      vodOffsetSeconds == null ? null : Duration(seconds: vodOffsetSeconds!);
}

/// A channel's top clips for one period and sort.
///
/// Anonymous clients cannot page further (cursor paging is integrity-gated),
/// so this is a single page of up to 100 clips.
class ClipPage {
  const ClipPage({
    required this.items,
    required this.hasMore,
    this.featuredKnown = true,
  });

  final bool featuredKnown;

  final List<Clip> items;

  /// Twitch has more clips than the ones returned.
  final bool hasMore;
}

/// A page of the top clips feed, and where the next one starts.
class ClipFeedPage {
  const ClipFeedPage({required this.items, this.cursor});

  final List<Clip> items;

  /// Twitch's cursor for the next page (null: this was the last one).
  final String? cursor;

  bool get hasMore => cursor != null;
}

/// One MP4 file of a clip.
class ClipRendition {
  const ClipRendition({
    required this.height,
    required this.frameRate,
    required this.url,
  });

  final int height;
  final double frameRate;

  /// The unsigned CDN URL (see [ClipPlayback.signedUrl]).
  final String url;

  /// "1080p60", "720p": the frame rate is shown above 30 fps, like Twitch.
  String get label =>
      frameRate > 31 ? '${height}p${frameRate.round()}' : '${height}p';
}

/// What a clip needs to play: its renditions (best first) and the access
/// token that signs them. Never log a signed URL: it carries the token.
class ClipPlayback {
  const ClipPlayback({
    required this.renditions,
    required this.signature,
    required this.token,
  });

  final List<ClipRendition> renditions;
  final String signature;
  final String token;

  /// [rendition]'s URL with the `sig` and `token` the CDN requires.
  String signedUrl(ClipRendition rendition) =>
      signClipUrl(rendition.url, signature: signature, token: token);
}

/// [url] with the clip access token's `sig` and `token` added (encoded),
/// keeping its own query parameters.
String signClipUrl(
  String url, {
  required String signature,
  required String token,
}) {
  final uri = Uri.parse(url);
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'sig': signature,
          'token': token,
        },
      )
      .toString();
}

/// [value] when it is a [T], else null (GQL data is never trusted to match).
T? _as<T>(Object? value) => value is T ? value : null;

/// [value] as a whole number, at least 0; null when not finite.
int? _nonNegative(num? value) =>
    value == null || !value.isFinite ? null : math.max(0, value.toInt());

class ClipExtras {
  const ClipExtras({required this.autoClip, required this.hasPortrait});

  static ClipExtras? tryParse(Object? clip) {
    if (clip is! Map) return null;
    final assets = clip['assets'] is List ? clip['assets'] as List : const [];
    final hasPortrait = assets.any(
      (asset) =>
          asset is Map &&
          asset['type'] == 'RECOMPOSED' &&
          asset['aspectRatio'] is num &&
          (asset['aspectRatio'] as num) > 0 &&
          (asset['aspectRatio'] as num) < 1,
    );
    return ClipExtras(
      autoClip: clip['isAutoCurated'] == true,
      hasPortrait: hasPortrait,
    );
  }

  final bool autoClip;
  final bool hasPortrait;
}
