import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/twitch_web_token_service.dart';

const _channel = MethodChannel('frosty/cookies');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseAuthToken', () {
    const table = <String?, String?>{
      'auth-token=abc': 'abc',
      'a=1; auth-token=abc; b=2': 'abc',
      ' auth-token = abc ': 'abc',
      'auth-token=a=b': 'a=b',
      'xauth-token=abc': null,
      'auth-token-x=z; auth-token=abc': 'abc',
      'auth-token=': null,
      'api_token=x; twilight-user=y': null,
      'no separators here': null,
      '': null,
      null: null,
    };
    for (final MapEntry(:key, :value) in table.entries) {
      test('"$key" -> $value', () {
        expect(TwitchWebTokenService.parseAuthToken(key), value);
      });
    }
  });

  group('the native cookie jar', () {
    final calls = <MethodCall>[];

    void answer(Object? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return handler(call);
          });
    }

    setUp(calls.clear);
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );

    const android = TwitchWebTokenService(isAndroid: true);

    test('reads auth-token from the twitch.tv cookies', () async {
      answer((_) => 'unique_id=1; auth-token=tok; server_session_id=2');

      expect(await android.readAuthToken(), 'tok');
      expect(calls.single.method, 'getCookie');
      expect(calls.single.arguments, {'url': 'https://www.twitch.tv'});
    });

    test('an empty jar reads as no token', () async {
      answer((_) => null);

      expect(await android.readAuthToken(), isNull);
    });

    test('a platform error reads as no token', () async {
      answer((_) => throw PlatformException(code: 'bad_args'));

      expect(await android.readAuthToken(), isNull);
    });

    test('a build without the native side reads as no token', () async {
      // No handler at all: the channel throws MissingPluginException.
      expect(await android.readAuthToken(), isNull);
      await android.clearCookies();
    });

    test('clearCookies asks the native side to clear the jar', () async {
      answer((_) => null);

      await android.clearCookies();

      expect(calls.single.method, 'clearCookies');
    });

    test('a platform error while clearing is swallowed', () async {
      answer((_) => throw PlatformException(code: 'x'));

      await android.clearCookies();
    });

    test('off Android the channel is never called', () async {
      answer((_) => 'auth-token=tok');
      const other = TwitchWebTokenService(isAndroid: false);

      expect(await other.readAuthToken(), isNull);
      await other.clearCookies();

      expect(calls, isEmpty);
    });
  });
}
