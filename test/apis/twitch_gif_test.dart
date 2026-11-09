import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/giphy_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/gif_picker.dart';

import '../fixtures/gif_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
  });

  Map<String, dynamic> sent() {
    final data = requests.single.data;
    return Map<String, dynamic>.from(
      data is String ? jsonDecode(data) as Map : data as Map,
    );
  }

  void replyGql(Object? body) => adapter.onPost(
    _gql,
    (server) => server.reply(200, body),
    data: Matchers.any,
  );

  final gif = GiphyGif.fromJson(giphyGif('abc123'))!;

  group('GIF picker config', () {
    test('reads the config with the web token', () async {
      replyGql(gifPickerConfigResponse());
      final config = await TwitchViewerActionsService(
        dio,
      ).gifPickerConfig(channelId: '1000', authToken: 'tok');
      expect(config!.canSend, isTrue);
      expect(config.rating, 'pg-13');
      expect(sent()['operationName'], 'GetGifPickerConfig');
      expect(sent()['variables'], {'channelID': '1000'});
    });

    test('a viewer outside the allowlist cannot send', () async {
      replyGql(gifPickerConfigResponse(allowlisted: false));
      final config = await TwitchViewerActionsService(
        dio,
      ).gifPickerConfig(channelId: '1000', authToken: 'tok');
      expect(config!.enabled, isTrue);
      expect(config.canSend, isFalse);
    });

    test('an odd key is never used', () async {
      replyGql(gifPickerConfigResponse(apiKey: 'bad key/../'));
      final config = await TwitchViewerActionsService(
        dio,
      ).gifPickerConfig(channelId: '1000', authToken: 'tok');
      expect(config!.canSend, isFalse);
    });

    test('an error, a bad id or no token reads nothing', () async {
      replyGql({
        'errors': [
          {'message': 'unauthenticated'},
        ],
        'data': {'gifPickerConfig': null},
      });
      final service = TwitchViewerActionsService(dio);
      expect(
        await service.gifPickerConfig(channelId: '1000', authToken: 'tok'),
        isNull,
      );
      requests.clear();
      expect(
        await service.gifPickerConfig(channelId: 'x', authToken: 'tok'),
        isNull,
      );
      expect(
        await service.gifPickerConfig(channelId: '1000', authToken: ''),
        isNull,
      );
      expect(requests, isEmpty);
    });
  });

  group('sending a GIF', () {
    test('sends the GIPHY id, url and search term', () async {
      replyGql(sendGifResponse());
      final result = await TwitchViewerActionsService(dio).sendGif(
        channelId: '1000',
        gif: gif,
        searchTerm: ' wave ',
        authToken: 'tok',
      );
      expect(result.status, GifSendStatus.sent);
      expect(sent()['operationName'], 'sendGifMessage');
      expect(sent()['variables'], {
        'input': {
          'channelID': '1000',
          'gifID': 'abc123',
          'gifURL': 'https://media1.giphy.com/media/abc123/giphy.gif',
          'searchTerm': 'wave',
        },
      });
    });

    test('a cooldown gives the seconds to wait', () async {
      replyGql(
        sendGifResponse(
          error: 'RATE_LIMITED',
          secondsUntilCanSend: 11.2,
          messageId: null,
        ),
      );
      final result = await TwitchViewerActionsService(
        dio,
      ).sendGif(channelId: '1000', gif: gif, searchTerm: '', authToken: 'tok');
      expect(result.status, GifSendStatus.cooldown);
      expect(result.secondsUntilCanSend, 12);
      expect(
        (sent()['variables'] as Map)['input'],
        isNot(contains('searchTerm')),
      );
    });

    test('an error without a wait is a refusal', () async {
      replyGql(sendGifResponse(error: 'BANNED', messageId: null));
      final result = await TwitchViewerActionsService(
        dio,
      ).sendGif(channelId: '1000', gif: gif, searchTerm: '', authToken: 'tok');
      expect(result.status, GifSendStatus.refused);
    });

    test('an anti-bot refusal is told apart', () async {
      replyGql({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });
      final result = await TwitchViewerActionsService(
        dio,
      ).sendGif(channelId: '1000', gif: gif, searchTerm: '', authToken: 'tok');
      expect(result.status, GifSendStatus.integrityRefused);
    });
  });

  group('GIPHY', () {
    const config = GifPickerConfig(
      enabled: true,
      allowlisted: true,
      apiKey: 'abcDEF123456',
      rating: 'pg',
    );

    test('searches with the key and rating Twitch gave', () async {
      adapter.onGet(
        'https://api.giphy.com/v1/gifs/search',
        (server) => server.reply(
          200,
          giphyResponse([
            giphyGif('a1'),
            {'id': 'bad', 'images': <String, Object?>{}},
          ]),
        ),
        queryParameters: {
          'api_key': 'abcDEF123456',
          'limit': 24,
          'offset': 0,
          'rating': 'pg',
          'q': 'wave',
        },
      );
      final gifs = await GiphyService(
        dio,
      ).search(config: config, query: ' wave ');
      expect(gifs!.map((gif) => gif.id), ['a1']);
    });

    test('an empty search shows trending GIFs', () async {
      adapter.onGet(
        'https://api.giphy.com/v1/gifs/trending',
        (server) => server.reply(200, giphyResponse([giphyGif('t1')])),
        queryParameters: {
          'api_key': 'abcDEF123456',
          'limit': 24,
          'offset': 0,
          'rating': 'pg',
        },
      );
      final gifs = await GiphyService(dio).search(config: config, query: '');
      expect(gifs!.single.id, 't1');
    });

    test('a failure gives null and no key means no request', () async {
      adapter.onGet(
        'https://api.giphy.com/v1/gifs/trending',
        (server) => server.reply(500, null),
        queryParameters: {
          'api_key': 'abcDEF123456',
          'limit': 24,
          'offset': 0,
          'rating': 'pg',
        },
      );
      expect(await GiphyService(dio).trending(config: config), isNull);
      requests.clear();
      expect(
        await GiphyService(dio).trending(
          config: const GifPickerConfig(
            enabled: true,
            allowlisted: false,
            apiKey: 'abcDEF123456',
            rating: 'pg',
          ),
        ),
        isNull,
      );
      expect(requests, isEmpty);
    });

    test('a failure is logged without the key', () {
      final description = GiphyService.describeFailure(
        DioException(
          requestOptions: RequestOptions(
            path: 'https://api.giphy.com/v1/gifs/search?api_key=abcDEF123456',
          ),
          response: Response(requestOptions: RequestOptions(), statusCode: 429),
        ),
      );
      expect(description, 'HTTP 429');
      expect(
        GiphyService.describeFailure(Exception('api_key=abcDEF123456')),
        isNot(contains('abcDEF123456')),
      );
    });

    test('only https GIPHY images are kept', () {
      final gif = giphyGif('x1');
      (gif['images']! as Map)['original'] = {
        'url': 'https://evil.example/x.gif',
      };
      expect(GiphyGif.fromJson(gif), isNull);
    });
  });
}
