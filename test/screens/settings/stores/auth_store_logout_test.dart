import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/twitch_web_token_service.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockStorage extends Mock implements FlutterSecureStorage {}

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTwitchApi api;

  setUp(() {
    api = MockTwitchApi();
    FlutterSecureStorage.setMockInitialValues({
      'user_token': 'the_user_token',
      'default_token': 'the_default_token',
    });
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
  });

  test('logging out revokes the user token and forgets it', () async {
    when(
      () => api.revokeToken(token: any(named: 'token')),
    ).thenAnswer((_) async {});
    final store = AuthStore(twitchApi: api);

    await store.logout();

    verify(() => api.revokeToken(token: 'the_user_token')).called(1);
    expect(await const FlutterSecureStorage().read(key: 'user_token'), isNull);
  });

  test('a revoke that fails does not stop the logout', () async {
    when(
      () => api.revokeToken(token: any(named: 'token')),
    ).thenThrow(const ApiException('offline'));
    final store = AuthStore(twitchApi: api);

    await store.logout();
    await pumpEventQueue();

    expect(await const FlutterSecureStorage().read(key: 'user_token'), isNull);
  });

  test('an unreadable user token still clears the twitch.tv session', () async {
    final storage = MockStorage();
    final cookies = MockWebTokenService();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenThrow(Exception('keystore'));
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => cookies.clearCookies()).thenAnswer((_) async {});
    final store = AuthStore(
      twitchApi: api,
      storage: storage,
      webTokenService: cookies,
      isAndroid: true,
    );

    await store.logout();

    verify(() => cookies.clearCookies()).called(1);
    verify(() => storage.delete(key: 'twitch_web_token')).called(1);
    expect(store.twitchWebToken, isNull);
  });
}
