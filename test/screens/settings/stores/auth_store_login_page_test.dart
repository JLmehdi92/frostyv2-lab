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
    // The launch, the reconnect loop and a pasted token ask checkToken; here
    // it answers as validateToken does (this app's token, or refused).
    when(() => api.checkToken(token: any(named: 'token'))).thenAnswer(
      (invocation) async =>
          await api.validateToken(
            token: invocation.namedArguments[#token] as String,
          )
          ? TokenCheck.valid
          : TokenCheck.invalid,
    );
    when(
      () => api.getUserInfo(token: any(named: 'token')),
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
      final logins = <Future<bool>>[];
      final decision = store.handleNavigation(
        request: request(redirect('abc', state: state)),
        onTokenCaptured: logins.add,
      );
      expect(decision, NavigationDecision.navigate);
      expect(logins, hasLength(1));
      // What it is given is this login's own outcome.
      expect(await logins.single, isTrue);
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
        final logins = <Future<bool>>[];
        store.handleNavigation(
          request: request(redirect('old', state: state)),
          onTokenCaptured: logins.add,
        );
        expect(await logins.single, isFalse);
        expect(store.isLoggedIn, isFalse);
      },
    );

    for (final (name, refuse) in [
      ('refused', () async => false),
      ('unverifiable', () async => throw Exception('network')),
    ]) {
      test('already logged in, a new login whose token is $name: its outcome '
          'is a failure although someone is logged in', () async {
        final logins = <Future<bool>>[];
        store.handleNavigation(
          request: request(
            redirect('first', state: stateOf(store.startAuthorization())),
          ),
          onTokenCaptured: logins.add,
        );
        expect(await logins.single, isTrue);
        expect(store.isLoggedIn, isTrue);

        when(
          () => api.validateToken(token: 'second'),
        ).thenAnswer((_) => refuse());
        logins.clear();
        store.handleNavigation(
          request: request(
            redirect('second', state: stateOf(store.startAuthorization())),
          ),
          onTokenCaptured: logins.add,
        );
        expect(await logins.single, isFalse);
      });
    }

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

      test('with the earlier state of the same page (it was opened again)', () {
        final attempt = store.beginLogin();
        final first = stateOf(store.authorizationUri(attempt));
        store.authorizationUri(attempt);
        var captured = 0;
        store.handleNavigation(
          request: request(redirect('attacker', state: first)),
          attempt: attempt,
          onTokenCaptured: (_) => captured++,
        );
        expect(captured, 0);
      });

      test('with the state of a login page that was closed', () {
        final attempt = store.beginLogin();
        final closed = stateOf(store.authorizationUri(attempt));
        store.endLogin(attempt);
        expectRefused(request(redirect('attacker', state: closed)));
      });
    });

    test('two login pages at once (the onboarding, and one opened over '
        'it): each takes its own token', () async {
      final onboarding = store.beginLogin();
      final onboardingState = stateOf(store.authorizationUri(onboarding));
      final overIt = store.beginLogin();
      final overItState = stateOf(store.authorizationUri(overIt));
      final captured = <String>[];

      // The page over it never takes the onboarding's token…
      store.handleNavigation(
        request: request(redirect('a', state: onboardingState)),
        attempt: overIt,
        onTokenCaptured: (_) => captured.add('over it'),
      );
      expect(captured, isEmpty);
      // …it is closed, and the onboarding's own login still goes through.
      store.endLogin(overIt);
      store.handleNavigation(
        request: request(redirect('abc', state: onboardingState)),
        attempt: onboarding,
        onTokenCaptured: (_) => captured.add('onboarding'),
      );
      expect(captured, ['onboarding']);
      expect(onboarding.captured, isTrue);
      expect(overIt.captured, isFalse);
      // The closed page's state is gone for good.
      store.handleNavigation(
        request: request(redirect('x', state: overItState)),
        onTokenCaptured: (_) => captured.add('closed'),
      );
      expect(captured, ['onboarding']);
      await pumpEventQueue();
    });

    test('signed in on twitch.tv after its token: told, once', () {
      final attempt = store.beginLogin();
      final state = stateOf(store.authorizationUri(attempt));
      store.handleNavigation(
        request: request(redirect('abc', state: state)),
        attempt: attempt,
      );
      var signedIn = 0;
      var notSignedIn = 0;
      void go(NavigationRequest request) => store.handleNavigation(
        request: request,
        attempt: attempt,
        onSignedIn: () => signedIn++,
        onNotSignedIn: () => notSignedIn++,
      );
      go(request('https://www.twitch.tv/?no-reload=true'));
      expect(signedIn, 1);
      go(request('https://www.twitch.tv/directory'));
      // A frame inside the page reaching that address is not the page.
      go(request('https://www.twitch.tv/?no-reload=true', mainFrame: false));
      expect(signedIn, 1);
      expect(notSignedIn, 0);
    });

    test('twitch.tv without a token for this page (the user said no): the '
        'page still moves on as before, told that nothing was taken', () {
      final attempt = store.beginLogin();
      store.authorizationUri(attempt);
      final order = <String>[];
      store.handleNavigation(
        request: request('https://www.twitch.tv/?no-reload=true'),
        attempt: attempt,
        onSignedIn: () => order.add('moved on'),
        onNotSignedIn: () => order.add('nothing taken'),
      );
      expect(order, ['nothing taken', 'moved on']);
      expect(attempt.captured, isFalse);
      verifyNever(() => api.validateToken(token: any(named: 'token')));
    });

    test('a closed page forgets its token: a late sign-in does not count', () {
      final attempt = store.beginLogin();
      final state = stateOf(store.authorizationUri(attempt));
      store.handleNavigation(
        request: request(redirect('abc', state: state)),
        attempt: attempt,
      );
      expect(attempt.captured, isTrue);
      store.endLogin(attempt);
      expect(attempt.captured, isFalse);
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
