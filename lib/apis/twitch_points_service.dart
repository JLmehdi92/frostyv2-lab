import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/models/community_points.dart';

/// Reads channel points and predictions from Twitch's private GQL endpoint.
///
/// None of this is in the public Helix API: Helix exposes predictions to the
/// *broadcaster* only, and channel points not at all from a viewer's side.
/// They are read through GQL, as the 2K renditions already are.
///
/// Reads use no credential; writes use the viewer's own token, doing what any
/// official client would do on their behalf.
class TwitchPointsService extends BaseApiClient {
  /// The public web client-id twitch.tv itself uses. Not a secret, and already
  /// used elsewhere in the app for the playback token.
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  static const _gqlUrl = 'https://gql.twitch.tv/gql';

  /// One round trip for everything the panel shows.
  ///
  /// Field names were confirmed against the live endpoint rather than guessed —
  /// `image { url }` in particular, since `url_1x` (the name the mobile app's
  /// own JSON model uses) is rejected by GQL.
  static const _contextQuery = '''
query OnsetCommunityPoints(\$login: String!) {
  channel(name: \$login) {
    id
    self {
      communityPoints {
        balance
        availableClaim { id }
      }
    }
    communityPointsSettings {
      name
      image { url }
      automaticRewards {
        id
        type
        cost
        isEnabled
        defaultImage { url }
      }
      customRewards {
        id
        title
        cost
        isEnabled
        isUserInputRequired
        backgroundColor
        image { url }
      }
    }
    activePredictionEvents {
      id
      title
      status
      createdBy {
        ... on User {
          id
          displayName
        }
      }
      outcomes {
        id
        title
        color
        totalPoints
        totalUsers
      }
    }
  }
}
''';

  TwitchPointsService(Dio dio) : super(dio, '');

  /// A client of its own with timeouts: a hung mutation keeps the sheet's
  /// controls disabled until it ends, so it has to end.
  TwitchPointsService.withDefaults() : this(Dio(defaultOptions));

  @visibleForTesting
  static BaseOptions get defaultOptions => BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  );

  /// Fetches the balance, the reward list and any running prediction.
  ///
  /// [authToken] is the twitch.tv web token — the same one that unlocks 2K.
  /// Without it the balance comes back null and everything else still works,
  /// so a signed-out viewer sees the rewards and the odds but not their own
  /// total.
  ///
  /// Never throws: this decorates a channel and must not be able to stop one
  /// from opening. A failure returns an empty context.
  Future<CommunityPointsContext> fetchContext({
    required String userLogin,
    String? authToken,
  }) async {
    try {
      final data = await post<JsonMap>(
        _gqlUrl,
        headers: {
          'Client-ID': _gqlClientId,
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'OAuth $authToken',
        },
        data: {
          'query': _contextQuery,
          'variables': {'login': userLogin},
        },
      );

      return _parseContext(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Community points unavailable for $userLogin: $e');
      }
      return CommunityPointsContext.empty;
    }
  }

  /// Spends points on a reward.
  ///
  /// Uses the viewer's own credential to do what they could do in any official
  /// client. Returns the error code Twitch reports, or null on success.
  ///
  /// One error is worth recognising: Twitch guards some point-spending
  /// mutations with an integrity attestation and answers
  /// `failed integrity check`. That is an anti-abuse control, and this client
  /// reports it rather than trying to satisfy it.
  Future<String?> redeemReward({
    required String channelId,
    required PointsReward reward,
    required String authToken,
    String? userInput,
  }) => _mutate(
    operation: 'redeemCommunityPointsCustomReward',
    inputType: 'RedeemCommunityPointsCustomRewardInput!',
    input: {
      'channelID': channelId,
      'cost': reward.cost,
      'rewardID': reward.id,
      'title': reward.title,
      // Twitch requires a caller-generated id so a retried request cannot
      // charge the viewer twice.
      'transactionID': _transactionId(),
      'prompt': ?userInput,
    },
    authToken: authToken,
  );

  /// Claims the periodic bonus chest.
  Future<String?> claimBonus({
    required String channelId,
    required String claimId,
    required String authToken,
  }) => _mutate(
    operation: 'claimCommunityPoints',
    inputType: 'ClaimCommunityPointsInput!',
    input: {'channelID': channelId, 'claimID': claimId},
    authToken: authToken,
  );

  /// Backs an outcome with [points].
  Future<String?> makePrediction({
    required String eventId,
    required String outcomeId,
    required int points,
    required String authToken,
  }) => _mutate(
    operation: 'makePrediction',
    inputType: 'MakePredictionInput!',
    input: {
      'eventID': eventId,
      'outcomeID': outcomeId,
      'points': points,
      'transactionID': _transactionId(),
    },
    authToken: authToken,
  );

  static const _predictionAccessQuery =
      'query OnsetPredictionAccess(\$eventID: ID!) { currentUser { id '
      'predictionsSettings { hasAcceptedTOS isTemporaryChatBadgeEnabled } } '
      'predictionEvent(id: \$eventID) { id self { restriction } } }';

  static const _acceptPredictionTermsDocument =
      'mutation AcceptPredictionTerms(\$input: '
      'UpdateUserPredictionSettingsInput!) { updateUserPredictionSettings('
      'input: \$input) { error { code } settings { hasAcceptedTOS '
      'isTemporaryChatBadgeEnabled } } }';

  Future<PredictionAccess?> fetchPredictionAccess({
    required String eventId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || eventId.isEmpty) return null;
    try {
      final data = await post<JsonMap>(
        _gqlUrl,
        headers: {
          'Client-ID': _gqlClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': 'OnsetPredictionAccess',
          'query': _predictionAccessQuery,
          'variables': {'eventID': eventId},
        },
      );
      return PredictionAccess.fromBody(data);
    } catch (e) {
      if (kDebugMode) debugPrint('Prediction access unavailable: $e');
      return null;
    }
  }

  Future<String?> acceptPredictionTerms({
    required bool temporaryBadgeEnabled,
    required String authToken,
  }) => _mutate(
    operation: 'updateUserPredictionSettings',
    inputType: 'UpdateUserPredictionSettingsInput!',
    document: _acceptPredictionTermsDocument,
    operationName: 'AcceptPredictionTerms',
    input: {
      'hasAcceptedTOS': true,
      'isTemporaryChatBadgeEnabled': temporaryBadgeEnabled,
    },
    authToken: authToken,
  );

  static const _unlockChosenEmoteDocument =
      'mutation UnlockChosenSubscriberEmote(\$input: '
      'UnlockChosenSubscriberEmoteInput!) { unlockChosenSubscriberEmote('
      'input: \$input) { balance error { code } } }';

  static const _unlockModifiedEmoteDocument =
      'mutation UnlockModifiedEmote(\$input: '
      'UnlockChosenModifiedSubscriberEmoteInput!) { '
      'unlockChosenModifiedSubscriberEmote(input: \$input) { balance error { '
      'code } } }';

  Future<String?> unlockChosenEmote({
    required String channelId,
    required int cost,
    required String emoteId,
    required bool modified,
    required String authToken,
  }) => _mutate(
    operation: modified
        ? 'unlockChosenModifiedSubscriberEmote'
        : 'unlockChosenSubscriberEmote',
    inputType: modified
        ? 'UnlockChosenModifiedSubscriberEmoteInput!'
        : 'UnlockChosenSubscriberEmoteInput!',
    document: modified
        ? _unlockModifiedEmoteDocument
        : _unlockChosenEmoteDocument,
    operationName: modified
        ? 'UnlockModifiedEmote'
        : 'UnlockChosenSubscriberEmote',
    input: {
      'channelID': channelId,
      'cost': cost,
      'emoteID': emoteId,
      'transactionID': _transactionId(),
    },
    authToken: authToken,
  );

  /// Runs a mutation and reduces the outcome to an error code or null.
  Future<String?> _mutate({
    required String operation,
    required String inputType,
    required Map<String, dynamic> input,
    required String authToken,
    String? document,
    String? operationName,
  }) async {
    try {
      final data = await post<JsonMap>(
        _gqlUrl,
        extra: TwitchTvSessionInterceptor.userAction,
        headers: {
          'Client-ID': _gqlClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': ?operationName,
          'query':
              document ??
              'mutation Onset(\$input: $inputType) { '
                  '$operation(input: \$input) { error { code } } }',
          'variables': {'input': input},
        },
      );

      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final message = (errors.first as JsonMap?)?['message']?.toString();
        return message ?? 'unknown_error';
      }

      // Success is a payload whose error is null. A missing or null payload
      // is not one: it says nothing about whether the points were spent.
      final body = data['data'];
      final payload = body is JsonMap ? body[operation] : null;
      if (payload is! JsonMap) return 'unknown_error';

      final error = payload['error'];
      if (error is JsonMap) return error['code']?.toString() ?? 'unknown_error';

      return null;
    } on UnauthorizedException {
      // A refused token is not a network problem: the fix is to sign in
      // again, and "could not reach Twitch" would send the viewer elsewhere.
      return 'unauthorized';
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return 'request_failed';
    }
  }

  /// A caller-generated id, which Twitch uses to make a retry idempotent.
  static String _transactionId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = identityHashCode(Object()).toRadixString(16);
    return '$now$salt';
  }

  @visibleForTesting
  static CommunityPointsContext parseContext(JsonMap data) =>
      _parseContext(data);

  static CommunityPointsContext _parseContext(JsonMap data) {
    final channel = (data['data'] as JsonMap?)?['channel'];
    if (channel is! JsonMap) return CommunityPointsContext.empty;

    final self = channel['self'];
    final points = self is JsonMap ? self['communityPoints'] : null;

    final settings = channel['communityPointsSettings'];
    final settingsMap = settings is JsonMap
        ? settings
        : const <String, Object?>{};
    final image = settingsMap['image'];

    final rawRewards = settingsMap['customRewards'];
    final rawAutomatic = settingsMap['automaticRewards'];
    final rawPredictions = channel['activePredictionEvents'];

    // Twitch's built-in rewards and the streamer's own are two separate lists
    // over the wire, but one list on screen. Querying only the custom ones is
    // why a channel with three built-ins and one custom reward showed exactly
    // one row.
    final rewards =
        <PointsReward>[
              if (rawAutomatic is List)
                ...rawAutomatic
                    .whereType<JsonMap>()
                    .map(PointsReward.tryParseAutomatic)
                    .nonNulls,
              if (rawRewards is List)
                ...rawRewards
                    .whereType<JsonMap>()
                    .map(PointsReward.tryParse)
                    .nonNulls,
            ]
            // Twitch returns disabled rewards too; showing them would only offer
            // the viewer something they cannot have.
            .where((reward) => reward.isEnabled)
            .toList()
          // By cost, which is the order the official client shows: the API's own
          // order puts the 10 000-point reward before the 80-point one, and the
          // real panel does not.
          ..sort((a, b) => a.cost.compareTo(b.cost));

    final claim = points is JsonMap ? points['availableClaim'] : null;

    return CommunityPointsContext(
      balance: points is JsonMap ? (points['balance'] as num?)?.toInt() : null,
      availableClaimId: claim is JsonMap ? claim['id'] as String? : null,
      pointsName: settingsMap['name'] as String?,
      pointsImageUrl: image is JsonMap ? image['url'] as String? : null,
      rewards: rewards,
      predictions: rawPredictions is List
          ? rawPredictions
                .whereType<JsonMap>()
                .map(Prediction.tryParse)
                .nonNulls
                .toList()
          : const [],
    );
  }
}
