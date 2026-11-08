class ShoutoutCategory {
  final String id;
  final String name;
  final String? boxArtUrl;

  const ShoutoutCategory({
    required this.id,
    required this.name,
    this.boxArtUrl,
  });
}

class ShoutoutSchedule {
  final String? title;
  final DateTime startAt;
  final List<String> categories;

  const ShoutoutSchedule({
    required this.startAt,
    this.title,
    this.categories = const [],
  });
}

class ShoutoutProfile {
  final String id;
  final String login;
  final String displayName;
  final String? profileImageUrl;
  final List<ShoutoutCategory> categories;
  final ShoutoutSchedule? nextStream;
  final bool? following;

  const ShoutoutProfile({
    required this.id,
    required this.login,
    required this.displayName,
    this.profileImageUrl,
    this.categories = const [],
    this.nextStream,
    this.following,
  });

  ShoutoutProfile withFollowing(bool? following) => ShoutoutProfile(
    id: id,
    login: login,
    displayName: displayName,
    profileImageUrl: profileImageUrl,
    categories: categories,
    nextStream: nextStream,
    following: following,
  );

  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

  static ShoutoutProfile? tryParse(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final user = (body['data'] as Map?)?['user'];
    if (user is! Map) return null;
    final id = user['id'];
    final name = user['displayName'];
    final channel = user['channel'];
    final login = channel is Map ? channel['name'] : null;
    if (id is! String || name is! String || login is! String) return null;
    if (!_login.hasMatch(login)) return null;
    return ShoutoutProfile(
      id: id,
      login: login,
      displayName: name.isEmpty ? login : name,
      profileImageUrl: _httpsUrl(user['profileImageURL']),
      categories: _categories(channel),
      nextStream: _nextStream(channel),
    );
  }

  static bool? followingIn(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final self = ((body['data'] as Map?)?['user'] as Map?)?['self'];
    if (self is! Map) return null;
    final follower = self['follower'];
    return follower is Map && follower['followedAt'] is String;
  }

  static List<ShoutoutCategory> _categories(Map channel) {
    final shelves = (channel['home'] as Map?)?['shelves'] as Map?;
    final edges = (shelves?['categoryShelf'] as Map?)?['edges'];
    if (edges is! List) return const [];
    return [
      for (final edge in edges)
        if ((edge as Map?)?['node'] case {
          'id': final String id,
          'displayName': final String name,
        } when name.isNotEmpty)
          ShoutoutCategory(
            id: id,
            name: name,
            boxArtUrl: _httpsUrl((edge!['node'] as Map)['boxArtURL']),
          ),
    ];
  }

  static ShoutoutSchedule? _nextStream(Map channel) {
    final segment = (channel['schedule'] as Map?)?['nextSegment'];
    if (segment is! Map || segment['isCancelled'] == true) return null;
    final start = segment['startAt'];
    final startAt = start is String ? DateTime.tryParse(start) : null;
    if (startAt == null) return null;
    final title = segment['title'];
    final categories = segment['categories'];
    return ShoutoutSchedule(
      startAt: startAt,
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      categories: [
        if (categories is List)
          for (final category in categories)
            if ((category as Map?)?['displayName'] case final String name
                when name.isNotEmpty)
              name,
      ],
    );
  }

  static String? _httpsUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? value
        : null;
  }
}
