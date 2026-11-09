class ChatBadgeChoice {
  const ChatBadgeChoice({
    required this.setId,
    required this.version,
    required this.title,
    this.imageUrl,
  });

  final String setId;
  final String version;
  final String title;
  final String? imageUrl;

  String get key => '$setId/$version';

  static final _token = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

  static ChatBadgeChoice? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final setId = raw['setID'];
    final version = raw['version'];
    if (setId is! String || !_token.hasMatch(setId)) return null;
    if (version is! String || !_token.hasMatch(version)) return null;
    final title = raw['title'];
    final image = raw['imageUrlDouble'] ?? raw['imageUrlNormal'];
    return ChatBadgeChoice(
      setId: setId,
      version: version,
      title: title is String && title.isNotEmpty ? title : setId,
      imageUrl: image is String && image.startsWith('https://') ? image : null,
    );
  }

  static List<ChatBadgeChoice> listFrom(Object? raw) => [
    if (raw is List)
      for (final badge in raw) ?tryParse(badge),
  ];
}

enum ChatBadgeScope { channel, global }

class ChatIdentity {
  const ChatIdentity({
    required this.channelBadges,
    required this.globalBadges,
    this.channelSelected,
    this.globalSelected,
    this.flairHidden,
  });

  final List<ChatBadgeChoice> channelBadges;
  final List<ChatBadgeChoice> globalBadges;
  final ChatBadgeChoice? channelSelected;
  final ChatBadgeChoice? globalSelected;
  final bool? flairHidden;

  List<ChatBadgeChoice> badgesFor(ChatBadgeScope scope) =>
      scope == ChatBadgeScope.channel ? channelBadges : globalBadges;

  ChatBadgeChoice? selectedFor(ChatBadgeScope scope) =>
      scope == ChatBadgeScope.channel ? channelSelected : globalSelected;

  static ChatIdentity? fromBody(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;
    final user = data['user'];
    if (user is! Map) return null;
    final channel = data['channel'];
    final self = channel is Map ? channel['self'] : null;
    final settings = user['subscriptionSettings'];
    final hidden = settings is Map ? settings['isBadgeModifierHidden'] : null;
    return ChatIdentity(
      channelBadges: self is Map
          ? ChatBadgeChoice.listFrom(self['availableBadges'])
          : const [],
      globalBadges: ChatBadgeChoice.listFrom(user['availableBadges']),
      channelSelected: self is Map
          ? ChatBadgeChoice.tryParse(self['selectedBadge'])
          : null,
      globalSelected: ChatBadgeChoice.tryParse(user['selectedBadge']),
      flairHidden: hidden is bool ? hidden : null,
    );
  }
}
