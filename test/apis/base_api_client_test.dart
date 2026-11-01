import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';

/// Concrete test subclass to test BaseApiClient through its public interface.
class TestApiClient extends BaseApiClient {
  TestApiClient(Dio dio) : super(dio, 'https://api.test.com');

  /// Test wrapper that exercises the error handling path through get().
  Future<dynamic> testGet(String endpoint) => get(endpoint);

  Future<dynamic> testPatch(String endpoint, Object data) =>
      patch(endpoint, data: data);
}

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TestApiClient client;

  setUp(() {
    dio = Dio(BaseOptions());
    dioAdapter = DioAdapter(dio: dio);
    client = TestApiClient(dio);
  });

  group('isSuccessResponse', () {
    test('returns true for 200', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 200,
      );
      expect(client.isSuccessResponse(response), isTrue);
    });

    test('returns true for 201', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 201,
      );
      expect(client.isSuccessResponse(response), isTrue);
    });

    test('returns true for 204', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 204,
      );
      expect(client.isSuccessResponse(response), isTrue);
    });

    test('returns false for 300', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 300,
      );
      expect(client.isSuccessResponse(response), isFalse);
    });

    test('returns false for 400', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 400,
      );
      expect(client.isSuccessResponse(response), isFalse);
    });

    test('returns false for 500', () {
      final response = Response(
        requestOptions: RequestOptions(),
        statusCode: 500,
      );
      expect(client.isSuccessResponse(response), isFalse);
    });

    test('returns false for null statusCode', () {
      final response = Response(requestOptions: RequestOptions());
      expect(client.isSuccessResponse(response), isFalse);
    });
  });

  group('error handling through get()', () {
    test('400 throws ApiException', () async {
      dioAdapter.onGet(
        'https://api.test.com/test',
        (server) => server.reply(400, {'message': 'Bad field'}),
      );

      expect(
        () => client.testGet('/test'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Bad field'),
        ),
      );
    });

    test('401 throws UnauthorizedException', () async {
      dioAdapter.onGet(
        'https://api.test.com/auth',
        (server) => server.reply(401, {'message': 'Unauthorized'}),
      );

      expect(
        () => client.testGet('/auth'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('404 throws NotFoundException', () async {
      dioAdapter.onGet(
        'https://api.test.com/missing',
        (server) => server.reply(404, {'message': 'User not found'}),
      );

      expect(
        () => client.testGet('/missing'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'User not found',
          ),
        ),
      );
    });

    test('404 with no server message uses default', () async {
      dioAdapter.onGet(
        'https://api.test.com/empty404',
        (server) => server.reply(404, 'not json'),
      );

      expect(
        () => client.testGet('/empty404'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'Resource not found',
          ),
        ),
      );
    });

    test('409 throws ApiException about conflict', () async {
      dioAdapter.onGet(
        'https://api.test.com/conflict',
        (server) => server.reply(409, null),
      );

      expect(
        () => client.testGet('/conflict'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Conflict'),
          ),
        ),
      );
    });

    test('429 throws ApiException about rate limit', () async {
      dioAdapter.onGet(
        'https://api.test.com/ratelimit',
        (server) => server.reply(429, null),
      );

      expect(
        () => client.testGet('/ratelimit'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Rate limit'),
          ),
        ),
      );
    });

    test('500 throws ServerException', () async {
      dioAdapter.onGet(
        'https://api.test.com/server-error',
        (server) => server.reply(500, null),
      );

      expect(
        () => client.testGet('/server-error'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('502 throws ServerException', () async {
      dioAdapter.onGet(
        'https://api.test.com/bad-gateway',
        (server) => server.reply(502, null),
      );

      expect(
        () => client.testGet('/bad-gateway'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test('503 throws ServerException', () async {
      dioAdapter.onGet(
        'https://api.test.com/maintenance',
        (server) => server.reply(503, null),
      );

      expect(
        () => client.testGet('/maintenance'),
        throwsA(isA<ServerException>()),
      );
    });

    test('504 throws ServerException', () async {
      dioAdapter.onGet(
        'https://api.test.com/timeout',
        (server) => server.reply(504, null),
      );

      expect(() => client.testGet('/timeout'), throwsA(isA<ServerException>()));
    });

    test('422 uses server message from error field', () async {
      dioAdapter.onGet(
        'https://api.test.com/unprocessable',
        (server) => server.reply(422, {'error': 'Invalid email'}),
      );

      expect(
        () => client.testGet('/unprocessable'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid email',
          ),
        ),
      );
    });

    test('400 uses error_description field', () async {
      dioAdapter.onGet(
        'https://api.test.com/oauth-error',
        (server) =>
            server.reply(400, {'error_description': 'OAuth error description'}),
      );

      expect(
        () => client.testGet('/oauth-error'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'OAuth error description',
          ),
        ),
      );
    });

    test('400 prefers message field over error field', () async {
      dioAdapter.onGet(
        'https://api.test.com/priority',
        (server) => server.reply(400, {
          'message': 'From message',
          'error': 'From error',
        }),
      );

      expect(
        () => client.testGet('/priority'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'From message',
          ),
        ),
      );
    });

    test('403 returns permission error', () async {
      dioAdapter.onGet(
        'https://api.test.com/forbidden',
        (server) => server.reply(403, null),
      );

      expect(
        () => client.testGet('/forbidden'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', contains('permissions'))
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('unknown status code throws ServerException', () async {
      dioAdapter.onGet(
        'https://api.test.com/teapot',
        (server) => server.reply(418, null),
      );

      expect(
        () => client.testGet('/teapot'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 418),
        ),
      );
    });
  });

  test('400 and 422 keep their code', () async {
    dioAdapter.onGet(
      'https://api.test.com/bad',
      (server) => server.reply(400, {'message': 'bad condition'}),
    );
    dioAdapter.onGet(
      'https://api.test.com/odd',
      (server) => server.reply(422, null),
    );

    expect(
      () => client.testGet('/bad'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 400)),
    );
    expect(
      () => client.testGet('/odd'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 422)),
    );
  });

  test("403 keeps Twitch's reason", () async {
    dioAdapter.onGet(
      'https://api.test.com/whispers',
      (server) => server.reply(403, {
        'message': 'The sender does not have a verified phone number.',
      }),
    );

    expect(
      () => client.testGet('/whispers'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', contains('phone number'))
            .having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test("409 and 429 keep Twitch's reason and their code", () async {
    dioAdapter.onGet(
      'https://api.test.com/bans',
      (server) => server.reply(409, {
        'message': 'You may not update the ban state right now.',
      }),
    );
    dioAdapter.onGet(
      'https://api.test.com/busy',
      (server) => server.reply(429, {'message': 'Slow down.'}),
    );

    expect(
      () => client.testGet('/bans'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', contains('ban state'))
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
    expect(
      () => client.testGet('/busy'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Slow down.')
            .having((e) => e.statusCode, 'statusCode', 429),
      ),
    );
  });

  group('successful get()', () {
    test('returns data on success', () async {
      dioAdapter.onGet(
        'https://api.test.com/users',
        (server) => server.reply(200, {'data': 'test'}),
      );

      final result = await client.testGet('/users');
      expect(result, {'data': 'test'});
    });

    test('handles absolute URL', () async {
      dioAdapter.onGet(
        'https://other.com/endpoint',
        (server) => server.reply(200, {'result': 'ok'}),
      );

      final result = await client.testGet('https://other.com/endpoint');
      expect(result, {'result': 'ok'});
    });
  });

  group('patch()', () {
    test('sends the body and returns the answer', () async {
      dioAdapter.onPatch(
        'https://api.test.com/settings',
        (server) => server.reply(200, {'data': 'ok'}),
        data: {'slow_mode': true},
      );

      final result = await client.testPatch('/settings', {'slow_mode': true});
      expect(result, {'data': 'ok'});
    });

    test('maps errors like the other verbs', () async {
      dioAdapter.onPatch(
        'https://api.test.com/settings',
        (server) => server.reply(400, {'message': 'bad mode'}),
        data: Matchers.any,
      );

      expect(
        () => client.testPatch('/settings', {}),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'bad mode'),
        ),
      );
    });
  });

  group('ApiException', () {
    test('toString includes message', () {
      const exception = ApiException('Test error');
      expect(exception.toString(), 'ApiException: Test error');
    });

    test('stores status code and type', () {
      const exception = ApiException(
        'Error',
        404,
        DioExceptionType.badResponse,
      );
      expect(exception.statusCode, 404);
      expect(exception.type, DioExceptionType.badResponse);
    });
  });

  group('Exception subtypes', () {
    test('NetworkException has connectionError type', () {
      const exception = NetworkException('No network');
      expect(exception.type, DioExceptionType.connectionError);
      expect(exception.statusCode, isNull);
    });

    test('TimeoutException has connectionTimeout type', () {
      const exception = TimeoutException('Timed out');
      expect(exception.type, DioExceptionType.connectionTimeout);
    });

    test('ServerException has badResponse type and status code', () {
      const exception = ServerException('Server error', 500);
      expect(exception.type, DioExceptionType.badResponse);
      expect(exception.statusCode, 500);
    });

    test('NotFoundException has 404 status code', () {
      const exception = NotFoundException('Not found');
      expect(exception.statusCode, 404);
    });

    test('UnauthorizedException has 401 status code', () {
      const exception = UnauthorizedException('Unauthorized');
      expect(exception.statusCode, 401);
    });
  });

  group('crashReasonFor', () {
    test('names the service, never who or what was asked for', () {
      // A path can name a channel (recent messages, usher) or carry a
      // user id (7TV, BTTV, FFZ); a query can name anyone.
      for (final (url, reason) in [
        (
          'https://recent-messages.robotty.de/api/v2/recent-messages/somelogin',
          'GET https://recent-messages.robotty.de',
        ),
        (
          'https://usher.ttvnw.net/api/channel/hls/somelogin.m3u8?token=t',
          'GET https://usher.ttvnw.net',
        ),
        ('https://7tv.io/v3/users/twitch/12345', 'GET https://7tv.io'),
        (
          'https://api.twitch.tv/helix/users?login=somelogin',
          'GET https://api.twitch.tv',
        ),
      ]) {
        expect(
          crashReasonFor(RequestOptions(path: url, method: 'GET')),
          reason,
        );
      }
      expect(
        crashReasonFor(
          RequestOptions(path: '/chat/color', baseUrl: 'https://api.test.com'),
        ),
        'GET https://api.test.com',
      );
    });
  });

  group('each failure says its kind, for a screen to word', () {
    Future<ApiException> failure(int status, [Object? body]) async {
      dioAdapter.onGet(
        'https://api.test.com/kind',
        (server) => server.reply(status, body ?? const <String, Object>{}),
      );
      try {
        await client.testGet('/kind');
      } on ApiException catch (e) {
        return e;
      }
      throw StateError('no failure');
    }

    for (final (status, kind) in const [
      (400, ApiErrorKind.badRequest),
      (401, ApiErrorKind.unauthorized),
      (403, ApiErrorKind.forbidden),
      (404, ApiErrorKind.notFound),
      (409, ApiErrorKind.conflict),
      (422, ApiErrorKind.invalid),
      (429, ApiErrorKind.rateLimited),
      (500, ApiErrorKind.server),
      (502, ApiErrorKind.unavailable),
      (503, ApiErrorKind.maintenance),
      (504, ApiErrorKind.serverTimeout),
      (418, ApiErrorKind.http),
    ]) {
      test('$status: ${kind.name}, and no explanation of Twitch\'s', () async {
        final e = await failure(status);
        expect(e.kind, kind);
        expect(e.statusCode, status);
        expect(e.twitchMessage, isNull);
      });
    }

    test("Twitch's own explanation is kept apart, as it wrote it", () async {
      final e = await failure(403, {'message': 'Missing scope'});
      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.twitchMessage, 'Missing scope');
      expect(e.message, 'Missing scope');
    });

    test('a blank explanation, or only the reason phrase, is none', () async {
      for (final body in const [
        {'message': ''},
        {'message': '   '},
        {'error': 'Not Found'},
        {'error': 'Not Found', 'message': ''},
      ]) {
        final e = await failure(404, body);
        expect(e.kind, ApiErrorKind.notFound, reason: '$body');
        expect(e.twitchMessage, isNull, reason: '$body');
      }
      // The logs keep whatever Twitch said.
      expect((await failure(404, {'error': 'Not Found'})).message, 'Not Found');
      // An OAuth description is an explanation.
      final oauth = await failure(400, {
        'error': 'invalid_request',
        'error_description': 'Missing client id',
      });
      expect(oauth.twitchMessage, 'Missing client id');
    });

    test('a connection dropped after it was made is a network error', () async {
      for (final inner in [
        const SocketException('Connection reset by peer'),
        const HttpException('Connection closed before full header'),
      ]) {
        dioAdapter.onGet(
          'https://api.test.com/dropped',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(
                path: 'https://api.test.com/dropped',
              ),
              error: inner,
            ),
          ),
        );
        try {
          await client.testGet('/dropped');
          fail('no failure');
        } on ApiException catch (e) {
          expect(e, isA<NetworkException>(), reason: '$inner');
          expect(e.kind, ApiErrorKind.network, reason: '$inner');
        }
      }
    });

    test('the connection failing, timing out or being cancelled', () async {
      for (final (type, kind) in const [
        (DioExceptionType.connectionError, ApiErrorKind.network),
        (DioExceptionType.connectionTimeout, ApiErrorKind.connectionTimeout),
        (DioExceptionType.sendTimeout, ApiErrorKind.sendTimeout),
        (DioExceptionType.receiveTimeout, ApiErrorKind.receiveTimeout),
        (DioExceptionType.cancel, ApiErrorKind.cancelled),
        (DioExceptionType.badCertificate, ApiErrorKind.certificate),
        (DioExceptionType.unknown, ApiErrorKind.unknown),
      ]) {
        dioAdapter.onGet(
          'https://api.test.com/${type.name}',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(
                path: 'https://api.test.com/${type.name}',
              ),
              type: type,
            ),
          ),
        );
        try {
          await client.testGet('/${type.name}');
          fail('no failure for ${type.name}');
        } on ApiException catch (e) {
          expect(e.kind, kind, reason: type.name);
          expect(e.twitchMessage, isNull, reason: type.name);
        }
      }
    });
  });
}
