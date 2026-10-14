import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_web_session_service.dart';
import 'package:frosty/constants.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _validate = 'https://id.twitch.tv/oauth2/validate';
const _token = 'abcdefghijklmnopqrstuvwxyz0123';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchWebSessionService service;
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
    service = TwitchWebSessionService(dio);
  });

  test('a twitch.tv session names its account', () async {
    adapter.onGet(
      _validate,
      (s) => s.reply(200, {
        'client_id': kTwitchWebClientId,
        'login': 'viewer',
        'user_id': '42',
        'scopes': <String>[],
        'expires_in': 5000000,
      }),
    );

    final info = (await service.validate(_token))!;

    expect(info.login, 'viewer');
    expect(info.userId, '42');
    expect(info.isWebSession, isTrue);
    expect(requests.single.headers['Authorization'], 'OAuth $_token');
  });

  test('a session of another app is not a twitch.tv session', () async {
    adapter.onGet(
      _validate,
      (s) => s.reply(200, {
        'client_id': 'someotherapp',
        'login': 'viewer',
        'user_id': '42',
      }),
    );
    expect((await service.validate(_token))!.isWebSession, isFalse);
  });

  test('an expired session is null; trouble reaching Twitch throws', () async {
    adapter.onGet(_validate, (s) => s.reply(401, {'message': 'invalid'}));
    expect(await service.validate(_token), isNull);

    adapter.onGet(_validate, (s) => s.reply(500, null));
    await expectLater(service.validate(_token), throwsA(isA<ApiException>()));
  });

  test('something that is not a token is never sent', () async {
    for (final bad in ['', 'short', 'UPPERCASEUPPERCASEUPPERCASE', 'a b c']) {
      expect(await service.validate(bad), isNull, reason: bad);
    }
    expect(requests, isEmpty);
  });
}
