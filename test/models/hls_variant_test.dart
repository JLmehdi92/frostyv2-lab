import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hls_variant.dart';

void main() {
  // A trimmed Twitch master playlist (two qualities).
  const masterPlaylist = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,VIDEO="chunked"
https://video-edge-1.ttvnw.net/chunked/index-live.m3u8
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p60",NAME="720p60",AUTOSELECT=YES,DEFAULT=NO
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,VIDEO="720p60"
https://video-edge-1.ttvnw.net/720p60/index-live.m3u8
''';

  test('parses each quality name and its media url', () {
    final variants = HlsVariant.parseMasterPlaylist(masterPlaylist);

    expect(variants.length, 2);
    expect(variants[0].name, '1080p60 (source)');
    expect(
      variants[0].url,
      'https://video-edge-1.ttvnw.net/chunked/index-live.m3u8',
    );
    expect(variants[1].name, '720p60');
    expect(
      variants[1].url,
      'https://video-edge-1.ttvnw.net/720p60/index-live.m3u8',
    );
  });

  test('returns empty list for an empty or invalid playlist', () {
    expect(HlsVariant.parseMasterPlaylist(''), isEmpty);
    expect(HlsVariant.parseMasterPlaylist('not a playlist'), isEmpty);
  });
}
