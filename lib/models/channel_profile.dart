import 'package:frosty/models/community_highlights.dart';

// A channel's profile page: header, about, panels and schedule, read from
// anonymous GQL. Every parser tolerates missing or odd fields, never
// throws, and returns null only when the channel itself is missing.

const _imageHosts = {'static-cdn.jtvnw.net', 'panels.twitch.tv'};

/// [value] as an https image on a Twitch image host, or null.
String? _image(Object? value) {
  final url = chString(value, max: 400);
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || !_imageHosts.contains(uri.host)) {
    return null;
  }
  return url;
}

/// [value] as an http(s) link, or null.
String? _link(Object? value) {
  final url = chString(value, max: 1000);
  final uri = url == null ? null : Uri.tryParse(url.trim());
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}

/// An "RRGGBB" accent colour as 0xFFRRGGBB, or null.
int? _color(Object? value) {
  final hex = chString(value, max: 7)?.replaceFirst('#', '');
  if (hex == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex, radix: 16);
}

enum BroadcasterRole { partner, affiliate, none }

class SocialLink {
  const SocialLink({
    required this.name,
    required this.title,
    required this.url,
  });

  /// Twitch's key for the site ("twitter", "discord"…), lowercase.
  final String name;
  final String title;
  final String url;

  static SocialLink? fromGql(Object? node) {
    final map = chMap(node);
    final url = _link(map?['url']);
    if (url == null) return null;
    final name = chString(map!['name'], max: 40)?.toLowerCase() ?? '';
    return SocialLink(
      name: name,
      title: chString(map['title'], max: 60) ?? name,
      url: url,
    );
  }
}

/// A panel under the channel's About: an image, a title and a Markdown
/// description, any of which can be missing. Extension panels are skipped.
class ChannelPanel {
  const ChannelPanel({
    required this.id,
    this.title,
    this.imageUrl,
    this.linkUrl,
    this.description,
    this.altText,
  });

  final String id;
  final String? title;
  final String? imageUrl;
  final String? linkUrl;
  final String? description;
  final String? altText;

  static ChannelPanel? fromGql(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 64);
    if (id == null || map!['type'] != 'DEFAULT') return null;
    final panel = ChannelPanel(
      id: id,
      title: chString(map['title'], max: 120),
      imageUrl: _image(map['imageURL']),
      linkUrl: _link(map['linkURL']),
      description: chString(map['description'], max: 5000),
      altText: chString(map['altText'], max: 300),
    );
    final empty =
        panel.title == null &&
        panel.imageUrl == null &&
        panel.description == null;
    return empty ? null : panel;
  }
}

class LastBroadcast {
  const LastBroadcast({this.title, this.startedAt, this.gameId, this.gameName});

  final String? title;
  final DateTime? startedAt;
  final String? gameId;
  final String? gameName;

  static LastBroadcast? fromGql(Object? node) {
    final map = chMap(node);
    if (map == null) return null;
    final game = chMap(map['game']);
    final gameId = chString(game?['id'], max: 20);
    final broadcast = LastBroadcast(
      title: chString(map['title'], max: 300),
      startedAt: chDate(map['startedAt']),
      gameId: gameId != null && RegExp(r'^[0-9]+$').hasMatch(gameId)
          ? gameId
          : null,
      gameName: chString(game?['displayName'], max: 100),
    );
    return broadcast.title == null && broadcast.startedAt == null
        ? null
        : broadcast;
  }
}

class LiveStatus {
  const LiveStatus({required this.isRerun, required this.viewers});

  final bool isRerun;
  final int viewers;

  static LiveStatus? fromGql(Object? node) {
    final map = chMap(node);
    if (chString(map?['id'], max: 32) == null) return null;
    return LiveStatus(
      isRerun: map!['type'] == 'rerun',
      viewers: (chInt(map['viewersCount']) ?? 0).clamp(0, 1 << 31),
    );
  }
}

class ChannelProfile {
  const ChannelProfile({
    required this.id,
    required this.login,
    required this.displayName,
    this.description,
    this.createdAt,
    this.profileImageUrl,
    this.bannerUrl,
    this.offlineImageUrl,
    this.accentColor,
    this.role = BroadcasterRole.none,
    this.followers,
    this.socials = const [],
    this.panels = const [],
    this.lastBroadcast,
    this.live,
  });

  final String id;
  final String login;
  final String displayName;
  final String? description;
  final DateTime? createdAt;
  final String? profileImageUrl;
  final String? bannerUrl;
  final String? offlineImageUrl;

  /// 0xFFRRGGBB.
  final int? accentColor;
  final BroadcasterRole role;
  final int? followers;
  final List<SocialLink> socials;
  final List<ChannelPanel> panels;
  final LastBroadcast? lastBroadcast;

  /// Null while offline.
  final LiveStatus? live;

  /// A GQL `user` node, or null when the channel does not exist.
  static ChannelProfile? fromGql(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 20);
    final login = chString(map?['login'], max: 25);
    if (id == null ||
        login == null ||
        !RegExp(r'^[0-9]+$').hasMatch(id) ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(login)) {
      return null;
    }
    final roles = chMap(map!['roles']);
    final channel = chMap(map['channel']);
    return ChannelProfile(
      id: id,
      login: login,
      displayName: chString(map['displayName'], max: 64) ?? login,
      description: chString(map['description'], max: 1000),
      createdAt: chDate(map['createdAt']),
      profileImageUrl: _image(map['profileImageURL']),
      bannerUrl: _image(map['bannerImageURL']),
      offlineImageUrl: _image(map['offlineImageURL']),
      accentColor: _color(map['primaryColorHex']),
      role: roles?['isPartner'] == true
          ? BroadcasterRole.partner
          : roles?['isAffiliate'] == true
          ? BroadcasterRole.affiliate
          : BroadcasterRole.none,
      followers: chInt(chMap(map['followers'])?['totalCount']),
      socials: [
        for (final item in chList(channel?['socialMedias']))
          ?SocialLink.fromGql(item),
      ],
      panels: [
        for (final item in chList(map['panels'], max: 40))
          ?ChannelPanel.fromGql(item),
      ],
      lastBroadcast: LastBroadcast.fromGql(map['lastBroadcast']),
      live: LiveStatus.fromGql(map['stream']),
    );
  }
}

class ScheduleSegment {
  const ScheduleSegment({
    required this.id,
    required this.startAt,
    this.endAt,
    this.title,
    this.isCancelled = false,
    this.categoryName,
  });

  final String id;
  final DateTime startAt;
  final DateTime? endAt;
  final String? title;
  final bool isCancelled;
  final String? categoryName;

  static ScheduleSegment? fromGql(Object? node) {
    final map = chMap(node);
    final id = chString(map?['id'], max: 200);
    final startAt = chDate(map?['startAt']);
    if (id == null || startAt == null) return null;
    final category = chMap(chList(map!['categories']).firstOrNull);
    return ScheduleSegment(
      id: id,
      startAt: startAt,
      endAt: chDate(map['endAt']),
      title: chString(map['title'], max: 140),
      isCancelled: map['isCancelled'] == true,
      categoryName: chString(category?['name'], max: 100),
    );
  }
}

/// The channel's streaming schedule: this week's and next week's segments.
class ChannelSchedule {
  const ChannelSchedule({required this.segments, this.nextStartAt});

  /// Sorted by start.
  final List<ScheduleSegment> segments;

  /// When the next (not cancelled) stream starts.
  final DateTime? nextStartAt;

  static const empty = ChannelSchedule(segments: []);

  /// A GQL `schedule` node; null (no schedule) reads as [empty].
  static ChannelSchedule fromGql(Object? node) {
    final map = chMap(node);
    if (map == null) return empty;
    final segments = [
      for (final item in chList(map['segments'], max: 100))
        ?ScheduleSegment.fromGql(item),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return ChannelSchedule(
      segments: segments,
      nextStartAt: chDate(chMap(map['nextSegment'])?['startAt']),
    );
  }

  /// The segments not over at [now] (one without an end counts as over
  /// four hours after its start).
  List<ScheduleSegment> upcoming(DateTime now) => [
    for (final segment in segments)
      if ((segment.endAt ?? segment.startAt.add(const Duration(hours: 4)))
          .isAfter(now))
        segment,
  ];
}
