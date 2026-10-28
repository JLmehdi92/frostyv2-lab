import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';

import '../fixtures/vod_responses.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late TwitchVodService service;
  late List<RequestOptions> sent;
  late void Function(RequestOptions, RequestInterceptorHandler) answer;

  Response<Object?> ok(RequestOptions o, Object body) =>
      Response(requestOptions: o, statusCode: 200, data: body);

  DioException status(RequestOptions o, int code) => DioException(
    requestOptions: o,
    response: Response(requestOptions: o, statusCode: code),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> body(RequestOptions o) =>
      (o.data as Map).cast<String, dynamic>();

  Map<String, Object?> edge(
    Map<String, Object?>? node, {
    Object? position = 3600,
    Object? updatedAt = '2026-10-27T20:00:00Z',
  }) => {
    'history': {'position': position, 'updatedAt': updatedAt},
    'node': node,
  };

  Map<String, Object?> viewed(List<Object?> edges, {Object? id = '1234'}) => {
    'data': {
      'currentUser': {
        'id': id,
        'viewedVideos': {'edges': edges},
      },
    },
  };

  setUp(() {
    sent = [];
    answer = (o, h) => h.resolve(ok(o, viewed(const [])));
    dio = Dio(BaseOptions());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          answer(o, h);
        },
      ),
    );
    service = TwitchVodService(dio)
      ..webToken = (() => 'webtok')
      ..viewerId = (() => '1234');
  });

  group('getResumeWatching', () {
    test("reads the viewer's shelf as the viewer, to gql only", () async {
      answer = (o, h) => h.resolve(
        ok(
          o,
          viewed([
            edge(vodNodeArchive),
            edge(
              vodNodeHighlightNoGame,
              position: 42,
              updatedAt: '2026-10-26T10:00:00Z',
            ),
          ]),
        ),
      );

      final entries = await service.getResumeWatching(limit: 12);

      expect(entries, hasLength(2));
      expect(entries![0].vod.id, '1000000001');
      expect(entries[0].vod.ownerLogin, 'streamer');
      expect(entries[0].history.positionSec, 3600);
      expect(entries[0].history.updatedAt, DateTime.utc(2026, 10, 27, 20));
      expect(entries[1].history.positionSec, 42);
      final o = sent.single;
      expect(o.uri.toString(), _gql);
      expect(o.headers['Authorization'], 'OAuth webtok');
      expect(body(o)['query'], contains('currentUser { id viewedVideos('));
      expect(body(o)['query'], contains('viewedVideos(first: \$limit)'));
      expect(body(o)['variables'], {'limit': 12});
    });

    test('skips deleted videos and unreadable positions', () async {
      answer = (o, h) => h.resolve(
        ok(
          o,
          viewed([
            edge(null),
            edge(vodNodeArchive, position: 'soon'),
            edge(vodNodeArchive, position: -5),
            edge({'id': 'broken'}),
            'nonsense',
            edge(vodNodeHighlightNoGame, updatedAt: null),
          ]),
        ),
      );

      final entries = await service.getResumeWatching();

      expect(entries, hasLength(1));
      expect(entries!.single.vod.id, '1000000002');
      expect(entries.single.history.updatedAt, isNull);
    });

    test("a web token of another account: not the viewer's shelf", () async {
      answer = (o, h) =>
          h.resolve(ok(o, viewed([edge(vodNodeArchive)], id: '999')));
      expect(await service.getResumeWatching(), isNull);
      // Nor without knowing the viewer.
      answer = (o, h) => h.resolve(ok(o, viewed([edge(vodNodeArchive)])));
      service.viewerId = () => null;
      expect(await service.getResumeWatching(), isNull);
    });

    test('a malformed number or id drops that video only', () async {
      answer = (o, h) => h.resolve(
        ok(
          o,
          viewed([
            edge({...vodNodeArchive, 'lengthSeconds': double.infinity}),
            edge({...vodNodeArchive, 'id': '../graphql'}),
            edge({...vodNodeArchive, 'viewCount': double.nan}),
          ]),
        ),
      );

      final entries = await service.getResumeWatching();

      expect(entries, hasLength(1));
      expect(entries!.single.vod.viewCount, 0);
    });

    test('logged out (or no session): nothing is sent', () async {
      service.webToken = () => null;
      expect(await service.getResumeWatching(), isNull);
      service.webToken = () => '';
      expect(await service.getResumeWatching(), isNull);
      expect(sent, isEmpty);
    });

    test('an answer without the viewer is "unknown", not "none"', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {'currentUser': null},
        }),
      );
      expect(await service.getResumeWatching(), isNull);
    });

    test('a 401 renews the web token once and stops sending it', () async {
      var renewals = 0;
      service.onWebTokenRejected = () async {
        renewals++;
        return 'fresh';
      };
      answer = (o, h) => h.reject(status(o, 401));

      expect(await service.getResumeWatching(), isNull);
      expect(await service.getResumeWatching(), isNull);

      expect(renewals, 1);
      expect(sent, hasLength(1));
    });

    test('an integrity refusal stops asking for this session', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'errors': [
            {'message': 'failed integrity check'},
          ],
          'data': null,
        }),
      );

      expect(await service.getResumeWatching(), isNull);
      expect(await service.getResumeWatching(), isNull);
      expect(sent, hasLength(1));
    });

    test('a network failure is null, never a throw', () async {
      answer = (o, h) => h.reject(
        DioException(requestOptions: o, type: DioExceptionType.connectionError),
      );
      expect(await service.getResumeWatching(), isNull);
    });
  });

  group('getVideos', () {
    test('one anonymous request for many ids, in their order', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {
            'v0': vodNodeHighlightNoGame,
            'v1': null,
            'v2': vodNodeArchive,
          },
        }),
      );

      final lookup = await service.getVideos([
        '1000000002',
        'v99',
        '1000000001',
      ]);

      expect(lookup.videos.map((v) => v.id), ['1000000002', '1000000001']);
      // Answered with nothing and no error: deleted.
      expect(lookup.missing, {'99'});
      final o = sent.single;
      expect(o.headers['Authorization'], isNull);
      final query = body(o)['query'] as String;
      expect(query, contains('v0: video(id: \$i0)'));
      expect(query, contains('v2: video(id: \$i2)'));
      expect(body(o)['variables'], {
        'i0': '1000000002',
        'i1': '99',
        'i2': '1000000001',
      });
    });

    test('ids that are not VOD ids never reach the query', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {'v0': vodNodeArchive},
        }),
      );

      final lookup = await service.getVideos(['../x', '1000000001', '']);

      expect(lookup.videos.single.id, '1000000001');
      expect(body(sent.single)['variables'], {'i0': '1000000001'});
    });

    test('no ids: no request', () async {
      expect((await service.getVideos(const [])).videos, isEmpty);
      expect((await service.getVideos(const ['nope'])).videos, isEmpty);
      expect(sent, isEmpty);
    });

    test('at most 25 per request', () async {
      answer = (o, h) => h.resolve(ok(o, {'data': <String, Object?>{}}));

      await service.getVideos([for (var i = 1; i <= 30; i++) '$i']);

      expect((body(sent.single)['variables'] as Map).length, 25);
    });

    test('a video refused on its own leaves the others', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'errors': [
            {
              'message': 'restricted',
              'path': ['v0'],
            },
          ],
          'data': {'v0': null, 'v1': vodNodeArchive},
        }),
      );

      final lookup = await service.getVideos(['1', '1000000001']);

      expect(lookup.videos.single.id, '1000000001');
      // Refused, not deleted: it can be asked again.
      expect(lookup.missing, isEmpty);
    });

    test('a GQL error throws', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'errors': [
            {'message': 'boom'},
          ],
        }),
      );
      await expectLater(
        service.getVideos(['1']),
        throwsA(isA<VodApiException>()),
      );
    });
  });
}
