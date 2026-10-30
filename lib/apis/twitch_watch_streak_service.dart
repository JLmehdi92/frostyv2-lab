import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/models/watch_streak.dart';

/// Reads the viewer's watch streaks from Twitch's private GQL, with the
/// viewer's twitch.tv web token (Helix has no streaks).
///
/// Read only: sharing a streak in chat and "Save Streak" are writes and are
/// not done here. A streak is shown as Twitch counts it; this app sends no
/// watch events, so it never advances one.
///
/// Every failure (an integrity refusal, a changed schema, a token Twitch no
/// longer accepts, the network) answers null once; nothing retries.
class TwitchWatchStreakService extends BaseApiClient {
  TwitchWatchStreakService(Dio dio) : super(dio, '');

  /// The public web client-id twitch.tv itself uses (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const _gqlUrl = 'https://gql.twitch.tv/gql';

  static final _numericId = RegExp(r'^[0-9]{1,20}$');

  // The watch streak queries, trimmed to what is shown. Validated
  // anonymously on 2026-10-20.
  static const _milestoneQuery =
      'query WatchStreakMilestoneQuery(\$channelId: ID!) { '
      'channel(id: \$channelId) { self { watchStreakMilestone { '
      'watchStreakMilestone { id value shareStatus } watchStreakThreshold '
      'watchStreakCopoBonus state expiresAt } } } '
      'channelViewerMilestoneSettings(channelID: \$channelId) { id '
      'isWatchStreakOptOut } }';

  static const _batchQuery =
      'query BatchGetWatchStreaksQuery { batchGetWatchStreaks { '
      'channel { id } value isSuspended } }';

  /// The viewer's streak in the channel [channelId], or null.
  Future<WatchStreak?> getWatchStreak({
    required String channelId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || !_numericId.hasMatch(channelId)) return null;
    return WatchStreak.tryParse(
      await _ask('WatchStreakMilestoneQuery', _milestoneQuery, authToken, {
        'channelId': channelId,
      }),
    );
  }

  /// The viewer's running streaks by channel id, or null.
  Future<Map<String, int>?> getStreaks({required String authToken}) async {
    if (authToken.isEmpty) return null;
    return WatchStreak.parseBatch(
      await _ask('BatchGetWatchStreaksQuery', _batchQuery, authToken, null),
    );
  }

  Future<JsonMap?> _ask(
    String operation,
    String query,
    String authToken,
    Map<String, Object?>? variables,
  ) async {
    try {
      return await post<JsonMap>(
        _gqlUrl,
        headers: {
          'Client-ID': _gqlClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': operation,
          'query': query,
          'variables': ?variables,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Watch streaks unavailable: $e');
      return null;
    }
  }
}
