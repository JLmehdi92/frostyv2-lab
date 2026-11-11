import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/settings/account/twitch_tv_connect_sheet.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/widgets/twitch_web_page.dart';

import '../../../helpers/l10n.dart';

class _MockAuth extends Mock implements TwitchTvAuthService {}

final _code = TwitchTvDeviceCode(
  deviceCode: 'dev',
  userCode: 'WXYZ-ABCD',
  interval: const Duration(seconds: 5),
  expiresAt: DateTime.utc(2030),
);

void main() {
  late _MockAuth auth;
  late TwitchTvSessionStore store;
  late Completer<TwitchTvPoll> poll;
  late List<String> clipboard;

  setUpAll(() => registerFallbackValue(_code));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _MockAuth();
    poll = Completer<TwitchTvPoll>();
    clipboard = [];
    when(auth.requestDeviceCode).thenAnswer((_) async => _code);
    when(() => auth.pollToken(any())).thenAnswer((_) => poll.future);
    when(
      () => auth.validate(any()),
    ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
    store = TwitchTvSessionStore(auth: auth, wait: (_) async {});
    await store.attach('77');
    TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TwitchWebPage.debugBody = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSheet(
    WidgetTester tester, {
    Locale locale = en,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    poll = Completer<TwitchTvPoll>();
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showTwitchTvConnectSheet(context, store),
              child: const Text('…'),
            ),
          ),
        ),
      ),
      locale: locale,
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('…'));
    await settle(tester);
  }

  testWidgets('shows the code, copies it and opens the activation page', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('WXYZ-ABCD'), findsOneWidget);
    expect(find.text('Waiting for your approval on Twitch…'), findsOneWidget);

    await tester.tap(find.byKey(TwitchTvConnectSheet.copyKey));
    await settle(tester);
    expect(clipboard, ['WXYZ-ABCD']);
    expect(find.text('Code copied.'), findsOneWidget);

    await tester.tap(find.byKey(TwitchTvConnectSheet.openKey));
    await settle(tester);
    expect(find.byKey(const ValueKey('web')), findsOneWidget);
    final page = tester.widget<TwitchWebPage>(find.byType(TwitchWebPage));
    expect(
      page.url.toString(),
      'https://www.twitch.tv/activate?device-code=WXYZ-ABCD',
    );
  });

  testWidgets('an approval connects the session', (tester) async {
    when(
      () => auth.validate('tv-new'),
    ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
    await openSheet(tester);
    poll.complete(
      const TwitchTvPollGranted(TwitchTvGrant(accessToken: 'tv-new')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Twitch session connected. Account actions now go through it.'),
      findsOneWidget,
    );
    expect(store.status, TwitchTvSessionStatus.connected);
    await tester.tap(find.byKey(TwitchTvConnectSheet.doneKey));
    await tester.pumpAndSettle();
    expect(find.byType(TwitchTvConnectSheet), findsNothing);
  });

  testWidgets('an expired code offers a new one', (tester) async {
    await openSheet(tester);
    poll.complete(const TwitchTvPollExpired());
    await tester.pumpAndSettle();
    expect(
      find.text('This code expired. Get a new one to try again.'),
      findsOneWidget,
    );
    poll = Completer<TwitchTvPoll>();
    await tester.tap(find.byKey(TwitchTvConnectSheet.newCodeKey));
    await settle(tester);
    verify(auth.requestDeviceCode).called(2);
    expect(find.text('Waiting for your approval on Twitch…'), findsOneWidget);
  });

  testWidgets('no code from Twitch says so', (tester) async {
    when(auth.requestDeviceCode).thenAnswer((_) async => null);
    await openSheet(tester);
    expect(find.text('Couldn’t reach Twitch. Try again.'), findsOneWidget);
    expect(find.byKey(TwitchTvConnectSheet.newCodeKey), findsOneWidget);
  });

  testWidgets('closing the sheet stops polling and stores nothing', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    poll.complete(
      const TwitchTvPollGranted(TwitchTvGrant(accessToken: 'late')),
    );
    await tester.pumpAndSettle();
    expect(store.status, TwitchTvSessionStatus.disconnected);
    verifyNever(() => auth.validate('late'));
  });

  group('settings row', () {
    Future<void> pumpRow(WidgetTester tester, {Locale locale = en}) =>
        pumpLocalized(
          tester,
          SettingsScaffold(
            title: 'Account',
            body: SettingsGroupsView(
              children: [TwitchTvSessionGroup(store: store)],
            ),
          ),
          locale: locale,
        );

    testWidgets('shows the state and opens the sheet', (tester) async {
      await pumpRow(tester);
      expect(find.text('Twitch session'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      await tester.tap(find.byKey(TwitchTvSessionGroup.rowKey));
      await settle(tester);
      expect(find.byType(TwitchTvConnectSheet), findsOneWidget);
    });

    testWidgets('a connected session can be disconnected', (tester) async {
      await const FlutterSecureStorage().write(
        key: TwitchTvSessionBase.sessionKey,
        value: const TwitchTvSession(
          accessToken: 'tv',
          userId: '77',
          deviceId: 'device00device00',
        ).encode(),
      );
      store = TwitchTvSessionStore(auth: auth, wait: (_) async {});
      await store.attach('77');
      await pumpRow(tester);
      expect(find.text('Connected'), findsOneWidget);
      await tester.tap(find.byKey(TwitchTvSessionGroup.rowKey));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect the Twitch session?'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(find.text('Not connected'), findsOneWidget);
      expect(
        await const FlutterSecureStorage().read(
          key: TwitchTvSessionBase.sessionKey,
        ),
        isNull,
      );
    });
  });

  for (final locale in sweepLocales) {
    for (final (name, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets(
          'connect sheet${sweepName(locale)} at $name ×$scale reads whole',
          (tester) async {
            await openSheet(
              tester,
              locale: locale,
              size: size,
              textScale: scale,
            );
            await expectFrenchThroughout(
              tester,
              'connect sheet $name ×$scale',
              content: const ['WXYZ-ABCD'],
            );
            poll.complete(const TwitchTvPollDenied());
            await tester.pumpAndSettle();
            await expectFrenchThroughout(
              tester,
              'connect sheet denied $name ×$scale',
              content: const ['WXYZ-ABCD'],
            );
          },
        );
        testWidgets(
          'settings row${sweepName(locale)} at $name ×$scale reads whole',
          (tester) async {
            await pumpLocalized(
              tester,
              SettingsScaffold(
                title: 'Compte',
                body: SettingsGroupsView(
                  children: [TwitchTvSessionGroup(store: store)],
                ),
              ),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await expectFrenchThroughout(tester, 'settings row $name ×$scale');
          },
        );
      }
    }
  }
}
