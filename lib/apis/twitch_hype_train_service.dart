import 'package:dio/dio.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';

/// A GQL error answered for a hype train request.
class HypeTrainApiException extends ApiException {
  const HypeTrainApiException(super.message, {this.isIntegrity = false});

  /// Twitch asked for a client-integrity token.
  final bool isIntegrity;

  @override
  String toString() => 'HypeTrainApiException: $message';
}

/// The channel's hype train as GQL reports it right now.
sealed class HypeTrainSnapshot {
  const HypeTrainSnapshot();
}

final class HtNoTrain extends HypeTrainSnapshot {
  const HtNoTrain();
}

final class HtApproachingSnapshot extends HypeTrainSnapshot {
  const HtApproachingSnapshot(this.approaching);

  final HypeTrainApproaching approaching;
}

final class HtOngoingSnapshot extends HypeTrainSnapshot {
  const HtOngoingSnapshot(this.train, {required this.fetchedAt});

  final HypeTrainExecution train;

  /// Local time of the answer, to age `remainingSeconds`.
  final DateTime fetchedAt;
}

/// Hype trains from Twitch GQL, anonymously (public web Client-ID and full
/// query documents, no user token). Realtime updates come from Hermes; this
/// is the snapshot taken on join, on resubscribe and while realtime is down.
class TwitchHypeTrainService extends BaseApiClient {
  TwitchHypeTrainService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _channelId = RegExp(r'^[0-9]{1,20}$');

  static const _reward =
      'id type ... on HypeTrainEmoteReward { emote { id token } } '
      '... on HypeTrainBadgeReward { badge { id setID '
      'imageURL(size: DOUBLE) } }';

  static const _conductor =
      'source participation { source action quantity } '
      'user { id displayName login profileImageURL(width: 150) }';

  /// Verified against live trains (2026-10-13). `difficultySettings.levels`
  /// (hundreds of levels) is left out: upcoming rewards have their own
  /// lazy document.
  static const _executionQuery =
      'query GetHypeTrainExecution(\$channelId: ID!, '
      '\$includeSharedHypeTrain: Boolean!) { user(id: \$channelId) { id '
      'channel { id hypeTrain { execution { id isActive isFastMode startedAt '
      'expiresAt updatedAt endedAt endReason progress { ...P } '
      'conductors { $_conductor } '
      'config { id difficulty isEnabled '
      'difficultySettings { difficulty maxLevel } kickoff { minPoints } '
      'conductorRewards { source type rewards { $_reward } } '
      'participationConversionRates { action source value } '
      'calloutEmote { id token } willUseCreatorColor primaryHexColor } '
      'allTimeHigh { ...C } isGoldenKappaTrain isTreasureTrain '
      'treasureTrainDetails { discountPercentage discountLevelThreshold '
      'status } '
      'variantTrainDetails { __typename ... on CommunityTrainDetails { '
      'currentRewardAmount nextRewardAmount previousRewardAmount '
      'rewardLevelThreshold maxRewardLevel status } ... on MythicTrainDetails { '
      'selectedEmote { id token } emotePool { id token } } } '
      'sharedHypeTrainDetails @include(if: \$includeSharedHypeTrain) { id '
      'sharedConductors { user { ...U } conductors { $_conductor } } '
      'sharedProgress { user { ...U } channelProgress { ...P } } '
      'sharedAllTimeHighRecords { user { ...U } '
      'channelAllTimeHigh { ...C } } } } '
      'approaching { id goal creatorColor participants '
      'eventsRemaining { events secondsRemaining } '
      'levelOneRewards { $_reward } isGoldenKappaTrain isTreasureTrain '
      'hypeTrainType } } } } } '
      'fragment L on HypeTrainLevel { id value goal rewards { $_reward } } '
      'fragment P on HypeTrainProgress { level { ...L } goal progression '
      'total remainingSeconds allTimeHighState } '
      'fragment C on HypeTrainCompleted { level { id value } goal '
      'progression total } '
      'fragment U on User { id displayName login '
      'profileImageURL(width: 150) }';

  static const _rewardsQuery =
      'query GetHypeTrainRewards(\$channelId: ID!) { user(id: \$channelId) { '
      'id channel { id hypeTrain { execution { id config { '
      'potentialRewards { id level value { $_reward } } } } } } } }';

  static const _statusesQuery =
      'query HypeTrainStatuses(\$channelIds: [ID!]!) { '
      'allActiveHypeTrainStatuses(channelIDs: \$channelIds) { channel { id } '
      'level isAllTimeHighTrain isSharedTrain hypeTrainType } }';

  static const _statusesChunk = 100;

  /// The running trains among [channelIds] (stream card pills), by channel
  /// id. Never throws: channels that fail are simply missing.
  Future<Map<String, HtCardStatus>> getActiveStatuses(
    List<String> channelIds,
  ) async {
    final ids = [
      for (final id in channelIds.toSet())
        if (_channelId.hasMatch(id)) id,
    ];
    final result = <String, HtCardStatus>{};
    for (var i = 0; i < ids.length; i += _statusesChunk) {
      final chunk = ids.sublist(
        i,
        i + _statusesChunk > ids.length ? ids.length : i + _statusesChunk,
      );
      try {
        final data = await _gql('HypeTrainStatuses', _statusesQuery, {
          'channelIds': chunk,
        });
        for (final item in htList(data, ['allActiveHypeTrainStatuses'])) {
          if (item is! Map) continue;
          final id = htString(htMap(item, ['channel']), ['id']);
          final level = htInt(item, ['level']);
          if (id == null || level == null || level < 1) continue;
          result[id] = HtCardStatus(
            level: level,
            variant: htVariantOf(item),
            isShared: htBool(item, ['isSharedTrain']),
            isAllTimeHigh: htBool(item, ['isAllTimeHighTrain']),
          );
        }
      } on Object {
        // Card pills are a nicety: a failed chunk shows none.
      }
    }
    return result;
  }

  /// [raw] trimmed, if it is a Twitch user id; [ArgumentError] otherwise.
  static String normalizeChannelId(String raw) {
    final id = raw.trim();
    if (!_channelId.hasMatch(id)) {
      throw ArgumentError.value(raw, 'channelId', 'Not a Twitch user id');
    }
    return id;
  }

  /// The channel's running or approaching train.
  ///
  /// Throws [HypeTrainApiException] for GQL errors and [ApiException] for
  /// transport failures.
  Future<HypeTrainSnapshot> getHypeTrain(String channelId) async {
    final id = normalizeChannelId(channelId);
    final data = await _gql('GetHypeTrainExecution', _executionQuery, {
      'channelId': id,
      'includeSharedHypeTrain': true,
    });
    try {
      return _snapshot(data);
    } on Object catch (e) {
      // Parsing never throws by design; this keeps the contract if it does.
      throw HypeTrainApiException('Malformed hype train: $e');
    }
  }

  static HypeTrainSnapshot _snapshot(JsonMap data) {
    final hypeTrain = _path(data, ['user', 'channel', 'hypeTrain']);
    if (hypeTrain == null) return const HtNoTrain();
    final execution = htMap(hypeTrain, ['execution']);
    if (execution != null && htBool(execution, ['isActive'])) {
      final train = HypeTrainExecution.parse(execution);
      if (train != null) {
        return HtOngoingSnapshot(train, fetchedAt: DateTime.now());
      }
    }
    final approaching = HypeTrainApproaching.parse(
      htMap(hypeTrain, ['approaching']),
    );
    if (approaching != null) return HtApproachingSnapshot(approaching);
    return const HtNoTrain();
  }

  /// Every emote of the running train's levels (unlocked ones included),
  /// grouped by level in level order. Never throws: empty when there is no
  /// train or on any failure.
  Future<List<(int, List<HtReward>)>> getUpcomingRewards(
    String channelId,
  ) async {
    try {
      final data = await _gql('GetHypeTrainRewards', _rewardsQuery, {
        'channelId': normalizeChannelId(channelId),
      });
      final byLevel = <int, List<HtReward>>{};
      final config = _path(data, [
        'user',
        'channel',
        'hypeTrain',
        'execution',
        'config',
      ]);
      for (final item in htList(config, ['potentialRewards'])) {
        if (item is! Map) continue;
        final level = htInt(item, ['level']);
        final reward = HtReward.parse(htMap(item, ['value']));
        if (level == null || level < 1 || reward == null) continue;
        byLevel.putIfAbsent(level, () => []).add(reward);
      }
      final levels = byLevel.keys.toList()..sort();
      return [for (final level in levels) (level, byLevel[level]!)];
    } on Object {
      return const [];
    }
  }

  /// The map at [keys] below [map], or null.
  static Map? _path(Map map, List<String> keys) {
    Map? current = map;
    for (final key in keys) {
      current = htMap(current, [key]);
      if (current == null) return null;
    }
    return current;
  }

  Future<JsonMap> _gql(
    String operationName,
    String query,
    JsonMap variables,
  ) async {
    final Object? body = await post<dynamic>(
      _gqlUrl,
      headers: {'Client-ID': kTwitchWebClientId},
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
    );
    if (body is! Map) {
      throw const HypeTrainApiException('Malformed GQL response');
    }
    final data = body['data'];
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join('; ');
      final isIntegrity = messages.toLowerCase().contains('integrity');
      // A nested resolver error still answers the rest: keep partial data.
      final partial = data is Map && data.values.any((v) => v != null);
      if (isIntegrity || !partial) {
        throw HypeTrainApiException(messages, isIntegrity: isIntegrity);
      }
    }
    if (data is! Map) throw const HypeTrainApiException('Empty GQL response');
    return JsonMap.from(data);
  }
}
