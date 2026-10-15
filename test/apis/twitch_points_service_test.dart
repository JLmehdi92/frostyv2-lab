import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/models/community_points.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _gql = 'https://gql.twitch.tv/gql';

const _reward = PointsReward(id: 'r1', title: 'Hydrate', cost: 100);

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchPointsService service;
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
    service = TwitchPointsService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  Future<String?> redeem() =>
      service.redeemReward(channelId: '42', reward: _reward, authToken: 'tok');

  group('a mutation reduces the reply to an error code', () {
    test('no error is success', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {'error': null},
        },
      });

      expect(await redeem(), isNull);
    });

    test('the error code is passed through', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {
            'error': {'code': 'NOT_ENOUGH_POINTS'},
          },
        },
      });

      expect(await redeem(), 'NOT_ENOUGH_POINTS');
    });

    test('an error object without a code is unknown', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {'error': <String, dynamic>{}},
        },
      });

      expect(await redeem(), 'unknown_error');
    });

    test('a top-level error message is passed through', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      expect(await redeem(), 'failed integrity check');
    });

    test('a top-level error without a message is unknown', () async {
      reply({
        'errors': [<String, dynamic>{}],
      });

      expect(await redeem(), 'unknown_error');
    });

    test('an empty payload is not mistaken for success', () async {
      reply({
        'data': {'redeemCommunityPointsCustomReward': null},
      });

      expect(await redeem(), 'unknown_error');
    });

    test('a reply without data is not mistaken for success', () async {
      reply(<String, dynamic>{});

      expect(await redeem(), 'unknown_error');
    });

    test('a server error is a request failure', () async {
      reply({'error': 'boom'}, status: 500);

      expect(await redeem(), 'request_failed');
    });

    test('a connection error is a request failure', () async {
      adapter.onPost(
        _gql,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: _gql),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );

      expect(await redeem(), 'request_failed');
    });

    test(
      'a refused token is reported as such, not as a network error',
      () async {
        reply({'error': 'Unauthorized'}, status: 401);

        final code = await redeem();

        expect(code, 'unauthorized');
        expect(
          PointsActionResult.fromError(code).status,
          PointsActionStatus.notAuthenticated,
        );
      },
    );
  });

  test('the default client gives up on a hung request', () {
    final options = TwitchPointsService.defaultOptions;

    expect(options.connectTimeout, const Duration(seconds: 5));
    expect(options.receiveTimeout, const Duration(seconds: 10));
  });
}
