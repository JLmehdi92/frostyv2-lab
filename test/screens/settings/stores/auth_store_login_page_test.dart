import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTwitchApi api;
  late AuthStore store;

  setUp(() {
    api = MockTwitchApi();
    final cookies = MockWebTokenService();
    FlutterSecureStorage.setMockInitialValues({});
    when(
      () => api.validateToken(token: any(named: 'token')),
    ).thenAnswer((_) async => true);
    when(
      () => api.getUserInfo(),
    ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(
      () => api.getUserBlockedList(id: any(named: 'id')),
    ).thenAnswer((_) async => []);
    when(() => cookies.readAuthToken()).thenAnswer((_) async => null);
    store = AuthStore(
      twitchApi: api,
      webTokenService: cookies,
      isAndroid: false,
    );
  });

  NavigationRequest request(String url) =>
      NavigationRequest(url: url, isMainFrame: true);

  group('the login page', () {
    test('the redirect with a token logs in and says so, without the '
        'token', () async {
      final logins = <Future<void>>[];
      final decision = store.handleNavigation(
        request: request('https://twitch.tv/login#access_token=abc&scope=x'),
        onTokenCaptured: logins.add,
      );
      expect(decision, NavigationDecision.navigate);
      expect(logins, hasLength(1));
      // What it is given is the login itself: once it ends, the store says
      // whether it worked.
      await logins.single;
      verify(() => api.validateToken(token: 'abc')).called(1);
      expect(store.isLoggedIn, isTrue);
    });

    test(
      'a token Twitch refuses: the login ends, nobody is logged in',
      () async {
        when(
          () => api.validateToken(token: any(named: 'token')),
        ).thenAnswer((_) async => false);
        final logins = <Future<void>>[];
        store.handleNavigation(
          request: request('https://twitch.tv/login#access_token=old&scope=x'),
          onTokenCaptured: logins.add,
        );
        await logins.single;
        expect(store.isLoggedIn, isFalse);
      },
    );

    test('a redirect without a token (the user said no) logs nobody in', () {
      var captured = 0;
      store.handleNavigation(
        request: request(
          'https://twitch.tv/login?error=access_denied&error_description=x',
        ),
        onTokenCaptured: (_) => captured++,
      );
      expect(captured, 0);
      verifyNever(() => api.validateToken(token: any(named: 'token')));
    });

    test('a token on another host is never taken', () {
      var captured = 0;
      for (final url in [
        'https://twitch.tv.example.com/login#access_token=abc',
        'https://example.com/?u=https://twitch.tv/login#access_token=abc',
        'http://twitch.tv/login#access_token=abc',
      ]) {
        store.handleNavigation(
          request: request(url),
          onTokenCaptured: (_) => captured++,
        );
      }
      expect(captured, 0);
      verifyNever(() => api.validateToken(token: any(named: 'token')));
    });

    test('signed in on twitch.tv: the onboarding is told, once', () {
      var signedIn = 0;
      store.handleNavigation(
        request: request('https://www.twitch.tv/?no-reload=true'),
        onSignedIn: () => signedIn++,
      );
      expect(signedIn, 1);
      store.handleNavigation(
        request: request('https://www.twitch.tv/directory'),
        onSignedIn: () => signedIn++,
      );
      expect(signedIn, 1);
    });

    test('opens the implicit grant with every scope, always confirmed', () {
      final uri = store.authorizeUri;
      expect(uri.scheme, 'https');
      expect(uri.host, 'id.twitch.tv');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['redirect_uri'], 'https://twitch.tv/login');
      expect(uri.queryParameters['response_type'], 'token');
      expect(uri.queryParameters['scope'], AuthBase.loginScopes);
      expect(uri.queryParameters['force_verify'], 'true');
      expect(uri.queryParameters.containsKey('client_id'), isTrue);
    });
  });
}
