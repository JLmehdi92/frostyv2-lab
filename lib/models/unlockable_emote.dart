import 'package:flutter/foundation.dart';

@immutable
class UnlockableEmote {
  const UnlockableEmote({required this.id, required this.token});

  final String id;
  final String token;

  static const modifiers = ['BW', 'HF', 'SG', 'SQ', 'TK'];

  static final _id = RegExp(r'^[A-Za-z0-9_]{1,80}$');

  String get imageUrl =>
      'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';

  String modifiedId(String modifier) => '${id}_$modifier';

  String modifiedImageUrl(String modifier) =>
      'https://static-cdn.jtvnw.net/emoticons/v2/${modifiedId(modifier)}'
      '/default/dark/2.0';

  static List<UnlockableEmote>? listFrom(Object? body) {
    final data = body is Map ? body['data'] : null;
    final user = data is Map ? data['user'] : null;
    if (user is! Map) return null;
    final products = user['subscriptionProducts'];
    if (products is! List) return const [];
    final emotes = <UnlockableEmote>[];
    final seen = <String>{};
    for (final product in products) {
      if (product is! Map || product['tier'] != '1000') continue;
      final raw = product['emotes'];
      if (raw is! List) continue;
      for (final emote in raw) {
        if (emote is! Map) continue;
        final id = emote['id'];
        final token = emote['token'];
        if (id is String &&
            token is String &&
            _id.hasMatch(id) &&
            seen.add(id)) {
          emotes.add(UnlockableEmote(id: id, token: token));
        }
      }
    }
    return emotes;
  }
}
