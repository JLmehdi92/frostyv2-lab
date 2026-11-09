import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/vod/vod_time.dart';

/// What a twitch.tv link points to, for the links the app opens itself.
sealed class TwitchLink {
  const TwitchLink();

  /// Videos and clips open in-app (never in a browser); channels and
  /// everything else keep their usual handling.
  bool get opensInApp => switch (this) {
    VodLink() ||
    ChannelVideosLink() ||
    ClipLink() ||
    ChannelClipsLink() ||
    ChannelProfileLink() => true,
    // A category opens in-app from a deep link only (the app's handler);
    // tapped in chat it keeps the browser, as before.
    ChannelLink() ||
    CategoryLink() ||
    CategoryVideosLink() ||
    ChannelChatLink() ||
    CollectionLink() ||
    SearchLink() ||
    BrowseLink() ||
    FollowingLink() ||
    ActivityLink() ||
    OtherLink() => false,
  };

  /// Parses a link found in text (chat, a deep link). A scheme-less
  /// `twitch.tv/...` is accepted, and trailing punctuation is ignored.
  static TwitchLink parseText(String text) {
    var value = text.trim().replaceFirst(RegExp(r'[.,!?)\]]+$'), '');
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    return uri == null ? const OtherLink() : parse(uri);
  }

  /// Never throws: a link with malformed escapes is an [OtherLink].
  static TwitchLink parse(Uri uri) {
    try {
      return _parse(uri);
    } on FormatException {
      return const OtherLink();
    }
  }

  static Uri? webUri(Uri uri) {
    try {
      return switch (uri.scheme.toLowerCase()) {
        'https' || 'http' => uri,
        'twitch' || 'ttv' => _appToWeb(uri),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static Uri? _appToWeb(Uri uri) {
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    final query = uri.queryParameters;
    Uri web(List<String> path, [Map<String, String>? parameters]) => Uri(
      scheme: 'https',
      host: 'www.twitch.tv',
      pathSegments: path,
      queryParameters: parameters == null || parameters.isEmpty
          ? null
          : parameters,
    );
    switch (uri.host.toLowerCase()) {
      case 'stream' || 'channel' || 'profile':
        return segments.isEmpty ? null : web(segments);
      case 'open':
        final login = query['stream'] ?? query['channel'];
        return login == null || login.isEmpty
            ? web(['directory', 'following'])
            : web([login]);
      case 'following':
        return web(['directory', 'following']);
      case 'directory':
        return web(['directory', ...segments]);
      case 'game':
        return segments.isEmpty
            ? null
            : web(['directory', 'game', ...segments]);
      case 'search':
        final term = query['term'] ?? query['query'] ?? '';
        return web(['search'], {if (term.isNotEmpty) 'term': term});
      case 'video':
        final t = query['t'];
        return segments.isEmpty
            ? null
            : web(['videos', ...segments], {'t': ?t});
      case 'activity':
        return web(['activity']);
      default:
        return null;
    }
  }

  static TwitchLink _parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'twitch' || scheme == 'ttv') {
      final web = _appToWeb(uri);
      return web == null ? const OtherLink() : _parse(web);
    }
    if (scheme != 'https' && scheme != 'http') {
      return const OtherLink();
    }
    final host = uri.host.toLowerCase();
    if (host == 'clips.twitch.tv') return _clipsHost(uri);
    if (host != 'twitch.tv' &&
        host != 'www.twitch.tv' &&
        host != 'm.twitch.tv' &&
        host != 'go.twitch.tv') {
      return const OtherLink();
    }
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.isEmpty) return const OtherLink();
    final first = segments.first.toLowerCase();

    // /videos/<id>, /v/<id>
    if ((first == 'videos' || first == 'v') && segments.length == 2) {
      return _vod(segments[1], uri);
    }
    // /clip/<slug> (mobile web)
    if (first == 'clip' && segments.length == 2) return _clip(segments[1]);
    if (first == 'directory') return _directory(segments);
    if (segments.length == 1) {
      switch (first) {
        case 'following':
          return const FollowingLink();
        case 'activity':
          return const ActivityLink();
        case 'search':
          return SearchLink(_searchTerm(uri.queryParameters['term']));
      }
    }
    if (first == 'collections') {
      return segments.length == 2 && _collectionId.hasMatch(segments[1])
          ? CollectionLink(segments[1])
          : const OtherLink();
    }
    if (_reserved.contains(first) || !_login.hasMatch(first)) {
      return const OtherLink();
    }
    // /<channel>/v/<id>, /<channel>/video/<id> (legacy)
    if (segments.length == 3 &&
        (segments[1] == 'v' || segments[1] == 'video')) {
      return _vod(segments[2], uri);
    }
    // /<channel>/clip/<slug>
    if (segments.length == 3 && segments[1] == 'clip') {
      return _clip(segments[2]);
    }
    // /<channel>/clips[?range=24hr|7d|30d|all]
    if (segments.length == 2 && segments[1] == 'clips') {
      return ChannelClipsLink(
        first,
        period: _ranges[uri.queryParameters['range']],
      );
    }
    // /<channel>/videos[/archive|highlights|uploads][?filter=…]
    if (segments.length >= 2 && segments[1] == 'videos') {
      final filter = segments.length > 2
          ? segments[2]
          : uri.queryParameters['filter'];
      // The old clips tab of the videos page.
      if (filter == 'clips') {
        return ChannelClipsLink(
          first,
          period: _ranges[uri.queryParameters['range']],
        );
      }
      return ChannelVideosLink(first, type: _types[filter]);
    }
    // /<channel>/about, /<channel>/schedule
    if (segments.length == 2) {
      final section = ProfileSection.values
          .where((s) => s.name == segments[1].toLowerCase())
          .firstOrNull;
      if (section != null) return ChannelProfileLink(first, section);
    }
    if (segments.length == 2 && segments[1].toLowerCase() == 'chat') {
      return ChannelChatLink(first);
    }
    if (segments.length == 1) {
      return ChannelLink(
        first,
        followRequested: uri.queryParameters['followChannel'] == 'true',
      );
    }
    return const OtherLink();
  }

  static TwitchLink _directory(List<String> segments) {
    if (segments.length == 1) return const BrowseLink();
    if (segments[1].toLowerCase() == 'following') return const FollowingLink();
    if (segments.length < 3) return const OtherLink();
    final category = _category(segments[1].toLowerCase(), segments[2]);
    if (category == null) return const OtherLink();
    if (segments.length == 3) return category;
    if (segments[3].toLowerCase() == 'videos') {
      return CategoryVideosLink(category);
    }
    return const OtherLink();
  }

  static CategoryLink? _category(String kind, String value) {
    if (kind == 'category' && _categorySlug.hasMatch(value)) {
      return CategoryLink(slug: value.toLowerCase());
    }
    final name = value.trim();
    // A name is one path segment: one that would climb out of the page
    // ("..", a slash once decoded) is not a category.
    if (kind == 'game' &&
        name.isNotEmpty &&
        name.length <= 100 &&
        name != '.' &&
        name != '..' &&
        !name.contains(RegExp(r'[/\\\x00-\x1f\x7f]'))) {
      return CategoryLink(name: name);
    }
    return null;
  }

  static String _searchTerm(String? raw) {
    final term = (raw ?? '').replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    return term.length <= 100 ? term : term.substring(0, 100);
  }

  /// `clips.twitch.tv/<slug>` and `clips.twitch.tv/embed?clip=<slug>`.
  static TwitchLink _clipsHost(Uri uri) {
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.length != 1) return const OtherLink();
    final page = segments.single;
    if (page == 'embed') return _clip(uri.queryParameters['clip'] ?? '');
    if (page == 'create') return const OtherLink();
    return _clip(page);
  }

  /// Slugs are case-sensitive: kept as written.
  static TwitchLink _clip(String slug) =>
      isValidClipSlug(slug) ? ClipLink(slug) : const OtherLink();

  static TwitchLink _vod(String id, Uri uri) {
    if (!_vodId.hasMatch(id)) return const OtherLink();
    final t = uri.queryParameters['t'];
    final collection = uri.queryParameters['collection'];
    return VodLink(
      id,
      startAt: t == null ? null : parseTwitchTimestamp(t),
      collectionId: collection != null && _collectionId.hasMatch(collection)
          ? collection
          : null,
    );
  }

  static final _vodId = RegExp(r'^[0-9]{1,20}$');
  static final _categorySlug = RegExp(
    r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
    caseSensitive: false,
  );
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');
  static final _collectionId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static const _ranges = {
    '24hr': ClipPeriod.lastDay,
    '7d': ClipPeriod.lastWeek,
    '30d': ClipPeriod.lastMonth,
    'all': ClipPeriod.allTime,
  };

  static const _types = {
    'archive': VodType.archive,
    'archives': VodType.archive,
    'highlight': VodType.highlight,
    'highlights': VodType.highlight,
    'upload': VodType.upload,
    'uploads': VodType.upload,
  };

  /// First path segments that are Twitch pages, not channels.
  static const _reserved = {
    'videos',
    'v',
    'directory',
    'settings',
    'search',
    'p',
    'downloads',
    'jobs',
    'turbo',
    'subscriptions',
    'wallet',
    'inventory',
    'drops',
    'friends',
    'messages',
    'following',
    'login',
    'signup',
    'prime',
    'store',
    'clips',
    'clip',
    'popout',
    'moderator',
    'broadcast',
    'team',
    'u',
    'embed',
    'products',
    'activity',
    'collections',
  };
}

/// A past broadcast, highlight or upload, optionally at a time.
final class VodLink extends TwitchLink {
  const VodLink(this.vodId, {this.startAt, this.collectionId});

  final String vodId;
  final Duration? startAt;
  final String? collectionId;

  @override
  bool operator ==(Object other) =>
      other is VodLink &&
      other.vodId == vodId &&
      other.startAt == startAt &&
      other.collectionId == collectionId;

  @override
  int get hashCode => Object.hash(vodId, startAt, collectionId);

  @override
  String toString() => 'VodLink($vodId, $startAt, $collectionId)';
}

/// A clip, by its (case-sensitive) slug.
final class ClipLink extends TwitchLink {
  const ClipLink(this.slug);

  final String slug;

  @override
  bool operator ==(Object other) => other is ClipLink && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;

  @override
  String toString() => 'ClipLink($slug)';
}

/// A channel's clips, optionally for one period.
final class ChannelClipsLink extends TwitchLink {
  const ChannelClipsLink(this.login, {this.period});

  final String login;
  final ClipPeriod? period;

  @override
  bool operator ==(Object other) =>
      other is ChannelClipsLink &&
      other.login == login &&
      other.period == period;

  @override
  int get hashCode => Object.hash(login, period);

  @override
  String toString() => 'ChannelClipsLink($login, $period)';
}

/// A channel's videos page, optionally on one tab.
final class ChannelVideosLink extends TwitchLink {
  const ChannelVideosLink(this.login, {this.type});

  final String login;
  final VodType? type;

  @override
  bool operator ==(Object other) =>
      other is ChannelVideosLink && other.login == login && other.type == type;

  @override
  int get hashCode => Object.hash(login, type);

  @override
  String toString() => 'ChannelVideosLink($login, $type)';
}

/// The profile sections a link can point to.
enum ProfileSection { about, schedule }

/// A channel's About or Schedule page.
final class ChannelProfileLink extends TwitchLink {
  const ChannelProfileLink(this.login, this.section);

  final String login;
  final ProfileSection section;

  @override
  bool operator ==(Object other) =>
      other is ChannelProfileLink &&
      other.login == login &&
      other.section == section;

  @override
  int get hashCode => Object.hash(login, section);

  @override
  String toString() => 'ChannelProfileLink($login, ${section.name})';
}

/// A channel page.
final class ChannelLink extends TwitchLink {
  const ChannelLink(this.login, {this.followRequested = false});

  final String login;
  final bool followRequested;

  @override
  bool operator ==(Object other) =>
      other is ChannelLink &&
      other.login == login &&
      other.followRequested == followRequested;

  @override
  int get hashCode => Object.hash(login, followRequested);

  @override
  String toString() =>
      'ChannelLink($login${followRequested ? ', followRequested' : ''})';
}

/// A category's page: by its [slug] (`/directory/category/<slug>`) or, in
/// the older form, by its [name] (`/directory/game/<name>`).
final class CategoryLink extends TwitchLink {
  const CategoryLink({this.slug, this.name})
    : assert((slug == null) != (name == null));

  final String? slug;
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is CategoryLink && other.slug == slug && other.name == name;

  @override
  int get hashCode => Object.hash(slug, name);

  @override
  String toString() => 'CategoryLink(${slug ?? name})';
}

/// [link]'s page on twitch.tv, its slug or name kept as one path segment
/// (encoded, never read as a path).
Uri twitchCategoryUrl(CategoryLink link) => Uri(
  scheme: 'https',
  host: 'www.twitch.tv',
  pathSegments: link.slug != null
      ? ['directory', 'category', link.slug!]
      : ['directory', 'game', link.name!],
);

/// Anything the app does not open itself.
final class OtherLink extends TwitchLink {
  const OtherLink();
}

final class CategoryVideosLink extends TwitchLink {
  const CategoryVideosLink(this.category);

  final CategoryLink category;

  @override
  bool operator ==(Object other) =>
      other is CategoryVideosLink && other.category == category;

  @override
  int get hashCode => category.hashCode;

  @override
  String toString() => 'CategoryVideosLink($category)';
}

final class ChannelChatLink extends TwitchLink {
  const ChannelChatLink(this.login);

  final String login;

  @override
  bool operator ==(Object other) =>
      other is ChannelChatLink && other.login == login;

  @override
  int get hashCode => login.hashCode;

  @override
  String toString() => 'ChannelChatLink($login)';
}

final class CollectionLink extends TwitchLink {
  const CollectionLink(this.collectionId);

  final String collectionId;

  @override
  bool operator ==(Object other) =>
      other is CollectionLink && other.collectionId == collectionId;

  @override
  int get hashCode => collectionId.hashCode;

  @override
  String toString() => 'CollectionLink($collectionId)';
}

final class SearchLink extends TwitchLink {
  const SearchLink(this.term);

  final String term;

  @override
  bool operator ==(Object other) => other is SearchLink && other.term == term;

  @override
  int get hashCode => term.hashCode;

  @override
  String toString() => 'SearchLink($term)';
}

final class BrowseLink extends TwitchLink {
  const BrowseLink();

  @override
  bool operator ==(Object other) => other is BrowseLink;

  @override
  int get hashCode => (BrowseLink).hashCode;
}

final class FollowingLink extends TwitchLink {
  const FollowingLink();

  @override
  bool operator ==(Object other) => other is FollowingLink;

  @override
  int get hashCode => (FollowingLink).hashCode;
}

final class ActivityLink extends TwitchLink {
  const ActivityLink();

  @override
  bool operator ==(Object other) => other is ActivityLink;

  @override
  int get hashCode => (ActivityLink).hashCode;
}

/// [name]'s slug, as twitch.tv writes it in a category's address
/// ("Tom Clancy's Rainbow Six Siege" → `tom-clancys-rainbow-six-siege`).
String twitchCategorySlug(String name) {
  const accents = {
    'a': 'àáâãäåāăą',
    'c': 'çćčĉ',
    'd': 'ďđ',
    'e': 'èéêëēėęě',
    'g': 'ğ',
    'i': 'ìíîïīı',
    'l': 'łľ',
    'n': 'ñńň',
    'o': 'òóôõöøō',
    'r': 'ř',
    's': 'śšş',
    't': 'ťţ',
    'u': 'ùúûüūů',
    'y': 'ýÿ',
    'z': 'źžż',
    'ss': 'ß',
    'ae': 'æ',
    'oe': 'œ',
  };
  final buffer = StringBuffer();
  for (final char in name.toLowerCase().split('')) {
    final plain = accents.entries
        .where((entry) => entry.value.contains(char))
        .firstOrNull
        ?.key;
    buffer.write(plain ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp("['’]"), '')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// The channel [login]'s subscription page on twitch.tv, where Twitch offers
/// to subscribe or gift a sub (in-app purchases go through Google Play
/// billing in Twitch's own app, so the web page is the only way here).
/// Null for anything but a login.
Uri? twitchSubscribeUrl(String login) {
  final name = login.toLowerCase();
  if (!RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(name)) return null;
  return Uri.https('www.twitch.tv', '/subs/$name');
}
