import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_twitch_web_token.dart';
import 'package:onset/services/twitch_web_token_service.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

const _secret = 'secret-web-token';

void main() {
  late AuthStore auth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = AuthStore(twitchApi: MockTwitchApi(), isAndroid: false);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SettingsTwitchWebToken(authStore: auth)),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(SettingsTwitchWebToken));
    await tester.pumpAndSettle();
  }

  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  testWidgets('a stored token is never shown, only that one is set', (
    tester,
  ) async {
    await auth.setTwitchWebToken(_secret);
    await pump(tester);
    await open(tester);

    expect(find.textContaining(_secret), findsNothing);
    expect(field(tester).controller!.text, isEmpty);
    expect(field(tester).obscureText, isTrue);
    expect(find.text('A token is set.'), findsOneWidget);
  });

  testWidgets('the input is obscured when none is set', (tester) async {
    await pump(tester);
    await open(tester);

    expect(find.text('No token set.'), findsOneWidget);
    expect(field(tester).obscureText, isTrue);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('replace stores the new token, trimmed', (tester) async {
    await auth.setTwitchWebToken(_secret);
    await pump(tester);
    await open(tester);

    await tester.enterText(find.byType(TextField), '  fresh  ');
    await tester.pump();
    // The hint takes up to three lines (the test font's letters are wide):
    // the button may sit below the dialog's fold.
    await tester.ensureVisible(find.text('Replace'));
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(auth.twitchWebToken, 'fresh');
  });

  testWidgets('an empty field cannot replace the stored token', (tester) async {
    await auth.setTwitchWebToken(_secret);
    await pump(tester);
    await open(tester);

    // The hint takes up to three lines (the test font's letters are wide):
    // the button may sit below the dialog's fold.
    await tester.ensureVisible(find.text('Replace'));
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(auth.twitchWebToken, _secret);
  });

  testWidgets('clear forgets the token', (tester) async {
    await auth.setTwitchWebToken(_secret);
    await pump(tester);
    await open(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(auth.twitchWebToken, isNull);
    expect(find.byType(SettingsDialog), findsNothing);
  });

  testWidgets('the tile says whether a token is set', (tester) async {
    await pump(tester);
    expect(
      find.text('Not set — log in to pick it up automatically'),
      findsOneWidget,
    );

    await auth.setTwitchWebToken(_secret);
    await tester.pump();
    expect(find.textContaining('Active'), findsOneWidget);
    expect(find.textContaining(_secret), findsNothing);
  });

  testWidgets('an expired session asks for a new login', (tester) async {
    final android = AuthStore(
      twitchApi: MockTwitchApi(),
      isAndroid: true,
      webTokenService: _EmptyJar(),
    );
    await android.setTwitchWebToken(_secret);
    await android.harvestTwitchWebToken();
    auth = android;
    await pump(tester);

    expect(
      find.text('Twitch session expired — log in again to restore 2K'),
      findsOneWidget,
    );
  });
}

/// A cookie jar with nothing in it.
class _EmptyJar extends Fake implements TwitchWebTokenService {
  @override
  Future<String?> readAuthToken() async => null;
}
