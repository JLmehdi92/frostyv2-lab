import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/quality_ladder.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';

/// Normalises a quality name so names saved by any engine compare equal
/// (e.g. the web player's `1080p60 (source)` and IVS's `1080p60`).
String normalizeQualityName(String name) => name
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '_');

/// Twitch's name for the sound-only rendition.
const kAudioOnlyQuality = 'audio_only';

/// How a quality is shown in the menu, in [l]'s language: Twitch's names
/// as they are ("1080p60"), Auto and audio only worded.
String qualityLabel(String name, AppLocalizations l) => switch (name) {
  kAudioOnlyQuality => l.livePlayerAudioOnly,
  'Auto' => l.playerConfigAuto,
  _ => name,
};

String unavailableQualityDetail(
  UnavailableQuality quality,
  AppLocalizations l,
) => switch (quality.bitrate) {
  final bitrate? => l.livePlayerQualityUnavailableBitrate(
    bitrate: formatBitrate(bitrate, l),
  ),
  null => l.livePlayerQualityUnavailable,
};

/// Picks the quality to apply once the stream's qualities are known.
///
/// Audio only is a choice for the moment: a saved one opens the next
/// stream on Auto, unless [keepAudioOnly] (this session's pick, kept across
/// reloads).
///
/// [available] is ordered best first (resolution, then frame rate, then
/// bitrate). Returns null to stay on Auto (adaptive).
String? pickInitialQuality({
  required List<String> available,
  required bool defaultToHighest,
  required String? lastQuality,
  bool keepAudioOnly = false,
}) {
  if (available.isEmpty) return null;
  if (defaultToHighest) return available.first;
  if (lastQuality == null ||
      lastQuality == 'Auto' ||
      (!keepAudioOnly &&
          normalizeQualityName(lastQuality) == kAudioOnlyQuality)) {
    return null;
  }
  final wanted = normalizeQualityName(lastQuality);
  for (final quality in available) {
    if (normalizeQualityName(quality) == wanted) return quality;
  }
  return null;
}

/// Whether going from quality [from] to [to] lowers the resolution, or the
/// frame rate at the same resolution (audio only is the lowest). False when
/// either name is not a rendition (`source`, `chunked`...): unknown is never
/// taken for a down-switch.
bool isQualityDownSwitch(String from, String to) {
  final a = _qualityRank(from);
  final b = _qualityRank(to);
  if (a == null || b == null) return false;
  return b.$1 < a.$1 || (b.$1 == a.$1 && b.$2 < a.$2);
}

(int, int)? _qualityRank(String name) {
  if (normalizeQualityName(name) == kAudioOnlyQuality) return (0, 0);
  final match = RegExp(r'(\d+)p(\d+)?').firstMatch(name);
  if (match == null) return null;
  return (int.parse(match.group(1)!), int.parse(match.group(2) ?? '30'));
}

const kDataSaverMaxHeight = 480;

String? dataSaverQuality(List<String> available) {
  for (final quality in available) {
    final rank = _qualityRank(quality);
    if (rank != null && rank.$1 > 0 && rank.$1 <= kDataSaverMaxHeight) {
      return quality;
    }
  }
  return null;
}
