import 'dart:convert';

import 'package:onset/screens/channel/video/quality_selection.dart';

class UnavailableQuality {
  const UnavailableQuality({required this.name, this.bitrate});

  final String name;
  final int? bitrate;
}

class QualityLadder {
  const QualityLadder({this.bitrates = const {}, this.unavailable = const []});

  static const empty = QualityLadder();

  static const _unavailableMediaId = 'com.amazon.ivs.unavailable-media';

  final Map<String, int> bitrates;
  final List<UnavailableQuality> unavailable;

  int? bitrateOf(String quality) => bitrates[normalizeQualityName(quality)];

  List<UnavailableQuality> unavailableBesides(Iterable<String> available) {
    final offered = available.map(normalizeQualityName).toSet();
    return [
      for (final quality in unavailable)
        if (!offered.contains(normalizeQualityName(quality.name))) quality,
    ];
  }

  static QualityLadder parse(String playlist) {
    final lines = const LineSplitter()
        .convert(playlist)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') return empty;

    final bitrates = <String, int>{};
    final unavailable = <UnavailableQuality>[];
    String? pendingName;
    for (final line in lines) {
      if (line.startsWith('#EXT-X-MEDIA:')) {
        pendingName = _attribute(line, 'NAME');
      } else if (line.startsWith('#EXT-X-STREAM-INF:') && pendingName != null) {
        final bandwidth = int.tryParse(_attribute(line, 'BANDWIDTH') ?? '');
        if (bandwidth != null && bandwidth > 0) {
          bitrates[normalizeQualityName(pendingName)] = bandwidth;
        }
        pendingName = null;
      } else if (line.startsWith('#EXT-X-SESSION-DATA:') &&
          _attribute(line, 'DATA-ID') == _unavailableMediaId) {
        unavailable.addAll(_unavailableMedia(_attribute(line, 'VALUE')));
      }
    }
    return QualityLadder(bitrates: bitrates, unavailable: unavailable);
  }

  static String? _attribute(String line, String key) {
    final quoted = RegExp('(?:[:,])$key="([^"]*)"').firstMatch(line);
    if (quoted != null) return quoted.group(1);
    return RegExp('(?:[:,])$key=([^,]*)').firstMatch(line)?.group(1);
  }

  static List<UnavailableQuality> _unavailableMedia(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(value)));
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry case {
            'NAME': final String name,
            'RESOLUTION': final String resolution,
          } when name.isNotEmpty && resolution.isNotEmpty)
            UnavailableQuality(
              name: name,
              bitrate: switch (entry['BANDWIDTH']) {
                final int bandwidth when bandwidth > 0 => bandwidth,
                _ => null,
              },
            ),
      ];
    } on FormatException {
      return const [];
    }
  }
}
