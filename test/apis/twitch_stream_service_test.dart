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

  group('usher parameters', () {
    void stubToken() {
      adapter.onPost(
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
      );
    }

    void expectUsherParams(Map<String, dynamic> params) {
      expect(params['allow_source'], 'true');
      expect(params['fast_bread'], 'true');
      // The user's 2K (1440p HEVC/AV1) support: must never change.
      expect(params['supported_codecs'], 'av1,h265,h264');
      expect(params['type'], 'any');
      expect(params['sig'], 'deadbeef');
      expect(params['token'], '{"token":"abc"}');
      expect(int.tryParse('${params['p']}'), isNotNull);
      // Legacy flags the official app never sends.
      expect(params.containsKey('low_latency'), isFalse);
      expect(params.containsKey('player'), isFalse);
    }

    test('usherQueryParameters keeps 2K codecs and drops legacy flags', () {
      final params = TwitchStreamService.usherQueryParameters(
        signature: 'deadbeef',
        token: '{"token":"abc"}',
        p: 1234,
      );

      expectUsherParams(params);
      expect(params['p'], '1234');
    });

    test('getUsherUrl builds the usher url with the same parameters', () async {
      stubToken();

      final url = await service.getUsherUrl(userLogin: login);
      final uri = Uri.parse(url);

      expect(uri.host, 'usher.ttvnw.net');
      expect(uri.path, '/api/channel/hls/$login.m3u8');
      expectUsherParams(uri.queryParameters);
      expect(url, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(url, contains('token=%7B%22token%22%3A%22abc%22%7D'));
      expect(url, contains('&type=any'));
    });

    test('getStreamVariants requests usher with the same parameters', () async {
      stubToken();
      Map<String, dynamic>? usherParams;
      String? usherUri;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'usher.ttvnw.net') {
              usherParams = Map.of(options.queryParameters);
              usherUri = options.uri.toString();
            }
            handler.next(options);
          },
        ),
      );
      adapter.onGet(
        'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
        (server) => server.reply(200, '#EXTM3U\n'),
      );

      await service.getStreamVariants(userLogin: login);

      expect(usherParams, isNotNull);
      expectUsherParams(usherParams!);
      expect(usherUri, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(usherUri, isNot(contains('low_latency')));
    });
  });
}
