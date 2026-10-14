import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/unauthorized_interceptor.dart';

void main() {
  RequestOptions request(String url, {Map<String, Object?>? extra}) =>
      RequestOptions(path: url, extra: extra);

  test('a 401 asks to log in again by default', () {
    expect(
      UnauthorizedInterceptor.promptsLogin(
        request('https://api.twitch.tv/helix/moderation/bans'),
      ),
      isTrue,
    );
  });

  test('except token validation and requests marked quiet', () {
    expect(
      UnauthorizedInterceptor.promptsLogin(
        request('https://id.twitch.tv/oauth2/validate'),
      ),
      isFalse,
    );
    expect(
      UnauthorizedInterceptor.promptsLogin(
        request(
          'https://api.twitch.tv/helix/channels/followers',
          extra: {UnauthorizedInterceptor.quiet: true},
        ),
      ),
      isFalse,
    );
  });
}
