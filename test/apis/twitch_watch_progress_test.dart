import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late TwitchVodService service;
  late List<RequestOptions> sent;

  /// How the next request is answered (default: a successful write).
  late void Function(RequestOptions, RequestInterceptorHandler) answer;

  Response<Object?> ok(RequestOptions o, Object body) =>
      Response(requestOptions: o, statusCode: 200, data: body);

  DioException status(RequestOptions o, int code) => DioException(
    requestOptions: o,
    response: Response(requestOptions: o, statusCode: code),
    type: DioExceptionType.badResponse,
  );

  String? auth(RequestOptions o) => o.headers['Authorization'] as String?;

  Map<String, dynamic> body(RequestOptions o) =>
      (o.data as Map).cast<String, dynamic>();

  const written = {
    'data': {
      'updateUserViewedVideo': {
        'video': {'id': '318071962212'},
      },
    },
  };

  const integrityError = {
    'errors': [
      {
        'message': 'failed integrity check',
        'path': ['updateUserViewedVideo'],
      },
    ],
    'data': {'updateUserViewedVideo': null},
  };

  setUp(() {
    sent = [];
    answer = (o, h) => h.resolve(ok(o, written));
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

  group('updateViewedVideo', () {
    test('writes the live position as the viewer, to gql only', () async {
      final done = await service.updateViewedVideo(
        videoId: '318071962212',
        type: WatchedVideoType.live,
        positionSec: 4321,
      );

      expect(done, isTrue);
      expect(sent, hasLength(1));
      final o = sent.single;
      expect(o.uri.toString(), _gql);
      expect(o.method, 'POST');
      expect(auth(o), 'OAuth webtok');
      expect(o.headers['Client-ID'], 'kimne78kx3ncx6brgo4mv6wki5h1ko');
      expect(
        body(o)['query'],
        contains('updateUserViewedVideo(input: \$input)'),
      );
      expect(body(o)['variables'], {
        'input': {
          'userID': '1234',
          'videoID': '318071962212',
          'videoType': 'LIVE',
          'position': 4321,
        },
      });
    });

    test('a VOD is written as a VOD', () async {
      await service.updateViewedVideo(
        videoId: 'v2905941597',
        type: WatchedVideoType.vod,
        positionSec: 75,
      );

      final input = (body(sent.single)['variables'] as Map)['input'] as Map;
      expect(input['videoType'], 'VOD');
      expect(input['videoID'], '2905941597');
    });

    test('nothing is sent without a session or with a bad input', () async {
      Future<bool> write({String id = '318071962212', int position = 60}) =>
          service.updateViewedVideo(
            videoId: id,
            type: WatchedVideoType.live,
            positionSec: position,
          );

      service.webToken = () => null;
      expect(await write(), isFalse);
      service.webToken = () => '';
      expect(await write(), isFalse);
      service
        ..webToken = (() => 'webtok')
        ..viewerId = (() => null);
      expect(await write(), isFalse);
      service.viewerId = () => 'not-an-id';
      expect(await write(), isFalse);
      service.viewerId = () => '1234';
      expect(await write(id: '../graphql'), isFalse);
      expect(await write(position: 0), isFalse);
      expect(await write(position: -1), isFalse);

      expect(sent, isEmpty);
    });

    test('a 401 renews the web token once and stops sending it', () async {
      var renewals = 0;
      service.onWebTokenRejected = () async {
        renewals++;
        return 'fresh';
      };
      answer = (o, h) => h.reject(status(o, 401));

      Future<bool> write() => service.updateViewedVideo(
        videoId: '318071962212',
        type: WatchedVideoType.live,
        positionSec: 60,
      );

      expect(await write(), isFalse);
      expect(await write(), isFalse);
      expect(await service.getViewingHistory('2905941597'), isNull);
      expect(sent, hasLength(1));
      expect(renewals, 1);

      // A new token is tried again.
      service.webToken = () => 'fresh';
      answer = (o, h) => h.resolve(ok(o, written));
      expect(await write(), isTrue);
      expect(auth(sent.last), 'OAuth fresh');
    });

    test('a failed renewal never surfaces', () async {
      service.onWebTokenRejected = () async => throw StateError('no page');
      answer = (o, h) => h.reject(status(o, 401));

      expect(
        await service.updateViewedVideo(
          videoId: '318071962212',
          type: WatchedVideoType.live,
          positionSec: 60,
        ),
        isFalse,
      );
    });

    test(
      'a refused write (integrity) is not sent again this session',
      () async {
        answer = (o, h) => h.resolve(ok(o, integrityError));

        Future<bool> write() => service.updateViewedVideo(
          videoId: '318071962212',
          type: WatchedVideoType.live,
          positionSec: 60,
        );

        expect(await write(), isFalse);
        expect(await write(), isFalse);
        expect(sent, hasLength(1));
      },
    );

    test(
      'a network failure is a no-op and the next save tries again',
      () async {
        answer = (o, h) => h.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        );

        Future<bool> write() => service.updateViewedVideo(
          videoId: '318071962212',
          type: WatchedVideoType.live,
          positionSec: 60,
        );

        expect(await write(), isFalse);
        answer = (o, h) => h.resolve(ok(o, written));
        expect(await write(), isTrue);
        expect(sent, hasLength(2));
      },
    );
  });

  group('transient GQL errors', () {
    const busy = {
      'errors': [
        {'message': 'service timeout'},
      ],
      'data': null,
    };

    Future<bool> write() => service.updateViewedVideo(
      videoId: '318071962212',
      type: WatchedVideoType.live,
      positionSec: 60,
    );

    test('one does not stop the next save', () async {
      answer = (o, h) => h.resolve(ok(o, busy));
      expect(await write(), isFalse);
      answer = (o, h) => h.resolve(ok(o, written));
      expect(await write(), isTrue);
      expect(sent, hasLength(2));
    });

    test('three in a row stop that kind of request', () async {
      answer = (o, h) => h.resolve(ok(o, busy));
      for (var i = 0; i < 4; i++) {
        expect(await write(), isFalse);
        expect(await service.getViewingHistory('2905941597'), isNull);
      }
      expect(sent, hasLength(6));
    });

    test('a success in between starts the count again', () async {
      for (var i = 0; i < 3; i++) {
        answer = (o, h) => h.resolve(ok(o, busy));
        await write();
        await write();
        answer = (o, h) => h.resolve(ok(o, written));
        expect(await write(), isTrue);
      }
    });
  });

  group('getViewingHistory', () {
    test('reads where the viewer left the video, as the viewer', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {
            'video': {
              'self': {
                'viewingHistory': {
                  'position': 3600,
                  'updatedAt': '2026-10-19T22:00:00Z',
                },
              },
            },
          },
        }),
      );

      final history = await service.getViewingHistory('v2905941597');

      expect(history?.positionSec, 3600);
      expect(history?.updatedAt, DateTime.utc(2026, 10, 19, 22));
      final o = sent.single;
      expect(o.uri.toString(), _gql);
      expect(auth(o), 'OAuth webtok');
      expect(
        body(o)['query'],
        contains('viewingHistory { position updatedAt }'),
      );
      expect(body(o)['variables'], {'id': '2905941597'});
    });

    test('never watched, or an unreadable answer: null', () async {
      for (final reply in [
        {
          'data': {
            'video': {
              'self': {'viewingHistory': null},
            },
          },
        },
        {
          'data': {'video': null},
        },
        {
          'data': {
            'video': {
              'self': {
                'viewingHistory': {'position': 'x'},
              },
            },
          },
        },
        {
          'data': {
            'video': {
              'self': {
                'viewingHistory': {'position': -5},
              },
            },
          },
        },
        'garbage',
      ]) {
        answer = (o, h) => h.resolve(ok(o, reply));
        expect(
          await service.getViewingHistory('2905941597'),
          isNull,
          reason: '$reply',
        );
      }
    });

    test('a missing or bad updatedAt keeps the position', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {
            'video': {
              'self': {
                'viewingHistory': {'position': 90, 'updatedAt': 'soon'},
              },
            },
          },
        }),
      );

      final history = await service.getViewingHistory('2905941597');
      expect(history?.positionSec, 90);
      expect(history?.updatedAt, isNull);
    });

    test('no session or a bad id: nothing is asked', () async {
      service.webToken = () => null;
      expect(await service.getViewingHistory('2905941597'), isNull);
      service.webToken = () => 'webtok';
      expect(await service.getViewingHistory('nope'), isNull);
      expect(sent, isEmpty);
    });

    test('a GQL error stops reads for the session, not writes', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'errors': [
            {'message': 'failed integrity check'},
          ],
        }),
      );

      expect(await service.getViewingHistory('2905941597'), isNull);
      expect(await service.getViewingHistory('2905941597'), isNull);
      expect(sent, hasLength(1));

      answer = (o, h) => h.resolve(ok(o, written));
      expect(
        await service.updateViewedVideo(
          videoId: '2905941597',
          type: WatchedVideoType.vod,
          positionSec: 60,
        ),
        isTrue,
      );
    });

    test('the anonymous requests never carry the web token', () async {
      answer = (o, h) => h.resolve(
        ok(o, {
          'data': {
            'video': {
              'muteInfo': {
                'mutedSegmentConnection': {'nodes': <Object>[]},
              },
            },
          },
        }),
      );

      await service.getMutedSegments('2905941597');

      expect(auth(sent.single), isNull);
    });
  });
}
