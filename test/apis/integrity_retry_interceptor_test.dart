import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/integrity_retry_interceptor.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/integrity/integrity_token_provider.dart';

const _gql = 'https://gql.twitch.tv/gql';

final _integrityToken = 'v4.public.${'b' * 40}';

const _refused = {
  'errors': [
    {'message': 'failed integrity check'},
  ],
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late int mints;
  late bool mintFails;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    mints = 0;
    mintFails = false;
    dio.interceptors
      ..add(
        IntegrityRetryInterceptor(
          dio: dio,
          tokens: IntegrityTokenProvider(
            mint: () async {
              mints++;
              if (mintFails) throw StateError('no session');
              return IntegrityToken(
                value: _integrityToken,
                deviceId: 'device0001',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
              );
            },
            webSession: () => 'web-token',
          ),
        ),
      )
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
  });

  void replyRefusedThen(Object? retried) {
    adapter
      ..onPost(
        _gql,
        (server) => server.reply(200, _refused),
        data: Matchers.any,
      )
      ..onPost(
        _gql,
        (server) => server.reply(200, retried),
        data: Matchers.any,
        headers: {'Client-Integrity': _integrityToken},
      );
  }

  test('a refused follow is retried once with the integrity headers', () async {
    replyRefusedThen({
      'data': {
        'followUser': {'error': null},
      },
    });
    final result = await TwitchViewerActionsService(
      dio,
    ).followChannel(channelId: '123', authToken: 'web-token');

    expect(result, FollowResult.done);
    expect(mints, 1);
    expect(requests, hasLength(2));
    expect(requests.first.headers['Client-Integrity'], isNull);
    expect(requests.last.headers['Client-Integrity'], _integrityToken);
    expect(requests.last.headers['X-Device-Id'], 'device0001');
  });

  test('a claim refused twice reports the refusal', () async {
    replyRefusedThen(_refused);
    final code = await TwitchPointsService(
      dio,
    ).claimBonus(channelId: '123', claimId: 'claim-1', authToken: 'web-token');

    expect(code, contains('integrity'));
    expect(requests, hasLength(2));
  });

  test('without a token the original refusal comes back', () async {
    mintFails = true;
    replyRefusedThen(const {'data': {}});
    final result = await TwitchViewerActionsService(
      dio,
    ).followChannel(channelId: '123', authToken: 'web-token');

    expect(result, FollowResult.integrityRefused);
    expect(requests, hasLength(1));
  });

  test('queries and background mutations never mint', () async {
    replyRefusedThen(const {'data': {}});
    for (final body in [
      {'query': 'query Q { user { id } }'},
      {
        'operationName': 'UpdateUserViewedVideo',
        'query': 'mutation UpdateUserViewedVideo { x }',
      },
    ]) {
      await dio.post<dynamic>(
        _gql,
        data: body,
        options: Options(headers: {'Authorization': 'OAuth web-token'}),
      );
    }
    expect(mints, 0);
    expect(requests, hasLength(2));
  });

  test('an anonymous mutation never mints', () async {
    replyRefusedThen(const {'data': {}});
    await dio.post<dynamic>(_gql, data: {'query': 'mutation M { x }'});
    expect(mints, 0);
  });

  test('an accepted mutation is left alone', () async {
    adapter.onPost(
      _gql,
      (server) => server.reply(200, {
        'data': {
          'followUser': {'error': null},
        },
      }),
      data: Matchers.any,
    );
    final result = await TwitchViewerActionsService(
      dio,
    ).followChannel(channelId: '123', authToken: 'web-token');
    expect(result, FollowResult.done);
    expect(mints, 0);
    expect(requests, hasLength(1));
  });
}
