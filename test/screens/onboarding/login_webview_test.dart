import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/onboarding/login_webview.dart';
import 'package:frosty/screens/onboarding/onboarding_parts.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockAuthStore extends Mock implements AuthStore {}

class MockWebViewController extends Mock implements WebViewController {}

void main() {
  late MockAuthStore auth;
  late MockWebViewController controller;
  ValueChanged<Uri>? onPage;
  ValueChanged<WebResourceError>? onError;
  ValueChanged<Future<void>>? onTokenCaptured;
  VoidCallback? onSignedIn;
  final authorize = Uri.parse(
    'https://id.twitch.tv/oauth2/authorize?client_id=x&force_verify=true',
  );

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    auth = MockAuthStore();
    controller = MockWebViewController();
    onPage = null;
    onError = null;
    onTokenCaptured = null;
    onSignedIn = null;
    when(() => auth.startAuthorization()).thenReturn(authorize);
    when(() => auth.isLoggedIn).thenReturn(false);
    when(
      () => auth.createAuthWebViewController(
        routeAfter: any(named: 'routeAfter'),
        onSignedIn: any(named: 'onSignedIn'),
        onTokenCaptured: any(named: 'onTokenCaptured'),
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
              as ValueChanged<Future<void>>?;
      onSignedIn = invocation.namedArguments[#onSignedIn] as VoidCallback?;
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
      expect(find.text('Connect with Twitch'), findsOneWidget);
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

  testWidgets('the login itself is the auth store\'s: it pops on success', (
    tester,
  ) async {
    await open(tester);
    // No onboarding callback: the store pops the page, as it always did.
    expect(onSignedIn, isNull);
    verify(
      () => auth.createAuthWebViewController(
        onTokenCaptured: any(named: 'onTokenCaptured'),
        onPage: any(named: 'onPage'),
        onError: any(named: 'onError'),
      ),
    ).called(1);
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

  testWidgets('the token is back: "Signing you in…" covers the page', (
    tester,
  ) async {
    await open(tester);
    onTokenCaptured!(Completer<void>().future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signing you in…'), findsOneWidget);
    // Twitch never finishing: the page shows again.
    await tester.pump(TwitchLoginPanel.signingInLimit);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signing you in…'), findsNothing);
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
    expect(find.text('Twitch could not be reached'), findsNothing);

    onError!(
      const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_INTERNET_DISCONNECTED',
        isForMainFrame: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Twitch could not be reached'), findsOneWidget);
    clearInteractions(controller);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A fresh attempt (a new state), never the old address again.
    verify(() => auth.startAuthorization()).called(1);
    verify(() => controller.loadRequest(authorize)).called(1);
    expect(find.text('Twitch could not be reached'), findsNothing);
  });

  testWidgets('a login that succeeds keeps "Signing you in…" until the '
      'page goes', (tester) async {
    await open(tester);
    when(() => auth.isLoggedIn).thenReturn(true);
    onTokenCaptured!(Future.value());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signing you in…'), findsOneWidget);
    expect(find.textContaining('did not sign you in'), findsNothing);
  });

  testWidgets('a login that fails shows the page again, and says so', (
    tester,
  ) async {
    await open(tester);
    final login = Completer<void>();
    onTokenCaptured!(login.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signing you in…'), findsOneWidget);
    login.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signing you in…'), findsNothing);
    expect(find.text('Twitch did not sign you in. Try again.'), findsOneWidget);
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
    expect(find.text('Twitch could not be reached'), findsOneWidget);
    // The failed page itself finishing (its error page) changes nothing.
    onPage!(Uri.parse('https://id.twitch.tv/failed'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Twitch could not be reached'), findsOneWidget);
    // The page Twitch moves on to clears it.
    onPage!(Uri.parse('https://id.twitch.tv/oauth2/authorize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Twitch could not be reached'), findsNothing);
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
    expect(find.text('Twitch could not be reached'), findsNothing);
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
      find.textContaining('go back, then open the login again.'),
      findsOneWidget,
    );
  });

  testWidgets('back leaves the page', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Connect with Twitch'), findsNothing);
  });
}
