import 'package:flutter/foundation.dart';

@immutable
class LegendaryEmote {
  const LegendaryEmote({
    required this.id,
    required this.token,
    required this.tier,
    required this.isOwned,
  });

  final String id;
  final String token;
  final String tier;
  final bool isOwned;

  static final _id = RegExp(r'^[A-Za-z0-9_]{1,80}$');

  String get imageUrl =>
      'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';

  static LegendaryEmote? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final emote = raw['emote'];
    if (emote is! Map) return null;
    final id = emote['id'];
    final token = emote['token'];
    if (id is! String || token is! String || !_id.hasMatch(id)) return null;
    final tier = raw['tier'];
    return LegendaryEmote(
      id: id,
      token: token,
      tier: tier is String ? tier : '',
      isOwned: raw['isOwned'] == true,
    );
  }
}

@immutable
class LegendaryCollection {
  const LegendaryCollection({
    required this.campaignName,
    this.imageUrl,
    this.emotes = const [],
    this.unopenedChests = 0,
    this.freeChests = 0,
  });

  final String campaignName;
  final String? imageUrl;
  final List<LegendaryEmote> emotes;
  final int unopenedChests;
  final int freeChests;

  int get paidChests => unopenedChests - freeChests;

  Set<String> get ownedIds => {
    for (final emote in emotes)
      if (emote.isOwned) emote.id,
  };

  List<LegendaryEmote> newlyOwnedSince(LegendaryCollection before) {
    final owned = before.ownedIds;
    return [
      for (final emote in emotes)
        if (emote.isOwned && !owned.contains(emote.id)) emote,
    ];
  }

  static const tierOrder = ['LEGENDARY', 'EPIC', 'RARE', 'UNCOMMON', 'COMMON'];

  int get ownedCount => emotes.where((emote) => emote.isOwned).length;

  List<(String, List<LegendaryEmote>)> get byTier {
    final groups = <String, List<LegendaryEmote>>{};
    for (final emote in emotes) {
      groups.putIfAbsent(emote.tier, () => []).add(emote);
    }
    int rank(String tier) {
      final index = tierOrder.indexOf(tier);
      return index < 0 ? tierOrder.length : index;
    }

    final tiers = groups.keys.toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return [for (final tier in tiers) (tier, groups[tier]!)];
  }

  static LegendaryCollection? fromBody(Object? body) {
    final data = body is Map ? body['data'] : null;
    final season = data is Map ? data['legendaryEmoteSeason'] : null;
    if (season is! Map) return null;
    final campaign = season['campaign'];
    final name = campaign is Map ? campaign['name'] : null;
    final image = campaign is Map ? campaign['imageURL'] : null;
    final pool = season['emotePool'];
    final emotes = pool is List
        ? pool.map(LegendaryEmote.tryParse).nonNulls.toList()
        : <LegendaryEmote>[];
    if (emotes.isEmpty) return null;
    final progress = season['userProgress'];
    final inventory = progress is Map ? progress['chestInventory'] : null;
    var unopened = 0;
    var free = 0;
    if (inventory is List) {
      for (final entry in inventory) {
        final count = entry is Map ? entry['unopenedCount'] : null;
        if (count is! num || count <= 0) continue;
        unopened += count.toInt();
        if (entry is Map && entry['chestType'] == 'FREE') free += count.toInt();
      }
    }
    return LegendaryCollection(
      campaignName: name is String ? name : '',
      imageUrl: image is String && image.startsWith('https://') ? image : null,
      emotes: emotes,
      unopenedChests: unopened,
      freeChests: free,
    );
  }
}
