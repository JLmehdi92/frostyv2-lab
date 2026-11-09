enum LiveTogetherKind { costream, guestStar }

class LiveTogetherMember {
  const LiveTogetherMember({
    required this.id,
    required this.login,
    required this.displayName,
    this.imageUrl,
    this.viewers,
  });

  final String id;
  final String login;
  final String displayName;
  final String? imageUrl;
  final int? viewers;

  bool get isLive => viewers != null;

  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');
  static final _id = RegExp(r'^[0-9]{1,20}$');

  static LiveTogetherMember? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final login = raw['login'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (login is! String || !_login.hasMatch(login)) return null;
    final name = raw['displayName'];
    final image = raw['profileImageURL'];
    final stream = raw['stream'];
    final viewers = stream is Map ? stream['viewersCount'] : null;
    return LiveTogetherMember(
      id: id,
      login: login,
      displayName: name is String && name.isNotEmpty ? name : login,
      imageUrl: image is String && image.startsWith('https://') ? image : null,
      viewers: viewers is int && viewers >= 0
          ? viewers
          : stream is Map
          ? 0
          : null,
    );
  }
}

class LiveTogether {
  const LiveTogether({
    required this.kind,
    required this.members,
    this.host,
    this.totalCount,
    this.totalViewers,
  });

  final LiveTogetherKind kind;
  final LiveTogetherMember? host;
  final List<LiveTogetherMember> members;
  final int? totalCount;
  final int? totalViewers;

  List<LiveTogetherMember> othersThan(String channelId) =>
      [
        for (final member in [?host, ...members])
          if (member.id != channelId) member,
      ].fold([], (unique, member) {
        if (unique.every((known) => known.id != member.id)) unique.add(member);
        return unique;
      });

  int hiddenCount(String channelId) {
    final total = totalCount;
    if (total == null) return 0;
    final shown = othersThan(channelId).length + 1;
    return total > shown ? total - shown : 0;
  }

  static LiveTogether? fromCostream(Object? body) {
    final details = _path(body, ['data', 'user', 'stream', 'costreamDetails']);
    if (details is! Map) return null;
    final members = _members(details['topCostreamers']);
    final organizer = LiveTogetherMember.tryParse(details['organizer']);
    if (members.isEmpty && organizer == null) return null;
    final count = details['costreamersCount'];
    final viewers = details['totalViewersCount'];
    return LiveTogether(
      kind: LiveTogetherKind.costream,
      host: organizer,
      members: members,
      totalCount: count is int && count > 0 ? count : null,
      totalViewers: viewers is int && viewers >= 0 ? viewers : null,
    );
  }

  static LiveTogether? fromGuestStar(Object? body) {
    final channel = _path(body, ['data', 'channel']);
    if (channel is! Map) return null;
    final call = channel['guestStarSessionCall'];
    if (call is! Map) return null;
    final guests = call['guests'];
    final members = <LiveTogetherMember>[
      if (guests is List)
        for (final guest in guests)
          if (guest is Map) ?LiveTogetherMember.tryParse(guest['user']),
    ];
    if (members.isEmpty) return null;
    return LiveTogether(
      kind: LiveTogetherKind.guestStar,
      host: LiveTogetherMember.tryParse(channel['owner']),
      members: members,
    );
  }

  static List<LiveTogetherMember> _members(Object? raw) => [
    if (raw is List)
      for (final member in raw) ?LiveTogetherMember.tryParse(member),
  ];

  static Object? _path(Object? body, List<String> keys) {
    Object? node = body;
    for (final key in keys) {
      if (node is! Map) return null;
      node = node[key];
    }
    return node;
  }
}
