/// One tier of a cheermote: the image and color for cheers of at least
/// [minBits].
class CheermoteTier {
  const CheermoteTier({
    required this.minBits,
    required this.color,
    required Map<String, String> urls,
  }) : _urls = urls;

  final int minBits;

  /// ARGB.
  final int color;

  /// `dark/animated`, `light/static`… → URL at scale 2.
  final Map<String, String> _urls;

  /// The image for the chat's [dark] or light theme, moving or not; the
  /// closest one Twitch gave when that one is missing.
  String url({required bool dark, required bool animated}) {
    final theme = dark ? 'dark' : 'light';
    final kind = animated ? 'animated' : 'static';
    return _urls['$theme/$kind'] ??
        _urls['$theme/${animated ? 'static' : 'animated'}'] ??
        _urls.values.first;
  }
}

/// A cheer found in a message word.
typedef Cheer = ({String prefix, int amount, CheermoteTier tier});

/// A prefix (letters and digits, ending in a letter: `4Head`) then the
/// amount.
final _cheerWord = RegExp(r'^([a-zA-Z0-9]*[a-zA-Z])(\d{1,7})$');
final _hexColor = RegExp(r'^#([0-9a-fA-F]{6})$');

/// The cheermotes usable in a channel (Helix `GET /bits/cheermotes`).
class Cheermotes {
  const Cheermotes._(this._byPrefix);

  static const empty = Cheermotes._({});

  /// Lower-cased prefix → tiers, highest first.
  final Map<String, List<CheermoteTier>> _byPrefix;

  bool get isEmpty => _byPrefix.isEmpty;

  /// Reads Helix's answer, skipping what cannot be read; images are only
  /// taken from Twitch's hosts.
  factory Cheermotes.fromHelix(Map<String, dynamic> json) {
    final data = json['data'];
    final byPrefix = <String, List<CheermoteTier>>{};
    if (data is! List) return Cheermotes.empty;
    for (final entry in data) {
      if (entry is! Map) continue;
      final prefix = entry['prefix'];
      final tiers = entry['tiers'];
      if (prefix is! String ||
          !RegExp(r'^[a-zA-Z0-9]{0,39}[a-zA-Z]$').hasMatch(prefix) ||
          tiers is! List) {
        continue;
      }
      final read = [for (final tier in tiers) ?_tier(tier)]
        ..sort((a, b) => b.minBits.compareTo(a.minBits));
      if (read.isNotEmpty) byPrefix[prefix.toLowerCase()] = read;
    }
    return Cheermotes._(byPrefix);
  }

  static CheermoteTier? _tier(Object? tier) {
    if (tier is! Map) return null;
    final minBits = tier['min_bits'];
    final color = _hexColor.firstMatch('${tier['color']}');
    final images = tier['images'];
    if (minBits is! int || minBits < 1 || color == null || images is! Map) {
      return null;
    }
    final urls = <String, String>{};
    for (final theme in ['dark', 'light']) {
      final byTheme = images[theme];
      if (byTheme is! Map) continue;
      for (final kind in ['animated', 'static']) {
        final scales = byTheme[kind];
        final url = scales is Map ? (scales['2'] ?? scales['1']) : null;
        if (url is String && _isTwitchImage(url)) urls['$theme/$kind'] = url;
      }
    }
    if (urls.isEmpty) return null;
    return CheermoteTier(
      minBits: minBits,
      color: 0xFF000000 | int.parse(color[1]!, radix: 16),
      urls: urls,
    );
  }

  static bool _isTwitchImage(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (uri.host == 'd3aqoihi2n8ty8.cloudfront.net' ||
            uri.host.endsWith('.jtvnw.net') ||
            uri.host.endsWith('.twitch.tv'));
  }

  /// The cheer [word] makes (`Cheer100`), or null when it makes none.
  Cheer? match(String word) {
    final found = _cheerWord.firstMatch(word);
    if (found == null) return null;
    final tiers = _byPrefix[found[1]!.toLowerCase()];
    final amount = int.parse(found[2]!);
    if (tiers == null || amount < 1) return null;
    for (final tier in tiers) {
      if (amount >= tier.minBits) {
        return (prefix: found[1]!, amount: amount, tier: tier);
      }
    }
    return null;
  }
}
