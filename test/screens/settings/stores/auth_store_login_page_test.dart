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

  NavigationRequest request(String url, {bool mainFrame = true}) =>
      NavigationRequest(url: url, isMainFrame: mainFrame);

  /// The redirect Twitch makes once the user authorized [state]'s attempt.
  String redirect(String token, {String? state}) =>
      'https://twitch.tv/login#access_token=$token&scope=chat%3Aread'
      '${state == null ? '' : '&state=$state'}&token_type=bearer';

  String stateOf(Uri authorize) => authorize.queryParameters['state']!;

  group('the login page', () {
    test('the redirect with the token and its state logs in, and says so '
        'without the token', () async {
      final state = stateOf(store.startAuthorization());
      final logins = <Future<void>>[];
      final decision = store.handleNavigation(
        request: request(redirect('abc', state: state)),
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
        final state = stateOf(store.startAuthorization());
        final logins = <Future<void>>[];
        store.handleNavigation(
          request: request(redirect('old', state: state)),
          onTokenCaptured: logins.add,
        );
        await logins.single;
        expect(store.isLoggedIn, isFalse);
      },
    );

    test('a redirect without a token (the user said no) logs nobody in', () {
      final state = stateOf(store.startAuthorization());
      var captured = 0;
      store.handleNavigation(
        request: request(
          'https://twitch.tv/login?error=access_denied&error_description=x'
          '&state=$state',
        ),
        onTokenCaptured: (_) => captured++,
      );
      expect(captured, 0);
      verifyNever(() => api.validateToken(token: any(named: 'token')));
    });

    group('an injected token is never taken', () {
      late String state;
      setUp(() => state = stateOf(store.startAuthorization()));

      void expectRefused(NavigationRequest request) {
        var captured = 0;
        store.handleNavigation(
          request: request,
          onTokenCaptured: (_) => captured++,
        );
        expect(captured, 0, reason: request.url);
      }

      test('without the state of the login the app opened', () {
        expectRefused(request(redirect('attacker')));
        verifyNever(() => api.validateToken(token: any(named: 'token')));
      });

      test('with another state', () {
        expectRefused(request(redirect('attacker', state: 'guessed')));
        expectRefused(request(redirect('attacker', state: '$state-')));
        expectRefused(request(redirect('attacker', state: '')));
        verifyNever(() => api.validateToken(token: any(named: 'token')));
      });

      test('from a frame inside the page', () {
        expectRefused(
          request(redirect('attacker', state: state), mainFrame: false),
        );
        verifyNever(() => api.validateToken(token: any(named: 'token')));
      });

      test('on any other address', () {
        for (final url in [
          'https://twitch.tv/loginX#access_token=attacker&state=$state',
          'https://twitch.tv/login/x#access_token=attacker&state=$state',
          'https://twitch.tv:8443/login#access_token=attacker&state=$state',
          'https://user@twitch.tv/login#access_token=attacker&state=$state',
          'https://www.twitch.tv/login#access_token=attacker&state=$state',
          'https://twitch.tv.example.com/login#access_token=abc&state=$state',
          'https://example.com/?u=https://twitch.tv/login#access_token=abc',
          'http://twitch.tv/login#access_token=abc&state=$state',
        ]) {
          expectRefused(request(url));
        }
        verifyNever(() => api.validateToken(token: any(named: 'token')));
      });

      test('twice with the same state (single use)', () async {
        var captured = 0;
        store.handleNavigation(
          request: request(redirect('abc', state: state)),
          onTokenCaptured: (_) => captured++,
        );
        expect(captured, 1);
        expectRefused(request(redirect('attacker', state: state)));
        await pumpEventQueue();
        verifyNever(() => api.validateToken(token: 'attacker'));
      });

      test('with the state of an earlier attempt', () {
        store.startAuthorization();
        expectRefused(request(redirect('attacker', state: state)));
      });
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
      // A frame inside the page reaching that address is not the page.
      store.handleNavigation(
        request: request(
          'https://www.twitch.tv/?no-reload=true',
          mainFrame: false,
        ),
        onSignedIn: () => signedIn++,
      );
      expect(signedIn, 1);
    });

    test('opens the implicit grant with every scope, always confirmed, '
        'with a fresh unguessable state each time', () {
      final uri = store.startAuthorization();
      expect(uri.scheme, 'https');
      expect(uri.host, 'id.twitch.tv');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['redirect_uri'], 'https://twitch.tv/login');
      expect(uri.queryParameters['response_type'], 'token');
      expect(uri.queryParameters['scope'], AuthBase.loginScopes);
      expect(uri.queryParameters['force_verify'], 'true');
      expect(uri.queryParameters.containsKey('client_id'), isTrue);
      final state = stateOf(uri);
      // 32 random bytes, base64url without padding.
      expect(state, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(stateOf(store.startAuthorization()), isNot(state));
    });
  });
}
