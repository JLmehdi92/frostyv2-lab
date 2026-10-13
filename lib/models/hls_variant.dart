import 'dart:convert';

/// A single selectable quality from a Twitch HLS master playlist.
class HlsVariant {
  /// Human-readable name, e.g. '1080p60 (source)' or '720p60'.
  final String name;

  /// URL of this variant's media playlist.
  final String url;

  const HlsVariant({required this.name, required this.url});

  /// Parses a Twitch HLS master playlist into an ordered list of variants.
  ///
  /// Pairs each `#EXT-X-MEDIA:...,NAME="..."` with the URL line that follows
  /// its matching `#EXT-X-STREAM-INF`. Returns an empty list when the input is
  /// not a valid master playlist.
  static List<HlsVariant> parseMasterPlaylist(String playlist) {
    final lines = const LineSplitter()
        .convert(playlist)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty || lines.first != '#EXTM3U') return const [];

    final variants = <HlsVariant>[];
    String? pendingName;

    for (final line in lines) {
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final match = RegExp(r'NAME="([^"]*)"').firstMatch(line);
        pendingName = match?.group(1);
      } else if (!line.startsWith('#') && pendingName != null) {
        variants.add(HlsVariant(name: pendingName, url: line));
        pendingName = null;
      }
    }

    return variants;
  }
}
