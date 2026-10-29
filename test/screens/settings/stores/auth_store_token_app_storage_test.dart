import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

/// A keystore in memory that refuses to change some keys.
class FakeStorage extends Fake implements FlutterSecureStorage {
  FakeStorage(this.values);

  final Map<String, String> values;
  final refused = <String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (refused.contains(key)) throw Exception('keystore refused $key');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (refused.contains(key)) throw Exception('keystore refused $key');
    values.remove(key);
  }
}

/// The app a stored token was issued to is kept beside it: the two never
/// disagree, even when the keystore refuses one of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTwitchApi api;
  late MockWebTokenService cookies;

  setUp(() {
    api = MockTwitchApi();
    cookies = MockWebTokenService();
    when(() => api.validateToken(token: any(named: 'token'))).thenAnswer(
      (invocation) async => invocation.namedArguments[#token] == 'ours',
    );
    when(() => api.checkToken(token: any(named: 'token'))).thenAnswer(
      (invocation) async => invocation.namedArguments[#token] == 'foreign'
          ? const TokenCheck.foreign('other_app')
          : TokenCheck.valid,
    );
    when(
      () => api.getUserInfo(token: 'ours'),
    ).thenAnswer((_) async => const UserTwitch('2', 'two', 'Two', ''));
    when(
      () => api.getUserInfo(),
    ).thenAnswer((_) async => const UserTwitch('1', 'one', 'One', ''));
    when(
      () => api.getUserBlockedList(id: any(named: 'id')),
    ).thenAnswer((_) async => []);
    when(cookies.readAuthToken).thenAnswer((_) async => null);
  });

  AuthStore build(FlutterSecureStorage storage) => AuthStore(
    twitchApi: api,
    storage: storage,
    webTokenService: cookies,
    isAndroid: false,
  );

  test("a login whose token's app cannot be stored fails, and the stored "
      'session stays whole', () async {
    final storage = FakeStorage({
      'default_token': 'the_default_token',
      'user_token': 'foreign',
      'user_token_client_id': 'other_app',
    });
    final store = build(storage);
    await store.init();
    expect(store.headersTwitch['Client-Id'], 'other_app');
    storage.refused.add(AuthBase.userTokenClientIdKey);

    await store.login(token: 'ours');

    // Never this app's token beside the other app's id.
    expect(storage.values['user_token'], 'foreign');
    expect(storage.values['user_token_client_id'], 'other_app');
    expect(store.token, 'foreign');
    expect(store.headersTwitch['Client-Id'], 'other_app');
  });

  test(
    'a login rolled back puts back the stored app of the stored token',
    () async {
      final storage = FakeStorage({
        'default_token': 'the_default_token',
        'user_token': 'old',
        'user_token_client_id': 'kept_app',
        'user_id': '1',
        'twitch_web_token': 'web',
      });
      // The other account's web token cannot go: the login is undone.
      storage.refused.add('twitch_web_token');
      final store = build(storage);

      await store.login(token: 'ours');

      expect(store.isLoggedIn, isFalse);
      expect(storage.values['user_token'], 'old');
      expect(storage.values['user_token_client_id'], 'kept_app');
    },
  );
}
