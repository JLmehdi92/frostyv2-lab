import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Twitch as far as signing in goes, behind the real Dio interceptors:
/// `/oauth2/validate` says which app each token belongs to, and Helix
/// answers only a token sent with its own app's Client-Id (as Twitch does:
/// "Client ID and OAuth token do not match").
class FakeTwitchHttp implements HttpClientAdapter {
  FakeTwitchHttp(this.tokens);

  /// Each token's app client id and user id.
  final Map<String, ({String clientId, String userId})> tokens;

  /// Every request, in order.
  final requests = <RequestOptions>[];

  /// What ONSET's token proxy answers (any host but Twitch's), when set:
  /// its status and JSON body, after [proxyDelay].
  ({int status, Object body})? proxy;

  /// How long the token proxy takes to answer.
  Duration proxyDelay = Duration.zero;

  static String? _header(RequestOptions options, String name) {
    for (final MapEntry(:key, :value) in options.headers.entries) {
      if (key.toLowerCase() == name.toLowerCase()) return value?.toString();
    }
    return null;
  }

  static ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final uri = options.uri;
    if (uri.host != 'id.twitch.tv' && uri.host != 'api.twitch.tv') {
      final answer = proxy;
      if (answer == null) return _json({'message': 'not found'}, 404);
      await Future<void>.delayed(proxyDelay);
      return _json(answer.body, answer.status);
    }
    final bearer = _header(options, 'Authorization')?.split(' ').last;
    final token = tokens[bearer];
    if (uri.path == '/oauth2/validate') {
      if (token == null) return _json({'message': 'invalid'}, 401);
      return _json({
        'client_id': token.clientId,
        'login': 'user${token.userId}',
        'user_id': token.userId,
        'scopes': <String>[],
        'expires_in': 5000000,
      }, 200);
    }
    if (uri.path == '/oauth2/revoke') return _json({}, 200);
    if (uri.host == 'api.twitch.tv') {
      if (token == null || _header(options, 'Client-Id') != token.clientId) {
        return _json({
          'message': 'Client ID and OAuth token do not match',
        }, 401);
      }
      if (uri.path == '/helix/users') {
        return _json({
          'data': [
            {
              'id': token.userId,
              'login': 'user${token.userId}',
              'display_name': 'User ${token.userId}',
              'profile_image_url': '',
            },
          ],
        }, 200);
      }
      if (uri.path == '/helix/users/blocks') {
        return _json({'data': [], 'pagination': {}}, 200);
      }
      if (uri.path == '/helix/chat/emotes/global') {
        return _json({'data': [], 'template': ''}, 200);
      }
      // Needs a user token with a scope: refused whatever the token.
      if (uri.path == '/helix/whispers') {
        return _json({'message': 'Missing scope: user:manage:whispers'}, 401);
      }
    }
    return _json({'message': 'not found'}, 404);
  }

  @override
  void close({bool force = false}) {}
}
