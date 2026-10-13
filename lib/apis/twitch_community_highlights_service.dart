import 'package:dio/dio.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/community_highlights.dart';

/// A GQL error answered for a community highlights request.
class CommunityHighlightsApiException extends ApiException {
  const CommunityHighlightsApiException(
    super.message, {
    this.isIntegrity = false,
  });

  /// Twitch asked for a client-integrity token.
  final bool isIntegrity;

  @override
  String toString() => 'CommunityHighlightsApiException: $message';
}

/// A channel's predictions as GQL reports them.
typedef ChannelPredictions = ({
  Prediction? active,
  Prediction? locked,
  Prediction? lastResolved,
});

/// The current poll, predictions and pinned chat message of a channel, from
/// anonymous GQL (the public web Client-ID, full documents, no user token).
/// Realtime changes come from Hermes; these are the snapshots.
class TwitchCommunityHighlightsService extends BaseApiClient {
  TwitchCommunityHighlightsService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _channelId = RegExp(r'^[0-9]{1,20}$');

  static const _pollQuery =
      'query GetViewablePoll(\$channelID: ID!) { user(id: \$channelID) { id '
      'viewablePoll { id title status durationSeconds '
      'remainingDurationMilliseconds startedAt endedAt totalVoters '
      'votes { total } choices { id title totalVoters votes { total } } '
      'settings { multichoice { isEnabled } } } } }';

  // `resolvedPredictionEvents` must stay: without it the document is
  // rejected (verified 2026-10-13).
  static const _predictionsQuery =
      'query GetActivePrediction(\$channelID: ID!, \$resolvedCount: Int = 1) '
      '{ user(id: \$channelID) { id channel { id '
      'activePredictionEvents { id ...PredictionSnapshot } '
      'lockedPredictionEvents { id ...PredictionSnapshot } '
      'resolvedPredictionEvents(first: \$resolvedCount) { edges { node { id '
      '...PredictionSnapshot } } } } } } '
      'fragment PredictionSnapshot on PredictionEvent { id title status '
      'createdAt endedAt lockedAt predictionWindowSeconds outcomes { id title '
      'color totalPoints totalUsers topPredictors { id points user { id '
      'displayName } } } winningOutcome { id } }';

  static const _pinnedQuery =
      'query GetPinnedChat(\$channelID: ID!) { channel(id: \$channelID) { id '
      'pinnedChatMessages(first: 1, messageType: MOD) { edges { node { id '
      'type startsAt updatedAt endsAt pinnedMessage { id content { text '
      'fragments { text content { __typename ... on Emote { emoteID: id } } '
      '} } sentAt sender { id login displayName chatColor '
      'displayBadges(channelID: \$channelID) { id setID version } } } '
      'pinnedBy { id login displayName } } } } } }';

  /// The channel's viewable poll (active, or just ended), or null.
  Future<Poll?> getPoll(String channelId) async {
    final data = await _gql('GetViewablePoll', _pollQuery, {
      'channelID': _checked(channelId),
    });
    return Poll.fromGql(chMap(data['user'])?['viewablePoll']);
  }

  /// The channel's active, locked and last resolved predictions.
  Future<ChannelPredictions> getPredictions(String channelId) async {
    final data = await _gql('GetActivePrediction', _predictionsQuery, {
      'channelID': _checked(channelId),
    });
    final channel = chMap(chMap(data['user'])?['channel']);
    Prediction? first(Object? list) {
      for (final node in chList(list)) {
        if (Prediction.fromGql(node) case final prediction?) return prediction;
      }
      return null;
    }

    final resolved = chMap(channel?['resolvedPredictionEvents']);
    return (
      active: first(channel?['activePredictionEvents']),
      locked: first(channel?['lockedPredictionEvents']),
      lastResolved: first([
        for (final edge in chList(resolved?['edges'])) chMap(edge)?['node'],
      ]),
    );
  }

  /// The message moderators pinned in chat, or null.
  Future<PinnedChatMessage?> getPinned(String channelId) async {
    final data = await _gql('GetPinnedChat', _pinnedQuery, {
      'channelID': _checked(channelId),
    });
    final pinned = chMap(chMap(data['channel'])?['pinnedChatMessages']);
    for (final edge in chList(pinned?['edges'])) {
      final pin = PinnedChatMessage.fromGql(chMap(edge)?['node']);
      if (pin != null) return pin;
    }
    return null;
  }

  static String _checked(String raw) {
    final id = raw.trim();
    if (!_channelId.hasMatch(id)) {
      throw ArgumentError.value(raw, 'channelId', 'Not a Twitch user id');
    }
    return id;
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
      throw const CommunityHighlightsApiException('Malformed GQL response');
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
        throw CommunityHighlightsApiException(
          messages,
          isIntegrity: isIntegrity,
        );
      }
    }
    if (data is! Map) {
      throw const CommunityHighlightsApiException('Empty GQL response');
    }
    return JsonMap.from(data);
  }
}
