/// A category (game) the viewer follows on Twitch, as Twitch's own
/// `FollowedGamesQuery` gives it.
class FollowedCategory {
  final String id;
  final String name;
  final String displayName;

  /// The category's twitch.tv slug, when Twitch gave one that looks right.
  final String? slug;

  /// Box art at 285x380.
  final String boxArtUrl;

  /// People watching the category's live streams right now.
  final int viewers;

  const FollowedCategory({
    required this.id,
    required this.name,
    this.displayName = '',
    this.slug,
    this.boxArtUrl = '',
    this.viewers = 0,
  });

  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _slug = RegExp(r'^[a-z0-9-]{1,100}$');
  static const _imageHost = 'https://static-cdn.jtvnw.net/';

  /// The name to show.
  String get title => displayName.isNotEmpty ? displayName : name;

  /// The category's page on twitch.tv, where the viewer can follow or
  /// unfollow it themselves.
  Uri get twitchUrl => twitchUrlFor(slug: slug, name: name);

  /// The twitch.tv page of a category: by its slug, else by its name (which
  /// twitch.tv redirects). Always on twitch.tv.
  static Uri twitchUrlFor({required String? slug, required String name}) => Uri(
    scheme: 'https',
    host: 'www.twitch.tv',
    pathSegments: slug != null && _slug.hasMatch(slug)
        ? ['directory', 'category', slug]
        : ['directory', 'game', name],
  );

  /// A slug Twitch gave, kept only when it is a plain slug.
  static String? validSlug(Object? slug) =>
      slug is String && _slug.hasMatch(slug) ? slug : null;

  /// A `Game` node, or null when it lacks an id or a name.
  static FollowedCategory? tryParse(Object? node) {
    if (node is! Map) return null;
    final id = node['id'];
    final name = node['name'];
    if (id is! String || !_numericId.hasMatch(id)) return null;
    if (name is! String || name.isEmpty) return null;
    final displayName = node['displayName'];
    final boxArt = node['boxArtURL'];
    final viewers = node['viewersCount'];
    return FollowedCategory(
      id: id,
      name: name,
      displayName: displayName is String ? displayName : '',
      slug: validSlug(node['slug']),
      // Only Twitch's image host: the URL is loaded as is.
      boxArtUrl: boxArt is String && boxArt.startsWith(_imageHost)
          ? boxArt
          : '',
      viewers: viewers is int && viewers > 0 ? viewers : 0,
    );
  }
}
