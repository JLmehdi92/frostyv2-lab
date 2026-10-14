/// Normalises a quality name so names saved by any engine compare equal
/// (e.g. the web player's `1080p60 (source)` and IVS's `1080p60`).
String normalizeQualityName(String name) => name
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '_');

/// Twitch's name for the sound-only rendition.
const kAudioOnlyQuality = 'audio_only';

/// How a quality is shown in the menu.
String qualityLabel(String name) =>
    name == kAudioOnlyQuality ? 'Audio only' : name;

/// Picks the quality to apply once the stream's qualities are known.
///
/// Audio only is a choice for the moment: a saved one opens the next
/// stream on Auto.
///
/// [available] is ordered best first (resolution, then frame rate, then
/// bitrate). Returns null to stay on Auto (adaptive).
String? pickInitialQuality({
  required List<String> available,
  required bool defaultToHighest,
  required String? lastQuality,
}) {
  if (available.isEmpty) return null;
  if (defaultToHighest) return available.first;
  if (lastQuality == null ||
      lastQuality == 'Auto' ||
      normalizeQualityName(lastQuality) == kAudioOnlyQuality) {
    return null;
  }
  final wanted = normalizeQualityName(lastQuality);
  for (final quality in available) {
    if (normalizeQualityName(quality) == wanted) return quality;
  }
  return null;
}
