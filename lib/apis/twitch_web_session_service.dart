import 'package:dio/dio.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/constants.dart';

/// Who a Twitch web session belongs to.
class WebSessionInfo {
  const WebSessionInfo({
    required this.login,
    required this.userId,
    required this.clientId,
  });

  final String login;
  final String userId;
  final String clientId;

  /// Made for twitch.tv itself (the only sessions its GQL accepts).
  bool get isWebSession => clientId == kTwitchWebClientId;
}

/// Checks the viewer's twitch.tv session (the `auth-token` cookie) with
/// Twitch, on a client that never carries the app's own Helix token.
class TwitchWebSessionService extends BaseApiClient {
  TwitchWebSessionService(Dio dio) : super(dio, '');

  /// Twitch's session tokens: lowercase letters and digits.
  static final tokenPattern = RegExp(r'^[a-z0-9]{20,64}$');

  /// The session behind [token], or null when Twitch says it is not valid
  /// (expired, revoked). Network trouble throws, so a session is never
  /// dropped for being offline.
  Future<WebSessionInfo?> validate(String token) async {
    if (!tokenPattern.hasMatch(token)) return null;
    try {
      final data = await get<JsonMap>(
        'https://id.twitch.tv/oauth2/validate',
        headers: {'Authorization': 'OAuth $token'},
      );
      final login = data['login'];
      final userId = data['user_id'];
      final clientId = data['client_id'];
      if (login is! String || userId is! String || clientId is! String) {
        return null;
      }
      return WebSessionInfo(login: login, userId: userId, clientId: clientId);
    } on UnauthorizedException {
      return null;
    }
  }
}
