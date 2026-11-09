const _twitchEmotePrefix = 'https://static-cdn.jtvnw.net/emoticons/v2/';
final _twitchEmoteId = RegExp(
  r'^(emotesv2_[0-9a-f]{32}|[0-9]{1,20})(_[A-Z]{2})?$',
);
const emoteModifierCodes = {'BW', 'HF', 'SG', 'SQ', 'TK'};

String? twitchEmoteIdOf(String url) {
  if (!url.startsWith(_twitchEmotePrefix)) return null;
  final id = url.substring(_twitchEmotePrefix.length).split('/').first;
  return _twitchEmoteId.hasMatch(id) ? id : null;
}

String? emoteModifierOf(String url) {
  final id = twitchEmoteIdOf(url);
  final suffix = id == null ? null : _twitchEmoteId.firstMatch(id)?.group(2);
  if (suffix == null) return null;
  final code = suffix.substring(1);
  return emoteModifierCodes.contains(code) ? code : null;
}

int? bitsThresholdFrom(Object? body) {
  final data = body is Map ? body['data'] : null;
  final emote = data is Map ? data['emote'] : null;
  final tier = emote is Map ? emote['bitsBadgeTierSummary'] : null;
  final threshold = tier is Map ? tier['threshold'] : null;
  return threshold is int && threshold > 0 ? threshold : null;
}
