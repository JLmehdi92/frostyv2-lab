import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/twitch_tv_session.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchTvAuthService service;
  late List<RequestOptions> sent;
  var clock = DateTime.utc(2026, 11, 11, 12);

  setUp(() {
    clock = DateTime.utc(2026, 11, 11, 12);
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add(options);
          handler.next(options);
        },
      ),
    );
    service = TwitchTvAuthService(dio, now: () => clock);
  });

  TwitchTvDeviceCode code() => TwitchTvDeviceCode(
    deviceCode: 'dev-code',
    userCode: 'ABCDEFGH',
    interval: const Duration(seconds: 5),
    expiresAt: clock.add(const Duration(minutes: 30)),
  );

  void replyToken(int status, Object body) => adapter.onPost(
    TwitchTvAuthService.tokenUrl,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  group('device code', () {
    test('asks with the TV client id and the account scopes', () async {
      adapter.onPost(
        TwitchTvAuthService.deviceUrl,
        (server) => server.reply(200, {
          'device_code': 'dev-code',
          'expires_in': 1800,
          'interval': 5,
          'user_code': 'ABCDEFGH',
          'verification_uri':
              'https://www.twitch.tv/activate?public=true&device-code=ABCDEFGH',
        }),
        data: Matchers.any,
      );
      final result = await service.requestDeviceCode();
      expect(result, isNotNull);
      expect(result!.userCode, 'ABCDEFGH');
      expect(result.deviceCode, 'dev-code');
      expect(result.interval, const Duration(seconds: 5));
      expect(result.expiresAt, clock.add(const Duration(seconds: 1800)));
      expect(
        result.activationUri.toString(),
        'https://www.twitch.tv/activate?device-code=ABCDEFGH',
      );
      final request = sent.single;
      expect(request.contentType, Headers.formUrlEncodedContentType);
      final fields = request.data as Map;
      expect(fields['client_id'], kTwitchTvClientId);
      expect(
        fields['scopes'],
        'channel_read chat:read user_blocks_edit user_blocks_read '
        'user_follows_edit user_read',
      );
    });

    test('is null when Twitch refuses or answers nonsense', () async {
      adapter.onPost(
        TwitchTvAuthService.deviceUrl,
        (server) => server.reply(400, {'message': 'invalid client'}),
        data: Matchers.any,
      );
      expect(await service.requestDeviceCode(), isNull);
      adapter.onPost(
        TwitchTvAuthService.deviceUrl,
        (server) => server.reply(200, {'device_code': 'x'}),
        data: Matchers.any,
      );
      expect(await service.requestDeviceCode(), isNull);
    });

    test('is null on a network failure', () async {
      adapter.onPost(
        TwitchTvAuthService.deviceUrl,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );
      expect(await service.requestDeviceCode(), isNull);
    });

    test('rejects a user code that is not a short code', () {
      expect(
        TwitchTvDeviceCode.fromJson({
          'device_code': 'd',
          'user_code': 'a b<script>',
          'expires_in': 10,
        }, now: clock),
        isNull,
      );
    });
  });

  group('token poll', () {
    test('sends the device grant', () async {
      replyToken(400, {'status': 400, 'message': 'authorization_pending'});
      expect(await service.pollToken(code()), isA<TwitchTvPollPending>());
      final fields = sent.single.data as Map;
      expect(fields['grant_type'], TwitchTvAuthService.deviceGrantType);
      expect(fields['device_code'], 'dev-code');
      expect(fields['client_id'], kTwitchTvClientId);
    });

    test('reads slow_down', () async {
      replyToken(400, {'status': 400, 'message': 'slow_down'});
      expect(await service.pollToken(code()), isA<TwitchTvPollSlowDown>());
    });

    test('reads an expired or used code', () async {
      replyToken(400, {'status': 400, 'message': 'invalid device code'});
      expect(await service.pollToken(code()), isA<TwitchTvPollExpired>());
      replyToken(400, {'status': 400, 'message': 'expired_token'});
      expect(await service.pollToken(code()), isA<TwitchTvPollExpired>());
    });

    test('does not ask once the code is past its expiry', () async {
      final old = code();
      clock = old.expiresAt;
      expect(await service.pollToken(old), isA<TwitchTvPollExpired>());
      expect(sent, isEmpty);
    });

    test('reads a denial', () async {
      replyToken(400, {'status': 400, 'message': 'access_denied'});
      expect(await service.pollToken(code()), isA<TwitchTvPollDenied>());
    });

    test('returns the grant on success', () async {
      replyToken(200, {
        'access_token': 'tv-access',
        'refresh_token': 'tv-refresh',
        'expires_in': 14000,
        'token_type': 'bearer',
      });
      final poll = await service.pollToken(code());
      expect(poll, isA<TwitchTvPollGranted>());
      final grant = (poll as TwitchTvPollGranted).grant;
      expect(grant.accessToken, 'tv-access');
      expect(grant.refreshToken, 'tv-refresh');
      expect(grant.toString(), isNot(contains('tv-access')));
    });

    test('anything else is a failure', () async {
      replyToken(500, {'message': 'boom'});
      expect(await service.pollToken(code()), isA<TwitchTvPollFailed>());
      replyToken(200, {'nothing': true});
      expect(await service.pollToken(code()), isA<TwitchTvPollFailed>());
    });
  });

  group('refresh', () {
    test('sends the refresh grant with the TV client id', () async {
      replyToken(200, {'access_token': 'new', 'refresh_token': 'next'});
      final refresh = await service.refresh('old-refresh');
      expect(refresh.outcome, TwitchTvRefreshOutcome.granted);
      expect(refresh.grant!.accessToken, 'new');
      final fields = sent.single.data as Map;
      expect(fields['grant_type'], 'refresh_token');
      expect(fields['refresh_token'], 'old-refresh');
      expect(fields['client_id'], kTwitchTvClientId);
    });

    test('a refusal by Twitch is a rejection', () async {
      replyToken(400, {'message': 'Invalid refresh token'});
      expect(
        (await service.refresh('old-refresh')).outcome,
        TwitchTvRefreshOutcome.rejected,
      );
      replyToken(401, {'message': 'Unauthorized'});
      expect(
        (await service.refresh('old-refresh')).outcome,
        TwitchTvRefreshOutcome.rejected,
      );
    });

    test('a server error or no network is unreachable', () async {
      replyToken(503, {'message': 'down'});
      expect(
        (await service.refresh('old-refresh')).outcome,
        TwitchTvRefreshOutcome.unreachable,
      );
      adapter.onPost(
        TwitchTvAuthService.tokenUrl,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );
      expect(
        (await service.refresh('old-refresh')).outcome,
        TwitchTvRefreshOutcome.unreachable,
      );
    });
  });

  group('revoke', () {
    test('posts the token with the TV client id', () async {
      adapter.onPost(
        TwitchTvAuthService.revokeUrl,
        (server) => server.reply(200, null),
        data: Matchers.any,
      );
      await service.revoke('tv-access');
      final fields = sent.single.data as Map;
      expect(fields['client_id'], kTwitchTvClientId);
      expect(fields['token'], 'tv-access');
    });

    test('never throws', () async {
      adapter.onPost(
        TwitchTvAuthService.revokeUrl,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );
      await service.revoke('tv-access');
    });
  });

  group('validate', () {
    void replyValidate(int status, Object body) => adapter.onGet(
      TwitchTvAuthService.validateUrl,
      (server) => server.reply(status, body),
    );

    test('accepts a TV token and returns its user', () async {
      replyValidate(200, {
        'client_id': kTwitchTvClientId,
        'login': 'viewer',
        'user_id': '77',
        'scopes': <String>[],
      });
      final check = await service.validate('tv-access');
      expect(check.validity, TwitchTvValidity.valid);
      expect(check.userId, '77');
      expect(sent.single.headers['Authorization'], 'OAuth tv-access');
    });

    test('refuses a token of another client', () async {
      replyValidate(200, {'client_id': kTwitchWebClientId, 'user_id': '77'});
      expect((await service.validate('t')).validity, TwitchTvValidity.invalid);
    });

    test('a 401 is invalid, a 500 is unknown', () async {
      replyValidate(401, {'status': 401, 'message': 'invalid access token'});
      expect((await service.validate('t')).validity, TwitchTvValidity.invalid);
      replyValidate(500, {'message': 'boom'});
      expect((await service.validate('t')).validity, TwitchTvValidity.unknown);
    });
  });

  group('session storage form', () {
    test('round-trips and never prints the token', () {
      const session = TwitchTvSession(
        accessToken: 'secret-access',
        refreshToken: 'secret-refresh',
        userId: '77',
        deviceId: 'abcdef0123456789',
      );
      final back = TwitchTvSession.decode(session.encode())!;
      expect(back.accessToken, 'secret-access');
      expect(back.refreshToken, 'secret-refresh');
      expect(back.userId, '77');
      expect(back.deviceId, 'abcdef0123456789');
      expect(session.toString(), isNot(contains('secret')));
    });

    test('a damaged value reads as no session', () {
      expect(TwitchTvSession.decode('not json'), isNull);
      expect(TwitchTvSession.decode('{"access":"a"}'), isNull);
      expect(TwitchTvSession.decode(null), isNull);
    });
  });
}
