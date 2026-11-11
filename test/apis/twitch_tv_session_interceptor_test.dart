import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_report_service.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/report.dart';
import 'package:onset/models/twitch_tv_session.dart';

const _gql = 'https://gql.twitch.tv/gql';

const _credentials = TwitchTvCredentials(
  session: TwitchTvSession(
    accessToken: 'tv-access',
    userId: '77',
    deviceId: 'tvdevice00000001',
  ),
  clientSessionId: 'session000000001',
);

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> sent;
  late TwitchTvCredentials? credentials;
  late int rejections;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    sent = [];
    credentials = _credentials;
    rejections = 0;
    dio.interceptors
      ..add(
        TwitchTvSessionInterceptor(
          credentials: () => credentials,
          onRejected: () => rejections++,
        ),
      )
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            handler.next(options);
          },
        ),
      );
  });

  void reply(int status, Object? body) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  String? header(RequestOptions request, String name) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return '${entry.value}';
      }
    }
    return null;
  }

  int count(RequestOptions request, String name) => request.headers.keys
      .where((key) => key.toLowerCase() == name.toLowerCase())
      .length;

  void expectTv(RequestOptions request) {
    expect(header(request, 'Client-Id'), kTwitchTvClientId);
    expect(header(request, 'Authorization'), 'OAuth tv-access');
    expect(header(request, 'X-Device-Id'), 'tvdevice00000001');
    expect(header(request, 'Client-Session-Id'), 'session000000001');
    expect(count(request, 'Client-Id'), 1);
    expect(count(request, 'Authorization'), 1);
  }

  void expectWeb(RequestOptions request) {
    expect(header(request, 'Client-Id'), kTwitchWebClientId);
    expect(header(request, 'Authorization'), 'OAuth web-token');
    expect(header(request, 'Client-Session-Id'), isNull);
  }

  Future<void> send(
    String document, {
    String? operation,
    Map<String, Object?>? extra,
    bool signed = true,
    String url = _gql,
  }) => dio.post<dynamic>(
    url,
    data: {'operationName': ?operation, 'query': document},
    options: Options(
      extra: extra,
      headers: {
        'Client-ID': kTwitchWebClientId,
        if (signed) 'Authorization': 'OAuth web-token',
      },
    ),
  );

  group('routing per mutation', () {
    const userMutations = [
      'FollowUserMutation',
      'UnfollowUserMutation',
      'FollowGameMutation',
      'UnfollowGameMutation',
      'ClaimCommunityPoints',
      'MakePrediction',
      'OpenChests',
      'ClaimDropRewardsMutation',
      'ClaimMomentMutation',
      'RedeemCustomReward',
      'CommunityGoalMutation',
      'UpdateUserDescriptionMutation',
      'UpdateClipMutation',
      'ReportContent',
      'PollsVoteMutation',
    ];

    for (final operation in userMutations) {
      test('$operation goes through the TV session, once', () async {
        reply(200, {'data': <String, Object?>{}});
        await send(
          'mutation $operation { x }',
          operation: operation,
          extra: TwitchTvSessionInterceptor.userAction,
        );
        expectTv(sent.single);
      });
    }

    test('a signed mutation without the marker is routed too', () async {
      reply(200, {'data': <String, Object?>{}});
      await send('mutation Onset { x }');
      expectTv(sent.single);
    });

    test('a stale Client-Integrity header is dropped', () async {
      reply(200, {'data': <String, Object?>{}});
      await dio.post<dynamic>(
        _gql,
        data: {'query': 'mutation Onset { x }'},
        options: Options(
          headers: {
            'Client-ID': kTwitchWebClientId,
            'Authorization': 'OAuth web-token',
            'Client-Integrity': 'stale',
          },
        ),
      );
      expect(header(sent.single, 'Client-Integrity'), isNull);
    });
  });

  group('left on the web session', () {
    test('queries', () async {
      reply(200, {'data': <String, Object?>{}});
      await send(
        'query Viewer { currentUser { id } }',
        extra: TwitchTvSessionInterceptor.userAction,
      );
      expectWeb(sent.single);
    });

    test('background mutations', () async {
      reply(200, {'data': <String, Object?>{}});
      await send(
        'mutation UpdateUserViewedVideo { x }',
        operation: 'UpdateUserViewedVideo',
        extra: TwitchTvSessionInterceptor.userAction,
      );
      expectWeb(sent.single);
    });

    test('anonymous mutations', () async {
      reply(200, {'data': <String, Object?>{}});
      await send('mutation Onset { x }', signed: false);
      expect(header(sent.single, 'Authorization'), isNull);
      expect(header(sent.single, 'Client-Id'), kTwitchWebClientId);
    });

    test('everything when no TV session is connected', () async {
      credentials = null;
      reply(200, {'data': <String, Object?>{}});
      await send(
        'mutation FollowUserMutation { x }',
        extra: TwitchTvSessionInterceptor.userAction,
      );
      expectWeb(sent.single);
    });

    test('any host but gql.twitch.tv never sees the TV token', () async {
      const elsewhere = 'https://example.com/gql';
      adapter.onPost(
        elsewhere,
        (server) => server.reply(200, {}),
        data: Matchers.any,
      );
      await send(
        'mutation FollowUserMutation { x }',
        extra: TwitchTvSessionInterceptor.userAction,
        url: elsewhere,
      );
      expect(header(sent.single, 'Authorization'), 'OAuth web-token');
    });
  });

  group('a rejected TV token', () {
    test('a 401 reports the rejection', () async {
      reply(401, {'error': 'Unauthorized'});
      await expectLater(
        send('mutation Onset { x }'),
        throwsA(isA<DioException>()),
      );
      expect(rejections, 1);
    });

    test('a GraphQL error about permissions is not a rejection', () async {
      reply(200, {
        'errors': [
          {'message': 'unauthorized'},
        ],
      });
      await send('mutation Onset { x }');
      expect(rejections, 0);
    });

    test('a web-session 401 is not the TV session’s', () async {
      credentials = null;
      reply(401, {'error': 'Unauthorized'});
      await expectLater(
        send('mutation Onset { x }'),
        throwsA(isA<DioException>()),
      );
      expect(rejections, 0);
    });
  });

  group('through the services', () {
    test('a follow is sent once with the TV session and succeeds', () async {
      reply(200, {
        'data': {
          'followUser': {'follow': <String, Object?>{}, 'error': null},
        },
      });
      final result = await TwitchViewerActionsService(
        dio,
      ).followChannel(channelId: '1000', authToken: 'web-token');
      expect(result, FollowResult.done);
      expect(sent, hasLength(1));
      expectTv(sent.single);
    });

    test('an integrity refusal without a TV session asks for one', () async {
      credentials = null;
      reply(200, {
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });
      final result = await TwitchViewerActionsService(
        dio,
      ).followChannel(channelId: '1000', authToken: 'web-token');
      expect(result, FollowResult.needsTvSession);
      expect(sent, hasLength(1));
    });

    test('an integrity refusal through the TV session is Twitch’s', () async {
      reply(200, {
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });
      final result = await TwitchViewerActionsService(
        dio,
      ).followChannel(channelId: '1000', authToken: 'web-token');
      expect(result, FollowResult.integrityRefused);
      expect(sent, hasLength(1));
    });

    test('a rejected TV token is an expired session', () async {
      reply(401, {'error': 'Unauthorized'});
      final result = await TwitchViewerActionsService(
        dio,
      ).followChannel(channelId: '1000', authToken: 'web-token');
      expect(result, FollowResult.tvSessionExpired);
      expect(rejections, 1);
    });

    test('a bonus claim goes through the TV session', () async {
      reply(200, {
        'data': {
          'claimCommunityPoints': {'error': null},
        },
      });
      final error = await TwitchPointsService(
        dio,
      ).claimBonus(channelId: '1', claimId: 'c', authToken: 'web-token');
      expect(error, isNull);
      expectTv(sent.single);
    });

    test('a report goes through the TV session', () async {
      reply(200, {
        'data': {
          'reportContent': {'content': 'USER_REPORT', 'contentID': '42'},
        },
      });
      await TwitchReportService(dio).report(
        target: const ReportTarget.user(userId: '42', name: 'Someone'),
        reason: ReportReason.spam,
        description: '',
        authToken: 'web-token',
      );
      expectTv(sent.single);
    });
  });
}
