import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_clip_service.dart';

import '../fixtures/clip_responses.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchClipService service;
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
    service = TwitchClipService(dio);
  });

  void reply(Object body) =>
      adapter.onPost(_gql, (s) => s.reply(200, body), data: Matchers.any);

  Map<String, dynamic> variables() =>
      ((requests.last.data as Map)['variables'] as Map).cast<String, dynamic>();

  Map<String, Object?> page(
    List<Object?> nodes, {
    bool hasNextPage = true,
    String? endCursor = 'MjA=',
  }) => {
    'data': {
      'topClips': {
        'edges': [
          for (final node in nodes) {'node': node},
        ],
        'pageInfo': {'hasNextPage': hasNextPage, 'endCursor': endCursor},
      },
    },
  };

  group('getTopClips', () {
    test('asks for 20 top clips, anonymously, in every language', () async {
      reply(page([clipNode]));

      await service.getTopClips();

      expect((requests.last.data as Map)['query'], contains('topClips('));
      expect(variables(), {'first': 20});
      expect(
        requests.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('parses the clips and the next cursor', () async {
      reply(page([clipNode, clipNodeOrphan]));

      final result = await service.getTopClips();

      expect(result.items.map((c) => c.slug), [
        clipNode['slug'],
        clipNodeOrphan['slug'],
      ]);
      expect(result.cursor, 'MjA=');
      expect(result.hasMore, isTrue);
    });

    test('pages on with the cursor, in the chosen language', () async {
      reply(page([clipNode], hasNextPage: false, endCursor: null));

      final result = await service.getTopClips(cursor: 'MjA=', language: 'fr');

      expect(variables(), {
        'first': 20,
        'after': 'MjA=',
        'languages': ['fr'],
      });
      expect(result.hasMore, isFalse);
      expect(result.cursor, isNull);
    });

    test('skips an unreadable clip, but all unreadable is an error', () async {
      reply(
        page([
          {'id': 'x'},
          clipNode,
        ]),
      );
      expect((await service.getTopClips()).items, hasLength(1));

      reply(
        page([
          {'id': 'x'},
        ]),
      );
      expect(service.getTopClips(), throwsA(isA<ClipApiException>()));
    });

    test('an integrity refusal is reported as such', () async {
      reply(clipIntegrityResponse);

      await expectLater(
        service.getTopClips(cursor: 'MjA='),
        throwsA(
          isA<ClipApiException>().having(
            (e) => e.isIntegrity,
            'integrity',
            isTrue,
          ),
        ),
      );
    });
  });
}
