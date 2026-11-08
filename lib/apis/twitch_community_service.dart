import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/resub_notification.dart';

class TwitchCommunityService extends BaseApiClient {
  TwitchCommunityService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _numericId = RegExp(r'^[0-9]{1,20}$');

  static const _resubNotificationQuery =
      'query ChannelResubNotificationQuery(\$channelId: ID!) { user(id: '
      '\$channelId) { login self { resubNotification { id months token '
      'isGiftSubscription gifter { login } } } } }';

  Future<ResubNotification?> getResubNotification({
    required String channelId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || !_numericId.hasMatch(channelId)) return null;
    return ResubNotification.tryParse(
      await _ask(
        'ChannelResubNotificationQuery',
        _resubNotificationQuery,
        {'channelId': channelId},
        authToken: authToken,
      ),
    );
  }

  Future<Object?> _ask(
    String operation,
    String query,
    Map<String, Object?> variables, {
    String? authToken,
  }) async {
    try {
      return await post<dynamic>(
        _gqlUrl,
        headers: {
          'Client-ID': kTwitchWebClientId,
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': operation,
          'query': query,
          'variables': variables,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('$operation unavailable: $e');
      return null;
    }
  }
}
