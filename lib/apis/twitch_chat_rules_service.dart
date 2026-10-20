import 'package:dio/dio.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/chat_rules.dart';

/// A GQL answer for chat rules that could not be read.
class ChatRulesApiException extends ApiException {
  const ChatRulesApiException(super.message);

  @override
  String toString() => 'ChatRulesApiException: $message';
}

/// A channel's chat rules from anonymous GQL: the public web Client-ID and
/// the official app's own `ChatRules` document, no user token. Verified
/// anonymously on 2026-10-20.
class TwitchChatRulesService extends BaseApiClient {
  TwitchChatRulesService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _channelId = RegExp(r'^[0-9]{1,20}$');

  static const _query =
      'query ChatRules(\$userID: ID!) { user(id: \$userID) { id displayName '
      'profileImageURL(width: 150) chatSettings { rules } } }';

  /// The rules of the channel [channelId], or null when there is no such
  /// channel. An answer without data throws.
  Future<ChatRules?> getRules(String channelId) async {
    if (!_channelId.hasMatch(channelId)) {
      throw ArgumentError.value(channelId, 'channelId', 'Not a channel id');
    }
    final Object? body = await post<dynamic>(
      _gqlUrl,
      headers: {'Client-ID': kTwitchWebClientId},
      data: {
        'operationName': 'ChatRules',
        'query': _query,
        'variables': {'userID': channelId},
      },
    );
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw const ChatRulesApiException('Malformed GQL response');
    }
    return ChatRules.fromGql(data['user']);
  }
}
