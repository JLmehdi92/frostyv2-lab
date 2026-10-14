import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_web_session_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/stores/web_session_store.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';

class MockService extends Mock implements TwitchWebSessionService {}

class MockUserStore extends Mock implements UserStore {}

class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore(this.user);

  @override
  final UserStore user;

  final _loggedIn = Observable(true);

  @override
  bool get isLoggedIn => _loggedIn.value;

  void logOut() => runInAction(() => _loggedIn.value = false);
}

const _token = 'abcdefghijklmnopqrstuvwxyz0123';
const _storage = FlutterSecureStorage();

WebSessionInfo info(String login, {String clientId = kTwitchWebClientId}) =>
    WebSessionInfo(login: login, userId: '42', clientId: clientId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockService service;
  late MockUserStore user;
  late FakeAuthStore auth;
  late WebSessionStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = MockService();
    user = MockUserStore();
    when(
      () => user.details,
    ).thenReturn(const UserTwitch('42', 'viewer', 'Viewer', ''));
    auth = FakeAuthStore(user);
    store = WebSessionStore(service: service, authStore: auth);
  });

  tearDown(() => store.dispose());

  group('authTokenFromCookies', () {
    test('finds the session among the cookies, quoted or not', () {
      expect(
        authTokenFromCookies('unique_id=x; auth-token=$_token; theme=1'),
        _token,
      );
      expect(authTokenFromCookies('"auth-token=$_token; a=b"'), _token);
    });

    test('nothing, or something odd, is no session', () {
      expect(authTokenFromCookies('unique_id=x'), isNull);
      expect(authTokenFromCookies('auth-token=<script>'), isNull);
      expect(authTokenFromCookies('"broken'), isNull);
      expect(authTokenFromCookies(''), isNull);
    });
  });

  test('the logged-in account\'s session is kept on the device', () async {
    when(
      () => service.validate(_token),
    ).thenAnswer((_) async => info('viewer'));

    expect(await store.connectFromCookies('auth-token=$_token'), isTrue);

    expect(store.isConnected, isTrue);
    expect(store.login, 'viewer');
    expect(store.token, _token);
    expect(await _storage.read(key: 'twitch_web_auth_token'), _token);
  });

  test('another account, or another app, is refused', () async {
    when(() => service.validate(_token)).thenAnswer((_) async => info('other'));
    expect(await store.connect(_token), isFalse);
    expect(store.error, contains('other'));
    expect(store.token, isNull);

    when(
      () => service.validate(_token),
    ).thenAnswer((_) async => info('viewer', clientId: 'app'));
    expect(await store.connect(_token), isFalse);
    expect(await _storage.read(key: 'twitch_web_auth_token'), isNull);
  });

  test('a saved session is checked at launch', () async {
    FlutterSecureStorage.setMockInitialValues({
      'twitch_web_auth_token': _token,
      'twitch_web_auth_login': 'viewer',
    });
    when(() => service.validate(_token)).thenAnswer((_) async => null);

    await store.init();

    expect(store.isConnected, isFalse);
    expect(await _storage.read(key: 'twitch_web_auth_token'), isNull);
  });

  test('offline at launch keeps the saved session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'twitch_web_auth_token': _token,
      'twitch_web_auth_login': 'viewer',
    });
    when(
      () => service.validate(_token),
    ).thenThrow(const ApiException('offline'));

    await store.init();

    expect(store.isConnected, isTrue);
    expect(store.token, _token);
  });

  test('logging out forgets the session', () async {
    when(
      () => service.validate(_token),
    ).thenAnswer((_) async => info('viewer'));
    await store.connect(_token);

    auth.logOut();
    await pumpEventQueue();

    expect(store.isConnected, isFalse);
    expect(store.token, isNull);
    expect(await _storage.read(key: 'twitch_web_auth_token'), isNull);
  });
}
