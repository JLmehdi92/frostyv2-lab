class RecommendedChannel {
  const RecommendedChannel({
    required this.userId,
    required this.login,
    required this.displayName,
    this.avatarUrl,
    this.title,
    this.category,
    this.viewers,
  });

  final String userId;
  final String login;
  final String displayName;
  final String? avatarUrl;
  final String? title;
  final String? category;
  final int? viewers;

  bool get isLive => viewers != null;

  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  static RecommendedChannel? fromItem(Object? item) {
    if (item is! Map || item['__typename'] != 'PersonalSectionChannel') {
      return null;
    }
    final user = item['user'];
    if (user is! Map) return null;
    final id = user['id'];
    final login = user['login'];
    if (id is! String || !_numericId.hasMatch(id)) return null;
    if (login is! String || !_login.hasMatch(login)) return null;
    final name = user['displayName'];
    final content = item['content'];
    final stream = content is Map && content['__typename'] == 'Stream'
        ? content
        : null;
    final viewers = stream?['viewersCount'];
    final broadcaster = stream?['broadcaster'];
    final settings = broadcaster is Map ? broadcaster['broadcastSettings'] : null;
    final title = settings is Map ? settings['title'] : null;
    final game = stream?['game'];
    final category = game is Map ? game['displayName'] : null;
    final avatar = user['profileImageURL'];
    final avatarUri = avatar is String ? Uri.tryParse(avatar) : null;
    return RecommendedChannel(
      userId: id,
      login: login.toLowerCase(),
      displayName: name is String && name.isNotEmpty && name.length <= 64
          ? name
          : login,
      avatarUrl:
          avatarUri != null &&
              avatarUri.scheme == 'https' &&
              avatarUri.host.endsWith('.jtvnw.net')
          ? avatar as String
          : null,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : null,
      category: category is String && category.isNotEmpty ? category : null,
      viewers: viewers is int && viewers >= 0 ? viewers : null,
    );
  }
}

enum RecommendationSection {
  recommended('RECOMMENDED_SECTION'),
  similar('SIMILAR_SECTION');

  const RecommendationSection(this.apiValue);

  final String apiValue;
}

enum NotInterestedReason {
  notInterested,
  offensive,
  other;

  String get apiValue => name
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
      .toUpperCase();
}
