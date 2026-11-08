import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/resub_notification.dart';

class TwitchCommunityService extends BaseApiClient {
  TwitchCommunityService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _numericId = RegExp(r'^[0-9]{1,20}$');

  static const _resubNotificationQuery =
      'query ChannelResubNotificationQuery(\$channelId: ID!) { user(id: '
      '\$channelId) { login self { resubNotification { id months token '
      'isGiftSubscription gifter { login } } } } }';

  static const _leaderboardsQuery =
      'query ChannelLeaderboardsQuery(\$channelId: ID!, '
      '\$fetchChannelSettings: Boolean!) { user(id: \$channelId) { settings '
      '@include(if: \$fetchChannelSettings) { leaderboard { '
      'defaultLeaderboard isCheerEnabled isSubGiftEnabled isClipEnabled '
      'timePeriod } } channel { leaderboardSet { bits { __typename '
      '...UserLeaderboardFragment } subGift { __typename '
      '...UserLeaderboardFragment } clip { __typename '
      '...ClipLeaderboardFragment } } } } }  fragment '
      'UserLeaderboardItemFragment on UserLeaderboardItem { rank score user { '
      'id displayName } }  fragment UserLeaderboardFragment on '
      'UserLeaderboard { id items { edges { node { __typename '
      '...UserLeaderboardItemFragment } } } myPosition { __typename '
      '...UserLeaderboardItemFragment } }  fragment '
      'LeaderboardClipAssetMetadataFragment on ClipAsset { '
      'thumbnailURL(height: 45) curator { id displayName } }  fragment '
      'LeaderboardClipMetadataFragment on Clip { slug title assets { '
      '__typename ...LeaderboardClipAssetMetadataFragment } }  fragment '
      'ClipLeaderboardItemFragment on ClipLeaderboardItem { rank score clip { '
      '__typename ...LeaderboardClipMetadataFragment } }  fragment '
      'ClipLeaderboardFragment on ClipLeaderboard { id items { edges { node { '
      '__typename ...ClipLeaderboardItemFragment } } } myPosition { '
      '__typename ...ClipLeaderboardItemFragment } }';

  Future<ChannelLeaderboards?> getLeaderboards({
    required String channelId,
    String? authToken,
  }) async {
    if (!_numericId.hasMatch(channelId)) return null;
    return ChannelLeaderboards.tryParse(
      await _ask(
        'ChannelLeaderboardsQuery',
        _leaderboardsQuery,
        {'channelId': channelId, 'fetchChannelSettings': true},
        authToken: authToken,
      ),
    );
  }

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
