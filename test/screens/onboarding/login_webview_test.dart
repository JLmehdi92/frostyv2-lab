import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/screens/onboarding/login_webview.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockWebViewController extends Mock implements WebViewController {}

void main() {
  late MockAuthStore auth;
  late MockWebViewController controller;
  ValueChanged<Uri>? onPage;
  ValueChanged<WebResourceError>? onError;
  ValueChanged<Future<bool>>? onTokenCaptured;
  VoidCallback? onSignedIn;
  VoidCallback? onNotSignedIn;

  setUpAll(() {
    registerFallbackValue(Future<Object?>.value());
    registerFallbackValue(Uri());
    registerFallbackValue(MockWebViewController());
  });

  setUp(() {
    auth = MockAuthStore();
    controller = MockWebViewController();
    onPage = null;
    onError = null;
    onTokenCaptured = null;
    onSignedIn = null;
    onNotSignedIn = null;
    when(
      () => controller.runJavaScriptReturningResult(any()),
    ).thenAnswer((_) async => '');
    when(() => auth.retryLogin(any())).thenAnswer((_) async {});
    when(() => auth.closeLogin(any())).thenReturn(null);
    when(() => auth.isLoggedIn).thenReturn(false);
    when(
      () => auth.harvestTwitchWebToken(pageCookies: any(named: 'pageCookies')),
    ).thenAnswer((_) async => true);
    when(
      () => auth.createAuthWebViewController(
        routeAfter: any(named: 'routeAfter'),
        onSignedIn: any(named: 'onSignedIn'),
        onTokenCaptured: any(named: 'onTokenCaptured'),
        onNotSignedIn: any(named: 'onNotSignedIn'),
        onPage: any(named: 'onPage'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((invocation) {
      onPage = invocation.namedArguments[#onPage] as ValueChanged<Uri>?;
      onError =
          invocation.namedArguments[#onError]
              as ValueChanged<WebResourceError>?;
      onTokenCaptured =
          invocation.namedArguments[#onTokenCaptured]
              as ValueChanged<Future<bool>>?;
      onSignedIn = invocation.namedArguments[#onSignedIn] as VoidCallback?;
      onNotSignedIn =
          invocation.namedArguments[#onNotSignedIn] as VoidCallback?;
      return controller;
    });
    when(() => controller.loadRequest(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      Provider<AuthStore>.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => LoginWebView(
                        pageBuilder: (_) =>
                            const ColoredBox(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await pump(tester, size: size);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final (name, size) in const [
    ('phone', Size(390, 844)),
    ('tablet', Size(1280, 854)),
    ('tablet portrait', Size(854, 1280)),
  ]) {
    testWidgets('$name: the bar, the host, the help', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Log in with Twitch'), findsOneWidget);
      expect(find.text('id.twitch.tv'), findsOneWidget);

      await tester.tap(find.byTooltip('Login help'));
      await tester.pumpAndSettle();
      expect(
        find.text('Workaround for the Twitch cookie banner'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        find.text('Workaround for the Twitch cookie banner'),
        findsNothing,
      );
    });
  }

  testWidgets('signed in on twitch.tv: the login page closes itself', (
    tester,
  ) async {
    await open(tester);
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Log in with Twitch'), findsNothing);
  });

  testWidgets('the user said no (no token): the page still closes, as '
      'before', (tester) async {
    await open(tester);
    onNotSignedIn!();
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    verifyNever(() => auth.retryLogin(any()));
  });

  testWidgets('a login that goes through does not close the page: Twitch\'s '
      'redirect does, after its cookie harvest', (tester) async {
    await open(tester);
    onTokenCaptured!(Future.value(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Still open: the WebView must reach twitch.tv for the 2K cookie.
    expect(find.text('Log in with Twitch'), findsOneWidget);
    expect(find.text('Logging you in…'), findsOneWidget);
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Log in with Twitch'), findsNothing);
  });

  testWidgets('Twitch\'s redirect while the login is in flight: it waits '
      'for it, then closes once', (tester) async {
    await open(tester);
    final login = Completer<bool>();
    onTokenCaptured!(login.future);
    await tester.pump();
    onSignedIn!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Log in with Twitch'), findsOneWidget);
    login.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Log in with Twitch'), findsNothing);
    // A late redirect does not close the page under it.
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('no redirect after a login that went through: after 20 s the '
      'cookie harvest is tried, then the page closes', (tester) async {
    await open(tester);
    onTokenCaptured!(Future.value(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(find.text('Log in with Twitch'), findsOneWidget);
    verifyNever(
      () => auth.harvestTwitchWebToken(pageCookies: any(named: 'pageCookies')),
    );
    await tester.pump(const Duration(seconds: 2));
    verify(
      () => auth.harvestTwitchWebToken(pageCookies: any(named: 'pageCookies')),
    ).called(1);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a cookie harvest that never answers: the page still closes '
      '5 s after the limit', (tester) async {
    await open(tester);
    when(
      () => auth.harvestTwitchWebToken(pageCookies: any(named: 'pageCookies')),
    ).thenAnswer((_) => Completer<bool>().future);
    onTokenCaptured!(Future.value(true));
    await tester.pump();
    await tester.pump(TwitchLoginPanel.signingInLimit);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Log in with Twitch'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('already logged in, a new login that fails: the failure shows '
      '(the old account is not taken for success), the page stays', (
    tester,
  ) async {
    await open(tester);
    when(() => auth.isLoggedIn).thenReturn(true);
    onTokenCaptured!(Future.value(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Twitch didn’t log you in. Try again.'), findsOneWidget);
    // Twitch's redirect still comes: the page stays with Try again.
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('Log in with Twitch'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
  });

  testWidgets('closed with Back while Twitch was signing in: only the login '
      'page goes, never the one under it', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 50));
    // The exit animation still runs: the page is mounted but closed.
    onSignedIn!();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a rebuild never reloads the page', (tester) async {
    await open(tester);
    tester.view.physicalSize = const Size(400, 844);
    await tester.pumpAndSettle();
    verify(
      () => auth.createAuthWebViewController(
        routeAfter: any(named: 'routeAfter'),
        onSignedIn: any(named: 'onSignedIn'),
        onTokenCaptured: any(named: 'onTokenCaptured'),
        onNotSignedIn: any(named: 'onNotSignedIn'),
        onPage: any(named: 'onPage'),
        onError: any(named: 'onError'),
      ),
    ).called(1);
  });

  testWidgets('the host follows the page, never the rest of the address', (
    tester,
  ) async {
    await open(tester);
    onPage!(Uri.parse('https://twitch.tv/login#access_token=secret_token'));
    await tester.pump();
    expect(find.text('twitch.tv'), findsOneWidget);
    expect(find.textContaining('secret_token'), findsNothing);
    expect(find.textContaining('access_token'), findsNothing);
  });

  testWidgets('the token is back: "Logging you in…" covers the page', (
    tester,
  ) async {
    await open(tester);
    onTokenCaptured!(Completer<bool>().future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging you in…'), findsOneWidget);
    // Twitch never finishing: the page shows again.
    await tester.pump(TwitchLoginPanel.signingInLimit);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging you in…'), findsNothing);
  });

  testWidgets('the page failing: what happened, and "Try again" reloads it', (
    tester,
  ) async {
    await open(tester);
    // A picture failing leaves the page usable.
    onError!(
      const WebResourceError(
        errorCode: -2,
        description: 'img',
        isForMainFrame: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsNothing);

    onError!(
      const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_INTERNET_DISCONNECTED',
        isForMainFrame: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    clearInteractions(controller);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A fresh attempt of this page's login (a new state), never the old
    // address again.
    verify(() => auth.retryLogin(controller)).called(1);
    expect(find.text('Couldn’t reach Twitch.'), findsNothing);
  });

  testWidgets('a login that succeeds keeps "Logging you in…" until the '
      'page goes', (tester) async {
    await open(tester);
    onTokenCaptured!(Future.value(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging you in…'), findsOneWidget);
    expect(find.textContaining('did not sign you in'), findsNothing);
  });

  testWidgets('a login that fails shows the page again, and says so', (
    tester,
  ) async {
    await open(tester);
    final login = Completer<bool>();
    onTokenCaptured!(login.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging you in…'), findsOneWidget);
    login.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging you in…'), findsNothing);
    expect(find.text('Twitch didn’t log you in. Try again.'), findsOneWidget);
  });

  testWidgets('a login that fails: the line offers Try again', (tester) async {
    await open(tester);
    onTokenCaptured!(Future.value(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Twitch didn’t log you in. Try again.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pump();
    verify(() => auth.retryLogin(controller)).called(1);
    expect(find.text('Twitch didn’t log you in. Try again.'), findsNothing);
  });

  testWidgets('a reload that fails: the card stays until another page', (
    tester,
  ) async {
    await open(tester);
    onPage!(Uri.parse('https://id.twitch.tv/oauth2/authorize?x=1'));
    onError!(
      const WebResourceError(
        errorCode: -2,
        description: 'offline',
        isForMainFrame: true,
        url: 'https://id.twitch.tv/earlier',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    when(
      () => auth.retryLogin(any()),
    ).thenAnswer((_) => Future.error(Exception('no network')));
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    // The page it was on is not "another page".
    onPage!(Uri.parse('https://id.twitch.tv/oauth2/authorize?x=1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
  });

  testWidgets('closing the page closes its login', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    verify(() => auth.closeLogin(controller)).called(1);
  });

  testWidgets('iOS not naming the failed page: it is the one that was '
      'loading', (tester) async {
    await open(tester);
    onPage!(Uri.parse('https://id.twitch.tv/oauth2/authorize?x=1'));
    await tester.pump();
    onError!(
      const WebResourceError(
        errorCode: -1009,
        description: 'offline',
        isForMainFrame: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    // The same page again (a fragment, the host's case) is not another one.
    onPage!(Uri.parse('https://ID.twitch.tv/oauth2/authorize?x=1#top'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    onPage!(Uri.parse('https://www.twitch.tv/'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsNothing);
  });

  testWidgets('the failure clears once another page loads', (tester) async {
    await open(tester);
    onError!(
      const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
        url: 'https://id.twitch.tv/failed',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    // The failed page itself finishing (its error page) changes nothing.
    onPage!(Uri.parse('https://id.twitch.tv/failed'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsOneWidget);
    // The page Twitch moves on to clears it.
    onPage!(Uri.parse('https://id.twitch.tv/oauth2/authorize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsNothing);
  });

  testWidgets('the lock only for https; a page without host shows no host', (
    tester,
  ) async {
    await open(tester);
    final lock = find.byWidgetPredicate(
      (w) => w is OnboardingGlyph && w.kind == OnboardingGlyphKind.lock,
    );
    expect(lock, findsOneWidget);

    onPage!(Uri.parse('http://twitch.example/login'));
    await tester.pump();
    expect(find.text('http://twitch.example'), findsOneWidget);
    expect(lock, findsNothing);

    onPage!(Uri.parse('about:blank'));
    await tester.pump();
    expect(find.text('twitch.example'), findsNothing);
    expect(find.text('http://twitch.example'), findsNothing);
    expect(find.text('about:'), findsOneWidget);
    expect(lock, findsNothing);

    onPage!(Uri.parse('https://id.twitch.tv/x?state=s3cret#access_token=t'));
    await tester.pump();
    expect(find.text('id.twitch.tv'), findsOneWidget);
    expect(find.textContaining('s3cret'), findsNothing);
    expect(lock, findsOneWidget);
  });

  testWidgets('a navigation replaced by another is no failure (iOS)', (
    tester,
  ) async {
    await open(tester);
    for (final code in [-999, 102]) {
      onError!(
        WebResourceError(
          errorCode: code,
          description: 'cancelled',
          isForMainFrame: true,
        ),
      );
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Couldn’t reach Twitch.'), findsNothing);
  });

  testWidgets('the page shrinks above the keyboard', (tester) async {
    await open(tester);
    final page = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == const Color(0xFFFFFFFF),
    );
    expect(tester.getRect(page).bottom, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getRect(page).bottom, 844 - 300);
  });

  testWidgets('the help does not send back to an onboarding', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Login help'));
    await tester.pumpAndSettle();
    expect(find.textContaining('first step of the onboarding'), findsNothing);
    expect(
      find.textContaining('go back and open the login page again.'),
      findsOneWidget,
    );
  });

  testWidgets('back leaves the page', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Log in with Twitch'), findsNothing);
  });
}
