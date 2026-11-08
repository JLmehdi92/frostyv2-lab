import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/drop_campaign.dart';

enum ViewerActionOutcome { done, refused, integrityRefused, signedOut, failed }

class TwitchViewerActionsService extends BaseApiClient {
  TwitchViewerActionsService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _opaqueId = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');
  static final _random = Random.secure();
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');
  static const maxResubMessageLength = 255;

  static const _pollVoteDocument =
      'mutation PollsVoteMutation(\$input: VoteInPollInput!) { '
      'voteInPoll(input: \$input) { voter { __typename ...PollVoterFragment } '
      'error { code } } }  fragment ViewablePollFragment on Poll { id title '
      'status startedAt durationSeconds choices { id title votes { total } } '
      'settings { communityPointsVotes { cost isEnabled } } '
      'topCommunityPointsContributor { communityPointsAmount user { '
      'displayName } } self { voter { choices { pollChoice { id } } votes { '
      'total } } } votes { total } }  fragment PollVoterFragment on PollVoter '
      '{ id choices { pollChoice { id } } poll { __typename '
      '...ViewablePollFragment } votes { total } }';

  static const _joinRaidDocument =
      'mutation JoinRaidMutation(\$input: ID!) { joinRaid(input: { raidID: '
      '\$input } ) { raidID } }';

  static const _leaveRaidDocument =
      'mutation LeaveRaidMutation(\$input: ID!) { leaveRaid(input: { raidID: '
      '\$input } ) { raidID } }';

  static const _shareMilestoneDocument =
      'mutation ShareViewerMilestoneMutation(\$input: '
      'ShareViewerMilestoneInput!) { shareViewerMilestone(input: \$input) { '
      'milestone { __typename ...ViewerMilestoneFragment } error { code } } }'
      '  fragment ViewerMilestoneFragment on ViewerMilestone { id category '
      'value achievementTimestamp shareStatus }';

  static const _acknowledgeWarningDocument =
      'mutation AcknowledgeChatWarning(\$input: AcknowledgeChatWarningInput!) '
      '{ acknowledgeChatWarning(input: \$input) { error { code } } }';

  Future<ViewerActionOutcome> voteInPoll({
    required String pollId,
    required String choiceId,
    required String userId,
    required String authToken,
  }) {
    if (!_opaqueId.hasMatch(pollId) ||
        !_opaqueId.hasMatch(choiceId) ||
        !_numericId.hasMatch(userId)) {
      return _failedAtOnce(authToken);
    }
    return _send(
      operation: 'PollsVoteMutation',
      document: _pollVoteDocument,
      field: 'voteInPoll',
      authToken: authToken,
      input: {
        'pollID': pollId,
        'choiceID': choiceId,
        'userID': userId,
        'voteID': _freshId(),
      },
    );
  }

  Future<ViewerActionOutcome> joinRaid({
    required String raidId,
    required String authToken,
  }) => _raid(
    'JoinRaidMutation',
    _joinRaidDocument,
    'joinRaid',
    raidId,
    authToken,
  );

  Future<ViewerActionOutcome> leaveRaid({
    required String raidId,
    required String authToken,
  }) => _raid(
    'LeaveRaidMutation',
    _leaveRaidDocument,
    'leaveRaid',
    raidId,
    authToken,
  );

  Future<ViewerActionOutcome> shareWatchStreak({
    required String channelId,
    required String milestoneId,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) || !_opaqueId.hasMatch(milestoneId)) {
      return _failedAtOnce(authToken);
    }
    return _send(
      operation: 'ShareViewerMilestoneMutation',
      document: _shareMilestoneDocument,
      field: 'shareViewerMilestone',
      authToken: authToken,
      input: {'channelID': channelId, 'milestoneID': milestoneId},
    );
  }

  static const _useNotificationTokenDocument =
      'mutation UseChatNotificationToken(\$channelLogin: String!, \$tokenID: '
      'ID!, \$message: String, \$selection: '
      'AlertViewerCustomizationSelectionInput) { useChatNotificationToken('
      'input: { channelLogin: \$channelLogin tokenID: \$tokenID message: '
      '\$message selection: \$selection includeStreak: false } ) { '
      'isSuccess } }';

  Future<ViewerActionOutcome> shareResub({
    required String channelLogin,
    required String tokenId,
    required String authToken,
    String? message,
  }) {
    final login = channelLogin.toLowerCase();
    if (!_login.hasMatch(login) || !_opaqueId.hasMatch(tokenId)) {
      return _failedAtOnce(authToken);
    }
    final text = message?.trim() ?? '';
    return _send(
      operation: 'UseChatNotificationToken',
      document: _useNotificationTokenDocument,
      field: 'useChatNotificationToken',
      authToken: authToken,
      variables: {
        'channelLogin': login,
        'tokenID': tokenId,
        if (text.isNotEmpty)
          'message': text.length > maxResubMessageLength
              ? text.substring(0, maxResubMessageLength)
              : text,
      },
      succeeded: (payload) => payload['isSuccess'] == true,
    );
  }

  Future<ViewerActionOutcome> acknowledgeWarning({
    required String channelId,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId)) return _failedAtOnce(authToken);
    return _send(
      operation: 'AcknowledgeChatWarning',
      document: _acknowledgeWarningDocument,
      field: 'acknowledgeChatWarning',
      authToken: authToken,
      input: {'channelID': channelId},
    );
  }

  Future<ViewerActionOutcome> _raid(
    String operation,
    String document,
    String field,
    String raidId,
    String authToken,
  ) {
    if (!_opaqueId.hasMatch(raidId)) return _failedAtOnce(authToken);
    return _send(
      operation: operation,
      document: document,
      field: field,
      authToken: authToken,
      input: raidId,
      succeeded: (payload) => payload['raidID'] == raidId,
    );
  }

  static const _claimDropDocument =
      'mutation ClaimDropRewardsMutation(\$dropInstanceId: ID!) { '
      'claimDropRewards(input: { dropInstanceID: \$dropInstanceId } ) { '
      'dropInstanceID status dropType { id campaign { id } } '
      'isUserAccountConnected } }';

  Future<DropClaimResult> claimDrop({
    required String dropInstanceId,
    required String authToken,
  }) async {
    if (authToken.isEmpty) return DropClaimResult.signedOut;
    if (!_opaqueId.hasMatch(dropInstanceId)) return DropClaimResult.failed;
    try {
      return DropClaimResult.fromBody(
        await post<dynamic>(
          _gqlUrl,
          headers: {
            'Client-ID': kTwitchWebClientId,
            'Authorization': 'OAuth $authToken',
          },
          data: {
            'operationName': 'ClaimDropRewardsMutation',
            'query': _claimDropDocument,
            'variables': {'dropInstanceId': dropInstanceId},
          },
        ),
      );
    } on UnauthorizedException {
      return DropClaimResult.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('ClaimDropRewardsMutation failed: $e');
      return DropClaimResult.failed;
    }
  }

  Future<ViewerActionOutcome> _failedAtOnce(String authToken) => Future.value(
    authToken.isEmpty
        ? ViewerActionOutcome.signedOut
        : ViewerActionOutcome.failed,
  );

  Future<ViewerActionOutcome> _send({
    required String operation,
    required String document,
    required String field,
    required String authToken,
    Object? input,
    Map<String, Object?>? variables,
    bool Function(Map<dynamic, dynamic> payload)? succeeded,
  }) async {
    if (authToken.isEmpty) return ViewerActionOutcome.signedOut;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: {
          'Client-ID': kTwitchWebClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': operation,
          'query': document,
          'variables': variables ?? {'input': input},
        },
      );
      return _outcomeOf(body, field, succeeded);
    } on UnauthorizedException {
      return ViewerActionOutcome.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return ViewerActionOutcome.failed;
    }
  }

  static ViewerActionOutcome _outcomeOf(
    Object? body,
    String field,
    bool Function(Map<dynamic, dynamic> payload)? succeeded,
  ) {
    if (body is! Map) return ViewerActionOutcome.failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return text.contains('integrity')
          ? ViewerActionOutcome.integrityRefused
          : ViewerActionOutcome.failed;
    }
    final data = body['data'];
    final payload = data is Map ? data[field] : null;
    if (payload is! Map) return ViewerActionOutcome.failed;
    if (payload['error'] is Map) return ViewerActionOutcome.refused;
    if (succeeded != null && !succeeded(payload)) {
      return ViewerActionOutcome.failed;
    }
    return ViewerActionOutcome.done;
  }

  static String _freshId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
