import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';

class MockAuthStore extends Mock implements AuthStore {}

void main() {
  late MockAuthStore mockAuthStore;
  late TwitchAuthInterceptor interceptor;

  setUp(() {
    mockAuthStore = MockAuthStore();
    interceptor = TwitchAuthInterceptor(mockAuthStore);

    when(() => mockAuthStore.headersTwitch).thenReturn({
      'Authorization': 'Bearer test_token',
      'Client-Id': 'test_client_id',
    });
  });

  group('TwitchAuthInterceptor', () {
    test('adds headers for Twitch Helix API requests', () {
      final options = RequestOptions(path: 'https://api.twitch.tv/helix/users');

      final handler = RequestInterceptorHandler();

      // We test by calling onRequest and checking that headers were added
      interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer test_token');
      expect(options.headers['Client-Id'], 'test_client_id');
    });

    test('adds headers for Twitch OAuth requests', () {
      final options = RequestOptions(
        path: 'https://id.twitch.tv/oauth2/validate',
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer test_token');
      expect(options.headers['Client-Id'], 'test_client_id');
    });

    test('never replaces a token the request names itself (checking another '
        "token must check that one, not the session's)", () {
      final options = RequestOptions(
        path: 'https://id.twitch.tv/oauth2/validate',
        headers: {'Authorization': 'Bearer other_token'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], 'Bearer other_token');
      expect(options.headers['Client-Id'], 'test_client_id');
    });

    test('a request asking for none gets none (a twitch.tv web token is '
        "another app's: the app's Client-Id must not ride along)", () {
      final options = RequestOptions(
        path: 'https://id.twitch.tv/oauth2/validate',
        headers: {'Authorization': 'OAuth web_token'},
        extra: {TwitchAuthInterceptor.noSessionHeaders: true},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], 'OAuth web_token');
      expect(options.headers.containsKey('Client-Id'), isFalse);
    });

    test('does not add headers for BTTV API requests', () {
      final options = RequestOptions(
        path: 'https://api.betterttv.net/3/cached/emotes/global',
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Authorization'), isFalse);
      expect(options.headers.containsKey('Client-Id'), isFalse);
    });

    test('does not add headers for FFZ API requests', () {
      final options = RequestOptions(
        path: 'https://api.frankerfacez.com/v1/set/global',
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('does not add headers for 7TV API requests', () {
      final options = RequestOptions(
        path: 'https://7tv.io/v3/emote-sets/global',
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('does not add headers for other URLs', () {
      final options = RequestOptions(path: 'https://example.com/api/data');

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Authorization'), isFalse);
    });
  });
}
