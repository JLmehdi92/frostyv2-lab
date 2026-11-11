import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/settings/account/twitch_tv_connect_sheet.dart';
import 'package:onset/screens/settings/account/twitch_tv_login_offer.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/widgets/follow/follow_flow.dart';

import '../../../helpers/l10n.dart';

class _MockAuth extends Mock implements TwitchTvAuthService {}

const _storage = FlutterSecureStorage();

const _offerBody =
    'With a Twitch session, ONSET can follow, claim points, open chests, and '
    'make predictions without going through Twitch’s anti-bot check. It only '
    'takes a code from Twitch.';

void main() {
  late _MockAuth auth;
  late String? viewer;
  late TwitchTvSessionStore store;
  late TwitchTvLoginOffer offer;
  late int logins;
  BuildContext? navigatorContext;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _MockAuth();
    viewer = null;
    navigatorContext = null;
    logins = 0;
    when(
      () => auth.validate(any()),
    ).thenAnswer((_) async => TwitchTvValidation.valid(viewer ?? ''));
    when(() => auth.revoke(any())).thenAnswer((_) async {});
    when(auth.requestDeviceCode).thenAnswer((_) async => null);
    store = TwitchTvSessionStore(auth: auth, viewerId: () => viewer);
    offer = TwitchTvLoginOffer(
      store: store,
      context: () => navigatorContext,
      logins: () => logins,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpLocalized(tester, const Scaffold(), locale: en);
    navigatorContext = tester
        .state<NavigatorState>(find.byType(Navigator))
        .context;
  }

  Future<void> storeSession(String user) => _storage.write(
    key: TwitchTvSessionBase.sessionKey,
    value: TwitchTvSession(
      accessToken: 'tv-$user',
      refreshToken: 'r',
      userId: user,
      deviceId: 'device00device00',
    ).encode(),
  );

  Future<void> account(WidgetTester tester, String? id) async {
    viewer = id;
    await tester.runAsync(() => offer.accountChanged(id));
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester, String id) async {
    logins++;
    await account(tester, id);
  }

  testWidgets('a restored account at launch is not offered a session', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, '77');
    expect(find.text(_offerBody), findsNothing);
    expect(store.status, TwitchTvSessionStatus.disconnected);
  });

  testWidgets('a fresh login is offered a session, and Connect opens the '
      'sheet', (tester) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    expect(find.text('Connect a Twitch session?'), findsOneWidget);
    expect(find.text(_offerBody), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(await store.shouldPrompt(), isFalse);

    await tester.tap(find.byKey(FollowFlow.tvConnectKey));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(TwitchTvConnectSheet), findsOneWidget);
  });

  testWidgets('Later closes the offer and consumes the one-time prompt', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text(_offerBody), findsNothing);
    expect(find.byType(TwitchTvConnectSheet), findsNothing);
    expect(await store.shouldPrompt(), isFalse);
  });

  testWidgets('no offer when the account already has a valid session', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, null);
    await storeSession('77');
    await login(tester, '77');
    expect(store.status, TwitchTvSessionStatus.connected);
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('logging in again to an account that said Later is not '
      'offered again', (tester) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await account(tester, null);
    await login(tester, '77');
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('a logout clears the flag, so the next login is offered', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.runAsync(store.endAccountSession);
    await account(tester, null);
    await login(tester, '77');
    expect(find.text(_offerBody), findsOneWidget);
  });

  testWidgets('switching to another account without a session offers again', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, '77');
    await tester.runAsync(store.markPrompted);
    await login(tester, '99');
    expect(find.text(_offerBody), findsOneWidget);
  });

  testWidgets('switching to another account that has a session does not '
      'offer', (tester) async {
    await pump(tester);
    await account(tester, '77');
    await storeSession('99');
    await login(tester, '99');
    expect(store.status, TwitchTvSessionStatus.connected);
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('a logout detaches the session and offers nothing', (
    tester,
  ) async {
    await pump(tester);
    await storeSession('77');
    await account(tester, '77');
    expect(store.status, TwitchTvSessionStatus.connected);
    await account(tester, null);
    expect(store.status, TwitchTvSessionStatus.disconnected);
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('no offer without a navigator', (tester) async {
    await pump(tester);
    navigatorContext = null;
    logins = 0;
    await account(tester, null);
    await login(tester, '77');
    expect(find.text(_offerBody), findsNothing);
    expect(await store.shouldPrompt(), isTrue);
  });

  testWidgets('a reconnect after a logged-out launch is not a login', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, null);
    await account(tester, '1');
    expect(find.text(_offerBody), findsNothing);
    expect(await store.shouldPrompt(), isTrue);
  });

  testWidgets('a fast logout and login never stack two offers', (tester) async {
    await pump(tester);
    await account(tester, null);
    logins += 2;
    viewer = '77';
    await tester.runAsync(
      () => Future.wait([
        offer.accountChanged('77'),
        offer.accountChanged(null),
        offer.accountChanged('77'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text(_offerBody), findsOneWidget);
  });

  testWidgets('a logout closes the open offer', (tester) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    expect(find.text(_offerBody), findsOneWidget);
    await account(tester, null);
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('another account closes the open offer', (tester) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    await storeSession('99');
    await account(tester, '99');
    expect(find.text(_offerBody), findsNothing);
  });

  testWidgets('Connect opens nothing once the store has no account', (
    tester,
  ) async {
    await pump(tester);
    await account(tester, null);
    await login(tester, '77');
    store.detach();
    await tester.tap(find.byKey(FollowFlow.tvConnectKey));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(TwitchTvConnectSheet), findsNothing);
  });

  for (final locale in sweepLocales) {
    for (final (name, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets(
          'login offer${sweepName(locale)} at $name ×$scale reads whole',
          (tester) async {
            await pumpLocalized(
              tester,
              const Scaffold(),
              locale: locale,
              size: size,
              textScale: scale,
            );
            navigatorContext = tester
                .state<NavigatorState>(find.byType(Navigator))
                .context;
            await account(tester, null);
            await login(tester, '77');
            expect(find.byKey(FollowFlow.tvConnectKey), findsOneWidget);
            await expectFrenchThroughout(tester, 'login offer $name ×$scale');
          },
        );
      }
    }
  }
}
