import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_time.dart';

/// What a twitch.tv link points to, for the links the app opens itself.
sealed class TwitchLink {
  const TwitchLink();

  /// Parses a link found in text (chat, a deep link). A scheme-less
  /// `twitch.tv/...` is accepted, and trailing punctuation is ignored.
  static TwitchLink parseText(String text) {
    var value = text.trim().replaceFirst(RegExp(r'[.,!?)\]]+$'), '');
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    return uri == null ? const OtherLink() : parse(uri);
  }

  static TwitchLink parse(Uri uri) {
    final host = uri.host.toLowerCase();
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
    if (_reserved.contains(first) || !_login.hasMatch(first)) {
      return const OtherLink();
    }
    // /<channel>/v/<id>, /<channel>/video/<id> (legacy)
    if (segments.length == 3 &&
        (segments[1] == 'v' || segments[1] == 'video')) {
      return _vod(segments[2], uri);
    }
    // /<channel>/videos[/archive|highlights|uploads][?filter=…]
    if (segments.length >= 2 && segments[1] == 'videos') {
      final filter = segments.length > 2
          ? segments[2]
          : uri.queryParameters['filter'];
      return ChannelVideosLink(first, type: _types[filter]);
    }
    if (segments.length == 1) return ChannelLink(first);
    return const OtherLink();
  }

  static TwitchLink _vod(String id, Uri uri) {
    if (!_vodId.hasMatch(id)) return const OtherLink();
    final t = uri.queryParameters['t'];
    return VodLink(id, startAt: t == null ? null : parseTwitchTimestamp(t));
  }

  static final _vodId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

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
