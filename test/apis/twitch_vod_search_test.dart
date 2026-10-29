import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_vod_service.dart';

import '../fixtures/vod_responses.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchVodService service;
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
    service = TwitchVodService(dio);
  });

  void reply(Object body) =>
      adapter.onPost(_gql, (s) => s.reply(200, body), data: Matchers.any);

  Map<String, dynamic> lastBody() =>
      (requests.last.data as Map).cast<String, dynamic>();

  Map<String, Object?> page(
    List<Object?> items, {
    String cursor = 'MjU=',
    bool hasNextPage = true,
  }) => {
    'data': {
      'searchFor': {
        'videos': {
          'cursor': cursor,
          'items': items,
          'pageInfo': {'hasNextPage': hasNextPage},
        },
      },
    },
  };

  group('searchVideos', () {
    test('asks the VOD index for 25 videos, anonymously', () async {
      reply(page([vodNodeArchive]));

      await service.searchVideos('speedrun');

      final body = lastBody();
      expect(requests.single.uri.toString(), _gql);
      expect(body['query'], contains('searchFor('));
      expect(body['query'], contains('videos {'));
      final variables = (body['variables'] as Map).cast<String, dynamic>();
      expect(variables['query'], 'speedrun');
      expect(variables['target'], {'index': 'VOD', 'limit': 25});
      expect(requests.single.headers['Client-ID'], isNotNull);
      expect(
        requests.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
        reason: 'a search needs no token',
      );
    });

    test('parses the videos with their channel, and the next cursor', () async {
      reply(page([vodNodeArchive, vodNodeHighlightNoGame]));

      final result = await service.searchVideos('speedrun');

      expect(result.items.map((v) => v.id), ['1000000001', '1000000002']);
      expect(result.items.first.ownerLogin, 'streamer');
      expect(result.items.last.isRestricted, isTrue);
      expect(result.cursor, 'MjU=');
      expect(result.hasMore, isTrue);
    });

    test('sends the cursor for the next page', () async {
      reply(page([vodNodeArchive], hasNextPage: false, cursor: ''));

      final result = await service.searchVideos('speedrun', cursor: 'MjU=');

      final variables = (lastBody()['variables'] as Map)
          .cast<String, dynamic>();
      expect(variables['target'], {
        'index': 'VOD',
        'limit': 25,
        'cursor': 'MjU=',
      });
      expect(result.hasMore, isFalse);
      expect(result.cursor, isNull, reason: 'an empty cursor ends paging');
    });

    test('no match is an empty page, not an error', () async {
      reply(page(const [], cursor: '', hasNextPage: false));

      final result = await service.searchVideos('nothing');

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('skips unreadable videos but keeps the others', () async {
      reply(
        page([
          {'id': 'broken'},
          null,
          vodNodeArchive,
        ]),
      );

      final result = await service.searchVideos('speedrun');

      expect(result.items.map((v) => v.id), ['1000000001']);
    });

    test('only unreadable videos is an error (Twitch changed)', () async {
      reply(
        page([
          {'id': 'broken'},
        ]),
      );

      expect(
        () => service.searchVideos('speedrun'),
        throwsA(isA<VodApiException>()),
      );
    });

    test('an answer without searchFor is an error', () async {
      reply({
        'data': {'searchFor': null},
      });

      expect(
        () => service.searchVideos('speedrun'),
        throwsA(isA<VodApiException>()),
      );
    });

    test('a GQL error is reported (integrity flagged)', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      await expectLater(
        service.searchVideos('speedrun'),
        throwsA(
          isA<VodApiException>().having(
            (e) => e.isIntegrity,
            'isIntegrity',
            isTrue,
          ),
        ),
      );
    });

    test('a blank query is refused without a request', () async {
      expect(() => service.searchVideos('   '), throwsArgumentError);
      expect(requests, isEmpty);
    });
  });
}
