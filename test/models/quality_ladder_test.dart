import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/quality_ladder.dart';

String _unavailable(List<Map<String, Object>> media) =>
    base64.encode(utf8.encode(jsonEncode(media)));

String _playlist({String? unavailable}) => [
  '#EXTM3U',
  if (unavailable != null)
    '#EXT-X-SESSION-DATA:DATA-ID="com.amazon.ivs.unavailable-media",'
        'VALUE="$unavailable"',
  '#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",'
      'AUTOSELECT=YES,DEFAULT=YES',
  '#EXT-X-STREAM-INF:BANDWIDTH=8967602,RESOLUTION=1920x1080,'
      'CODECS="avc1.64002A,mp4a.40.2",VIDEO="chunked",FRAME-RATE=60.000',
  'https://example.test/source.m3u8',
  '#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p60",NAME="720p60",AUTOSELECT=YES',
  '#EXT-X-STREAM-INF:BANDWIDTH=3422999,RESOLUTION=1280x720,'
      'CODECS="avc1.4D401F,mp4a.40.2",VIDEO="720p60",FRAME-RATE=60.000',
  'https://example.test/720.m3u8',
].join('\n');

void main() {
  test('reads each rendition\'s bitrate by its name', () {
    final ladder = QualityLadder.parse(_playlist());
    expect(ladder.bitrateOf('1080p60'), 8967602);
    expect(ladder.bitrateOf('1080p60 (source)'), 8967602);
    expect(ladder.bitrateOf('720p60'), 3422999);
    expect(ladder.bitrateOf('480p'), isNull);
    expect(ladder.unavailable, isEmpty);
  });

  test('lists the video renditions Twitch withholds, not sound ones', () {
    final ladder = QualityLadder.parse(
      _playlist(
        unavailable: _unavailable([
          {
            'NAME': '1440p60',
            'BANDWIDTH': 12000000,
            'RESOLUTION': '2560x1440',
            'FILTER_REASONS': ['FR_CODEC_UNSUPPORTED'],
          },
          {
            'NAME': 'audio_only',
            'BANDWIDTH': 160000,
            'RESOLUTION': '',
            'FILTER_REASONS': ['FR_AUDIO_DISALLOWED'],
          },
          {'NAME': '720p60', 'BANDWIDTH': 3422999, 'RESOLUTION': '1280x720'},
        ]),
      ),
    );
    expect(ladder.unavailable.map((q) => q.name), ['1440p60', '720p60']);
    expect(ladder.unavailable.first.bitrate, 12000000);
    expect(
      ladder
          .unavailableBesides(['Auto', '1080p60', '720p60'])
          .map((q) => q.name),
      ['1440p60'],
    );
  });

  test('anything else gives an empty ladder', () {
    for (final text in ['', 'not a playlist', '[{"error":"x"}]']) {
      final ladder = QualityLadder.parse(text);
      expect(ladder.bitrates, isEmpty, reason: text);
      expect(ladder.unavailable, isEmpty, reason: text);
    }
    expect(
      QualityLadder.parse(_playlist(unavailable: 'not base64!')).unavailable,
      isEmpty,
    );
  });
}
