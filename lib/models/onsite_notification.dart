class OnsiteNotification {
  const OnsiteNotification({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.category,
    this.creatorName,
    this.avatarUrl,
    this.thumbnailUrl,
    this.channelLogin,
    this.link,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? category;
  final String? creatorName;
  final String? avatarUrl;
  final String? thumbnailUrl;
  final String? channelLogin;
  final Uri? link;

  static const maxBodyLength = 500;
  static final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
  static final _markup = RegExp('<[^>]*>');

  OnsiteNotification read() => _withRead(true);

  OnsiteNotification unread() => _withRead(false);

  OnsiteNotification _withRead(bool isRead) => OnsiteNotification(
    id: id,
    body: body,
    createdAt: createdAt,
    isRead: isRead,
    category: category,
    creatorName: creatorName,
    avatarUrl: avatarUrl,
    thumbnailUrl: thumbnailUrl,
    channelLogin: channelLogin,
    link: link,
  );

  static OnsiteNotification? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final rawBody = json['body'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id is! String || id.isEmpty || id.length > 256) return null;
    if (rawBody is! String || createdAt == null) return null;
    final body = rawBody.replaceAll(_markup, '').trim();
    if (body.isEmpty || body.length > maxBodyLength) return null;
    final creators = json['creators'];
    final creator = creators is List ? creators.firstOrNull : null;
    final name = creator is Map ? creator['displayName'] : null;
    final category = json['category'];
    return OnsiteNotification(
      id: id,
      body: body,
      createdAt: createdAt.toLocal(),
      isRead: json['isRead'] == true,
      category: category is String && category.isNotEmpty ? category : null,
      creatorName: name is String && name.isNotEmpty && name.length <= 64
          ? name
          : null,
      avatarUrl: _image(creator is Map ? creator['profileImageURL'] : null),
      thumbnailUrl: _image(json['thumbnailURL']),
      channelLogin: _channelOf(json['extra']),
      link: _linkOf(json),
    );
  }

  static String? _channelOf(Object? extra) {
    if (extra is! Map || extra['__typename'] != 'User') return null;
    final login = extra['login'];
    return login is String && _login.hasMatch(login)
        ? login.toLowerCase()
        : null;
  }

  static Uri? _linkOf(Map<dynamic, dynamic> json) {
    final actions = json['actions'];
    if (actions is! List) return null;
    for (final action in actions) {
      final url = action is Map ? action['url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri != null && _isTwitch(uri)) return uri;
    }
    return null;
  }

  static bool _isTwitch(Uri uri) =>
      uri.scheme == 'https' &&
      (uri.host == 'twitch.tv' || uri.host.endsWith('.twitch.tv'));

  static String? _image(Object? url) {
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null || uri.scheme != 'https') return null;
    return uri.host.endsWith('.jtvnw.net') || uri.host.endsWith('.twitch.tv')
        ? url as String
        : null;
  }
}

enum NotificationPlatform { push, email }

class NotificationCategorySetting {
  const NotificationCategorySetting({
    required this.category,
    required this.platforms,
  });

  final String category;
  final Map<NotificationPlatform, bool> platforms;

  static final _category = RegExp(r'^[a-zA-Z0-9_\-]{1,64}$');

  static NotificationCategorySetting? fromJson(Object? json) {
    if (json is! Map) return null;
    final category = json['category'];
    final platforms = json['platforms'];
    if (category is! String || !_category.hasMatch(category)) return null;
    if (platforms is! List) return null;
    final states = <NotificationPlatform, bool>{};
    for (final platform in platforms) {
      if (platform is! Map) continue;
      final kind = _platformOf('${platform['platformName']}');
      final enabled = platform['isEnabled'];
      if (kind != null && enabled is bool) states[kind] = enabled;
    }
    if (!states.containsKey(NotificationPlatform.push) &&
        !states.containsKey(NotificationPlatform.email)) {
      return null;
    }
    return NotificationCategorySetting(category: category, platforms: states);
  }

  static NotificationPlatform? _platformOf(String name) => switch (name) {
    'push' => NotificationPlatform.push,
    'email' => NotificationPlatform.email,
    _ => null,
  };
}
