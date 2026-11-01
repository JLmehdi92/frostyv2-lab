import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/constants.dart';

import '../fixtures/directory_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchDirectoryService service;
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
    service = TwitchDirectoryService(dio);
  });

  void reply(Object body) => adapter.onPost(
    _gql,
    (s) => s.reply(200, body is String ? jsonDecode(body) : body),
    data: Matchers.any,
  );

  Map<dynamic, dynamic> sent() => requests.single.data as Map;

  group('category streams', () {
    test('the captured answer, anonymously, in the asked order', () async {
      reply(gqlDirectoryCategoryRecent);

      final page = await service.getCategoryStreams(
        gameId: '509658',
        sort: StreamSort.recent,
        language: 'fr',
      );

      expect(page.pagination, isEmpty);
      expect(page.data, hasLength(2));
      final first = page.data.first;
      expect(first.userId, '900000101');
      expect(first.userLogin, 'streamer_1');
      expect(first.userName, 'Streamer_1');
      expect(first.gameId, '509658');
      expect(first.gameName, 'Just Chatting');
      expect(first.viewerCount, 0);
      expect(first.startedAt, '2026-10-13T23:33:15.000Z');
      expect(first.language, 'en');
      expect(first.tags, contains('chattingwithviewers'));
      expect(
        first.thumbnailUrl,
        'https://static-cdn.jtvnw.net/previews-ttv/'
        'live_user_streamer_1-{width}x{height}.jpg',
      );

      final request = requests.single;
      expect(request.headers['Client-ID'], kTwitchWebClientId);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(sent()['operationName'], 'DirectoryStreams');
      expect(sent()['variables'], {
        'id': '509658',
        'first': 100,
        'options': {
          'sort': 'RECENT',
          'broadcasterLanguages': ['FR'],
        },
      });
    });

    test('every language and "other" send no language', () async {
      reply(gqlDirectoryCategoryRecent);
      await service.getCategoryStreams(
        gameId: '1',
        sort: StreamSort.viewersLow,
        language: 'other',
      );
      expect((sent()['variables'] as Map)['options'], {
        'sort': 'VIEWER_COUNT_ASC',
      });
    });

    test('an unknown category, and a refused one', () async {
      reply({
        'data': {'game': null},
      });
      await expectLater(
        service.getCategoryStreams(gameId: '1', sort: StreamSort.recent),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.categoryNotFound,
          ),
        ),
      );

      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
        'data': {'game': null},
      });
      await expectLater(
        service.getCategoryStreams(gameId: '1', sort: StreamSort.recent),
        throwsA(
          isA<DirectoryApiException>().having(
            (e) => e.message,
            'message',
            contains('integrity'),
          ),
        ),
      );
    });

    test('streams nulled by an error throw instead of reading empty', () {
      reply({
        'errors': [
          {'message': 'boom'},
        ],
        'data': {
          'game': {'id': '1', 'streams': null},
        },
      });
      expect(
        service.getCategoryStreams(gameId: '1', sort: StreamSort.recent),
        throwsA(isA<DirectoryApiException>()),
      );
    });

    test('a bad id never reaches the network', () {
      expect(
        () => service.getCategoryStreams(
          gameId: '1 OR 1',
          sort: StreamSort.recent,
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  group('tag streams', () {
    test('the captured answer, with the tag and language', () async {
      reply(gqlDirectoryTagChill);

      final page = await service.getTagStreams(
        tag: 'Chill',
        sort: StreamSort.viewersHigh,
        language: 'en',
      );

      expect(page.data, hasLength(2));
      expect(page.data.every((s) => s.language == 'en'), isTrue);
      expect(page.data.first.viewerCount, greaterThan(0));
      expect(sent()['operationName'], 'TagStreams');
      expect(sent()['variables'], {
        'first': 30,
        'options': {
          'sort': 'VIEWER_COUNT',
          'broadcasterLanguages': ['EN'],
          'freeformTags': ['Chill'],
        },
      });
    });

    test('tags are letters and digits only', () {
      for (final tag in ['', 'two words', 'a"b', 'x' * 26]) {
        expect(
          () => service.getTagStreams(tag: tag, sort: StreamSort.recent),
          throwsArgumentError,
          reason: tag,
        );
      }
      expect(TwitchDirectoryService.tagPattern.hasMatch('Français'), isTrue);
      expect(TwitchDirectoryService.tagPattern.hasMatch('日本語'), isTrue);
      expect(requests, isEmpty);
    });
  });

  group('streamFromGql', () {
    Map<String, Object?> node({
      Object? type = 'live',
      Object? id = '42',
      Object? login = 'someone',
      Object? createdAt = '2026-10-13T20:00:00Z',
    }) => {
      'type': type,
      'createdAt': createdAt,
      'broadcaster': {'id': id, 'login': login},
    };

    test('a bare live stream reads with blanks', () {
      final stream = TwitchDirectoryService.streamFromGql(node())!;
      expect(stream.userName, 'someone');
      expect(stream.gameId, '');
      expect(stream.gameName, '');
      expect(stream.title, '');
      expect(stream.tags, isEmpty);
      expect(stream.language, '');
    });

    test('reruns, odd ids and logins, and missing dates are skipped', () {
      for (final bad in [
        node(type: 'rerun'),
        node(id: 'x'),
        node(id: 42),
        node(login: 'a/b'),
        node(login: '../x'),
        node(createdAt: null),
        null,
        'x',
      ]) {
        expect(TwitchDirectoryService.streamFromGql(bad), isNull);
      }
    });

    test('hostile values are cut or dropped', () {
      final stream = TwitchDirectoryService.streamFromGql({
        ...node(),
        'title': 't' * 1000,
        'viewersCount': -5,
        'language': 'zz-hack',
        'game': {'id': '1 OR 1', 'name': 'G'},
        'freeformTags': [
          for (var i = 0; i < 20; i++) {'name': 'tag$i'},
          {'name': 5},
        ],
      })!;
      expect(stream.title, hasLength(300));
      expect(stream.viewerCount, 0);
      expect(stream.language, '');
      expect(stream.gameId, '');
      expect(stream.gameName, 'G');
      expect(stream.tags, hasLength(10));
    });
  });

  group('a changed or refused GQL', () {
    test('errors without data name the error', () async {
      reply({
        'errors': [
          {'message': 'PersistedQueryNotFound'},
        ],
      });
      await expectLater(
        service.getCategoryStreams(gameId: '1', sort: StreamSort.recent),
        throwsA(
          isA<DirectoryApiException>().having(
            (e) => e.message,
            'message',
            contains('PersistedQueryNotFound'),
          ),
        ),
      );
      await expectLater(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(isA<DirectoryApiException>()),
      );
    });

    test('no data, or no object, is malformed', () async {
      reply({'data': null});
      await expectLater(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(
          isA<DirectoryApiException>().having(
            (e) => e.message,
            'message',
            'Malformed GQL response',
          ),
        ),
      );
      reply(<Object>[]);
      await expectLater(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(isA<DirectoryApiException>()),
      );
    });

    test('tag streams nulled by an error throw', () {
      reply({
        'errors': [
          {'message': 'boom'},
        ],
        'data': {'streams': null},
      });
      expect(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(isA<DirectoryApiException>()),
      );
    });

    test('a long error message is cut', () async {
      reply({
        'errors': [
          for (var i = 0; i < 50; i++) {'message': 'x' * 1000},
        ],
      });
      await expectLater(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(
          isA<DirectoryApiException>().having(
            (e) => e.message.length,
            'length',
            lessThanOrEqualTo(1000),
          ),
        ),
      );
    });

    test('bad nodes are skipped, good ones kept', () async {
      Map<String, Object?> good(String login) => {
        'node': {
          'type': 'live',
          'createdAt': '2026-10-13T20:00:00Z',
          'broadcaster': {'id': '1', 'login': login},
        },
      };
      reply({
        'data': {
          'streams': {
            'edges': [
              good('first'),
              {'node': null},
              'edge',
              {
                'node': {'type': 'rerun'},
              },
              good('second'),
            ],
          },
        },
      });

      final page = await service.getTagStreams(
        tag: 'Chill',
        sort: StreamSort.recent,
      );

      expect(page.data.map((s) => s.userLogin), ['first', 'second']);
    });
  });

  group('unreadable and filtered answers', () {
    Map<String, Object?> node(String login, {String language = 'EN'}) => {
      'node': {
        'type': 'live',
        'createdAt': '2026-10-13T20:00:00Z',
        'language': language,
        'broadcaster': {'id': '1', 'login': login},
      },
    };

    test(
      'streams that all fail to read are an error, not an empty list',
      () async {
        reply({
          'data': {
            'streams': {
              'edges': [
                {
                  'node': {'type': 'LIVE'},
                },
                {
                  'node': {'type': 'LIVE'},
                },
              ],
            },
          },
        });
        await expectLater(
          service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
          throwsA(
            isA<DirectoryApiException>().having(
              (e) => e.message,
              'message',
              'Unreadable streams',
            ),
          ),
        );
      },
    );

    test('nulled edges with an error are an error', () async {
      reply({
        'errors': [
          {'message': 'edges failed'},
        ],
        'data': {
          'streams': {'edges': null},
        },
      });
      await expectLater(
        service.getTagStreams(tag: 'Chill', sort: StreamSort.recent),
        throwsA(isA<DirectoryApiException>()),
      );
    });

    test('no streams at all is just empty', () async {
      reply({
        'data': {
          'streams': {'edges': <Object>[]},
        },
      });
      final page = await service.getTagStreams(
        tag: 'Chill',
        sort: StreamSort.recent,
      );
      expect(page.data, isEmpty);
    });

    test('"other" keeps only streams in another language', () async {
      reply({
        'data': {
          'streams': {
            'edges': [node('english'), node('elsewhere', language: 'OTHER')],
          },
        },
      });
      final page = await service.getTagStreams(
        tag: 'Chill',
        sort: StreamSort.recent,
        language: 'other',
      );
      expect(page.data.single.userLogin, 'elsewhere');
      expect(page.data.single.language, 'other');
    });
  });
}
