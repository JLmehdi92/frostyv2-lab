import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchStreamService service;

  const login = 'somestreamer';

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    service = TwitchStreamService(dio);
  });

  test('requests a playback access token then resolves usher variants', () async {
    adapter
      ..onPost(
        'https://gql.twitch.tv/gql',
        (server) => server.reply(200, {
          'data': {
            'streamPlaybackAccessToken': {
              'value': '{"token":"abc"}',
              'signature': 'deadbeef',
            },
          },
        }),
        data: Matchers.any,
      )
      ..onGet(
        'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
        (server) => server.reply(200, '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,VIDEO="chunked"
https://video-edge-1.ttvnw.net/chunked/index-live.m3u8
'''),
      );

    final variants = await service.getStreamVariants(userLogin: login);

    expect(variants, hasLength(1));
    expect(variants.first.name, '1080p60 (source)');
    expect(
      variants.first.url,
      'https://video-edge-1.ttvnw.net/chunked/index-live.m3u8',
    );
  });

  test('throws when no access token is returned (offline channel)', () async {
    adapter.onPost(
      'https://gql.twitch.tv/gql',
      (server) => server.reply(200, {
        'data': {'streamPlaybackAccessToken': null},
      }),
      data: Matchers.any,
    );

    expect(
      () => service.getStreamVariants(userLogin: login),
      throwsA(isA<ApiException>()),
    );
  });
}
