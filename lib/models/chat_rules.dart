import 'package:frosty/models/community_highlights.dart';

const _imageHosts = {'static-cdn.jtvnw.net'};

/// A channel's chat rules, as Twitch's `ChatRules` query answers them
/// (`user { chatSettings { rules } }`), with what the rules sheet shows
/// above them: the channel's name and picture.
class ChatRules {
  const ChatRules({
    required this.channelId,
    required this.channelName,
    required this.rules,
    this.iconUrl,
  });

  /// The most rules kept, and the longest rule, so a forged answer cannot
  /// flood the sheet.
  static const maxRules = 50;

  /// Matches `chString`'s default cut.
  static const maxRuleLength = 500;

  final String channelId;
  final String channelName;

  /// The channel's picture on Twitch's image host, or null.
  final String? iconUrl;

  /// The rules with text, in Twitch's order. Blank ones are dropped: Twitch
  /// decides whether to show the sheet on the non-blank ones.
  final List<String> rules;

  /// Whether there is a rule to show (Twitch's `willShowRules`).
  bool get hasRules => rules.isNotEmpty;

  /// The rules of the GQL [user] node, or null without a user or an id.
  static ChatRules? fromGql(Object? user) {
    final map = chMap(user);
    final id = chString(map?['id'], max: 32);
    if (map == null || id == null) return null;
    final settings = chMap(map['chatSettings']);
    return ChatRules(
      channelId: id,
      channelName: chString(map['displayName'], max: 64) ?? '',
      iconUrl: _image(map['profileImageURL']),
      rules: [
        for (final rule in chList(settings?['rules'], max: 200)) ?_rule(rule),
      ].take(maxRules).toList(),
    );
  }

  /// [value] as a rule with text (at most [maxRuleLength] units), or null.
  static String? _rule(Object? value) {
    final text = chString(value)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _image(Object? value) {
    final url = chString(value, max: 400);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !_imageHosts.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return null;
    }
    return uri.toString();
  }
}
