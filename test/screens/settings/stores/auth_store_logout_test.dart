import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

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
}
