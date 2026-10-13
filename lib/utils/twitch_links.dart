import 'package:frosty/models/clip.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_time.dart';

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
    ChannelLink() || OtherLink() => false,
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

  static TwitchLink _parse(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return const OtherLink();
    }
    final host = uri.host.toLowerCase();
    if (host == 'clips.twitch.tv') return _clipsHost(uri);
    if (host != 'twitch.tv' &&
        host != 'www.twitch.tv' &&
        host != 'm.twitch.tv') {
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
          .where((s) => s.name == segments[1])
          .firstOrNull;
      if (section != null) return ChannelProfileLink(first, section);
    }
    if (segments.length == 1) return ChannelLink(first);
    return const OtherLink();
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
    return VodLink(id, startAt: t == null ? null : parseTwitchTimestamp(t));
  }

  static final _vodId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

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
  };
}

/// A past broadcast, highlight or upload, optionally at a time.
final class VodLink extends TwitchLink {
  const VodLink(this.vodId, {this.startAt});

  final String vodId;
  final Duration? startAt;

  @override
  bool operator ==(Object other) =>
      other is VodLink && other.vodId == vodId && other.startAt == startAt;

  @override
  int get hashCode => Object.hash(vodId, startAt);

  @override
  String toString() => 'VodLink($vodId, $startAt)';
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
  const ChannelLink(this.login);

  final String login;

  @override
  bool operator ==(Object other) =>
      other is ChannelLink && other.login == login;

  @override
  int get hashCode => login.hashCode;

  @override
  String toString() => 'ChannelLink($login)';
}

/// Anything the app does not open itself.
final class OtherLink extends TwitchLink {
  const OtherLink();
}
