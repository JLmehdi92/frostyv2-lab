import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';

/// The app token of a logged-out viewer comes from ONSET's token proxy
/// (tool/token_proxy/), which holds the Twitch client secret: the APK
/// carries none, and never asks Twitch for a token itself.
void main() {
  const proxy = 'https://onset-token.example.workers.dev';
  const endpoint = '$proxy/app-token';
  const token = 'abcdefghijklmnopqrstuvwxyz0123';
  const publicApp = 'publicappclientid0123456789ab';

  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> sent;

  setUp(() {
    dio = Dio(BaseOptions());
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
  });

  TwitchApi api([String url = proxy]) =>
      TwitchApi(dio, appClientId: 'app', tokenProxyUrl: url);

  test('reads the token the proxy hands out', () async {
    adapter.onGet(
      endpoint,
      (server) => server.reply(200, {
        'access_token': token,
        'expires_in': 5011271,
        'client_id': publicApp,
      }),
    );

    final appToken = await api().getDefaultToken();
    expect(appToken.token, token);
    expect(appToken.clientId, publicApp);
    expect(sent.single.uri.toString(), endpoint);
    expect(sent.single.method, 'GET');
  });

  test('a trailing slash on the proxy URL changes nothing', () async {
    adapter.onGet(
      endpoint,
      (server) =>
          server.reply(200, {'access_token': token, 'client_id': publicApp}),
    );

    expect((await api('$proxy/').getDefaultToken()).token, token);
    expect(sent.single.uri.toString(), endpoint);
  });

  test('a proxy URL with a port and a path is used as is', () async {
    adapter.onGet(
      'https://onset-token.example.dev:8443/base/app-token',
      (server) =>
          server.reply(200, {'access_token': token, 'client_id': publicApp}),
    );

    final appToken = await api(
      'https://onset-token.example.dev:8443/base',
    ).getDefaultToken();
    expect(appToken.token, token);
  });

  test('a redirect from the proxy is not followed', () async {
    adapter.onGet(
      endpoint,
      (server) => server.reply(
        302,
        null,
        headers: {
          'location': ['https://elsewhere.example/app-token'],
        },
      ),
    );

    await expectLater(api().getDefaultToken(), throwsA(isA<ApiException>()));
    expect(sent.single.followRedirects, isFalse);
  });

  test('the request is quiet and carries no session header', () async {
    adapter.onGet(
      endpoint,
      (server) =>
          server.reply(200, {'access_token': token, 'client_id': publicApp}),
    );

    await api().getDefaultToken();

    final request = sent.single;
    expect(request.extra[UnauthorizedInterceptor.quiet], isTrue);
    expect(request.extra[TwitchAuthInterceptor.noSessionHeaders], isTrue);
    expect(
      request.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test('no request ever names a client secret', () async {
    adapter.onGet(
      endpoint,
      (server) =>
          server.reply(200, {'access_token': token, 'client_id': publicApp}),
    );

    await api().getDefaultToken();
    for (final url in ['', 'http://x.example', proxy]) {
      try {
        await api(url).getDefaultToken();
      } on ApiException {
        // Refused or failed: what matters is what was sent.
      }
    }

    expect(sent, isNotEmpty);
    for (final request in sent) {
      final everything = [
        request.uri.toString(),
        request.headers.toString(),
        '${request.data}',
        request.queryParameters.toString(),
      ].join(' ');
      expect(everything, isNot(contains('secret')));
      expect(request.uri.host, isNot('id.twitch.tv'));
    }
  });

  group('refuses without a request', () {
    for (final url in [
      '',
      'http://onset-token.example.workers.dev',
      'onset-token.example.workers.dev',
      'https://',
      'https://user:pass@onset-token.example.workers.dev',
      'https://onset-token.example.workers.dev?next=1',
      'ftp://onset-token.example.workers.dev',
      'https://onset-token.example.workers.dev#x',
      'https://onset-token.example.workers.dev/a b',
      'https://onset-token.example.workers.dev/%2e%2e',
      'https://onset_token.example.workers.dev',
      ' https://onset-token.example.workers.dev',
    ]) {
      test('"$url"', () async {
        await expectLater(
          api(url).getDefaultToken(),
          throwsA(isA<ApiException>()),
        );
        expect(sent, isEmpty);
      });
    }
  });

  group('an answer that is not a token fails', () {
    for (final (name, body) in [
      ('no access_token', <String, Object?>{'token': token}),
      ('a number', <String, Object?>{'access_token': 12345}),
      ('an empty token', <String, Object?>{'access_token': ''}),
      ('a header injection', <String, Object?>{'access_token': 'abc\r\nX: 1'}),
      ('spaces', <String, Object?>{'access_token': 'abc def ghi jkl'}),
      ('an error object', <String, Object?>{'error': 'unavailable'}),
      ('no client id', <String, Object?>{'access_token': token}),
      (
        'a client id with spaces',
        <String, Object?>{'access_token': token, 'client_id': 'a b'},
      ),
      (
        'a client id that is a number',
        <String, Object?>{'access_token': token, 'client_id': 42},
      ),
      (
        'an empty client id',
        <String, Object?>{'access_token': token, 'client_id': ''},
      ),
    ]) {
      test(name, () async {
        adapter.onGet(endpoint, (server) => server.reply(200, body));

        await expectLater(
          api().getDefaultToken(),
          throwsA(isA<ApiException>()),
        );
      });
    }

    test('a page instead of JSON', () async {
      adapter.onGet(
        endpoint,
        (server) => server.reply(200, '<html>Worker threw</html>'),
      );

      await expectLater(api().getDefaultToken(), throwsA(isA<ApiException>()));
    });

    test('a JSON list', () async {
      adapter.onGet(
        endpoint,
        (server) => server.reply(200, [
          {'access_token': token, 'client_id': publicApp},
        ]),
      );

      await expectLater(api().getDefaultToken(), throwsA(isA<ApiException>()));
    });
  });

  for (final status in [429, 502, 500, 404]) {
    test('a $status from the proxy fails', () async {
      adapter.onGet(
        endpoint,
        (server) => server.reply(status, {'error': 'unavailable'}),
      );

      await expectLater(api().getDefaultToken(), throwsA(isA<ApiException>()));
    });
  }

  test('a proxy that does not answer in time fails quickly', () async {
    adapter.onGet(
      endpoint,
      (server) => server.reply(200, {
        'access_token': token,
        'client_id': publicApp,
      }, delay: const Duration(seconds: 5)),
    );

    final watch = Stopwatch()..start();
    await expectLater(
      api().getDefaultToken(timeout: const Duration(milliseconds: 100)),
      throwsA(isA<TimeoutException>()),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('the default deadline is short', () {
    expect(
      TwitchApi.appTokenTimeout,
      lessThanOrEqualTo(const Duration(seconds: 8)),
    );
  });
}
