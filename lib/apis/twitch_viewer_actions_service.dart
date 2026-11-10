import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/integrity_retry_interceptor.dart';
import 'package:onset/apis/twitch_api.dart' show ClipEligibilityRefusal;
import 'package:onset/constants.dart';
import 'package:onset/models/chat_identity.dart';
import 'package:onset/models/chat_ui_settings.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/gif_picker.dart';
import 'package:onset/models/unban_request.dart';
import 'package:onset/models/weekly_rewards.dart';

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

  static const _assignLeadModDocument =
      'mutation AssignLeadModMutation(\$input: AssignChannelRoleInput!) { '
      'assignChannelRole(input: \$input) { isAssigned error { code } } }';

  static const _unassignLeadModDocument =
      'mutation UnassignLeadModMutation(\$input: UnassignChannelRoleInput!) '
      '{ unassignChannelRole(input: \$input) { isUnassigned error { code } } }';

  static const _pinMessageDocument =
      'mutation PinChatMessage(\$input: PinChatMessageInput!) { '
      'pinChatMessage(input: \$input) { pinnedChatMessage { id '
      'pinnedMessage { id } } error { code } } }';

  static const _unpinMessageDocument =
      'mutation unpinChatMessage(\$input: UnpinChatMessageInput!) { '
      'unpinChatMessage(input: \$input) { unpinnedChatMessage { id '
      'pinnedMessage { id } } error { code } } }';

  static const modPinSeconds = 1200;

  Future<ViewerActionOutcome> setLeadModerator({
    required String channelId,
    required String userId,
    required bool granted,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) || !_numericId.hasMatch(userId)) {
      return _failedAtOnce(authToken);
    }
    final field = granted ? 'assignChannelRole' : 'unassignChannelRole';
    return _send(
      operation: granted ? 'AssignLeadModMutation' : 'UnassignLeadModMutation',
      document: granted ? _assignLeadModDocument : _unassignLeadModDocument,
      field: field,
      authToken: authToken,
      input: {
        'channelID': channelId,
        'roleID': 'lead_mod',
        'targetUserID': userId,
      },
      succeeded: (payload) =>
          payload[granted ? 'isAssigned' : 'isUnassigned'] == true,
    );
  }

  Future<ViewerActionOutcome> pinMessage({
    required String channelId,
    required String messageId,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) || !_opaqueId.hasMatch(messageId)) {
      return _failedAtOnce(authToken);
    }
    return _send(
      operation: 'PinChatMessage',
      document: _pinMessageDocument,
      field: 'pinChatMessage',
      authToken: authToken,
      input: {
        'channelID': channelId,
        'durationSeconds': modPinSeconds,
        'messageID': messageId,
        'type': 'MOD',
      },
      succeeded: (payload) => payload['pinnedChatMessage'] is Map,
    );
  }

  Future<ViewerActionOutcome> unpinMessage({
    required String pinId,
    required String authToken,
  }) {
    if (!_opaqueId.hasMatch(pinId)) return _failedAtOnce(authToken);
    return _send(
      operation: 'unpinChatMessage',
      document: _unpinMessageDocument,
      field: 'unpinChatMessage',
      authToken: authToken,
      input: {'id': pinId, 'reason': 'UNPIN'},
      succeeded: (payload) => payload['unpinnedChatMessage'] is Map,
    );
  }

  static const _canCreateClipDocument =
      'query CanCreateClipForChannelQuery(\$broadcasterId: ID!) { '
      'canCreateClip(broadcasterID: \$broadcasterId) { isAllowed errorCode '
      'requiredFollowingLengthMinutes } }';

  Future<ClipEligibilityRefusal?> clipRefusal({
    required String broadcasterId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || !_numericId.hasMatch(broadcasterId)) return null;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: _viewerHeaders(authToken),
        data: {
          'operationName': 'CanCreateClipForChannelQuery',
          'query': _canCreateClipDocument,
          'variables': {'broadcasterId': broadcasterId},
        },
      );
      return ClipEligibilityRefusal.fromGql(body is Map ? body['data'] : null);
    } catch (e) {
      if (kDebugMode) debugPrint('CanCreateClipForChannelQuery failed: $e');
      return null;
    }
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

  static const _selectChannelBadgeDocument =
      'mutation SelectChannelBadgeMutation(\$input: '
      'SelectChannelBadgeInput!) { selectChannelBadge(input: \$input) { '
      'isSuccessful user { id } } }';

  static const _deselectChannelBadgeDocument =
      'mutation DeselectChannelBadgeMutation(\$input: '
      'DeselectChannelBadgeInput!) { deselectChannelBadge(input: \$input) '
      '{ user { id } } }';

  static const _selectGlobalBadgeDocument =
      'mutation SelectGlobalBadgeMutation(\$input: '
      'SelectGlobalBadgeInput!) { selectGlobalBadge(input: \$input) { '
      'isSuccessful user { id } } }';

  static const _deselectGlobalBadgeDocument =
      'mutation DeselectGlobalBadgeMutation { deselectGlobalBadge { user '
      '{ id } } }';

  static const _subFlairDocument =
      'mutation UpdateSubFlairHiddenMutation(\$input: '
      'UpdateUserSubscriptionSettingsInput!) { '
      'updateUserSubscriptionSettings(input: \$input) { '
      'subscriptionSettings { isBadgeModifierHidden } } }';

  static final _badgeToken = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

  Future<ViewerActionOutcome> selectBadge({
    required ChatBadgeScope scope,
    required String channelId,
    required String authToken,
    ChatBadgeChoice? badge,
  }) {
    if (!_numericId.hasMatch(channelId) ||
        (badge != null &&
            (!_badgeToken.hasMatch(badge.setId) ||
                !_badgeToken.hasMatch(badge.version)))) {
      return _failedAtOnce(authToken);
    }
    final channel = scope == ChatBadgeScope.channel;
    if (badge == null) {
      return channel
          ? _send(
              operation: 'DeselectChannelBadgeMutation',
              document: _deselectChannelBadgeDocument,
              field: 'deselectChannelBadge',
              authToken: authToken,
              input: {'channelID': channelId},
            )
          : _send(
              operation: 'DeselectGlobalBadgeMutation',
              document: _deselectGlobalBadgeDocument,
              field: 'deselectGlobalBadge',
              authToken: authToken,
              variables: const {},
            );
    }
    return _send(
      operation: channel
          ? 'SelectChannelBadgeMutation'
          : 'SelectGlobalBadgeMutation',
      document: channel
          ? _selectChannelBadgeDocument
          : _selectGlobalBadgeDocument,
      field: channel ? 'selectChannelBadge' : 'selectGlobalBadge',
      authToken: authToken,
      input: {
        'badgeSetID': badge.setId,
        'badgeSetVersion': badge.version,
        'channelID': ?(channel ? channelId : null),
      },
      succeeded: (payload) => payload['isSuccessful'] != false,
    );
  }

  Future<ViewerActionOutcome> setSubFlairHidden({
    required bool hidden,
    required String authToken,
  }) => _send(
    operation: 'UpdateSubFlairHiddenMutation',
    document: _subFlairDocument,
    field: 'updateUserSubscriptionSettings',
    authToken: authToken,
    input: {'isBadgeModifierHidden': hidden},
  );

  static const _createUnbanRequestDocument =
      'mutation CreateUnbanRequest(\$input: CreateUnbanRequestInput!) { '
      'createUnbanRequest(input: \$input) { unbanRequest { id } error { code } '
      '} }';

  static const maxUnbanMessageLength = 500;

  Future<UnbanRequestOutcome> createUnbanRequest({
    required String channelId,
    required String message,
    required String authToken,
  }) async {
    final text = message.trim();
    if (authToken.isEmpty) {
      return const UnbanRequestOutcome(UnbanRequestResult.signedOut);
    }
    if (!_numericId.hasMatch(channelId) ||
        text.isEmpty ||
        text.length > maxUnbanMessageLength) {
      return const UnbanRequestOutcome(UnbanRequestResult.failed);
    }
    try {
      return UnbanRequestOutcome.fromBody(
        await post<dynamic>(
          _gqlUrl,
          extra: IntegrityRetryInterceptor.userAction,
          headers: {
            'Client-ID': kTwitchWebClientId,
            'Authorization': 'OAuth $authToken',
          },
          data: {
            'operationName': 'CreateUnbanRequest',
            'query': _createUnbanRequestDocument,
            'variables': {
              'input': {'channelID': channelId, 'requesterMessage': text},
            },
          },
        ),
      );
    } on UnauthorizedException {
      return const UnbanRequestOutcome(UnbanRequestResult.signedOut);
    } catch (e) {
      if (kDebugMode) debugPrint('CreateUnbanRequest failed: $e');
      return const UnbanRequestOutcome(UnbanRequestResult.failed);
    }
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

  static const _contributeToGoalDocument =
      'mutation CommunityGoalMutation(\$input: '
      'ContributeCommunityPointsCommunityGoalInput!) { '
      'contributeCommunityPointsCommunityGoal(input: \$input) { error { code '
      '} } }';

  Future<GoalContributionResult> contributeToGoal({
    required String channelId,
    required String goalId,
    required int amount,
    required String authToken,
  }) async {
    if (authToken.isEmpty) return GoalContributionResult.signedOut;
    if (!_numericId.hasMatch(channelId) ||
        !_opaqueId.hasMatch(goalId) ||
        amount <= 0) {
      return GoalContributionResult.failed;
    }
    try {
      return GoalContributionResult.fromBody(
        await post<dynamic>(
          _gqlUrl,
          extra: IntegrityRetryInterceptor.userAction,
          headers: {
            'Client-ID': kTwitchWebClientId,
            'Authorization': 'OAuth $authToken',
          },
          data: {
            'operationName': 'CommunityGoalMutation',
            'query': _contributeToGoalDocument,
            'variables': {
              'input': {
                'amount': amount,
                'channelID': channelId,
                'goalID': goalId,
                'transactionID': _freshId(),
              },
            },
          },
        ),
      );
    } on UnauthorizedException {
      return GoalContributionResult.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('CommunityGoalMutation failed: $e');
      return GoalContributionResult.failed;
    }
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
          extra: IntegrityRetryInterceptor.userAction,
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

  static const _claimMomentDocument =
      'mutation ClaimMomentMutation(\$momentID: ID!) { claimCommunityMoment('
      'input: { momentID: \$momentID } ) { moment { id } error } }';

  Future<MomentClaimResult> claimMoment({
    required String momentId,
    required String authToken,
  }) async {
    if (authToken.isEmpty) return MomentClaimResult.signedOut;
    if (!_opaqueId.hasMatch(momentId)) return MomentClaimResult.invalid;
    try {
      return MomentClaimResult.fromBody(
        await post<dynamic>(
          _gqlUrl,
          extra: IntegrityRetryInterceptor.userAction,
          headers: {
            'Client-ID': kTwitchWebClientId,
            'Authorization': 'OAuth $authToken',
          },
          data: {
            'operationName': 'ClaimMomentMutation',
            'query': _claimMomentDocument,
            'variables': {'momentID': momentId},
          },
        ),
      );
    } on UnauthorizedException {
      return MomentClaimResult.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('ClaimMomentMutation failed: $e');
      return MomentClaimResult.failed;
    }
  }

  static const _followUserDocument =
      'mutation FollowUserMutation(\$targetId: ID!, \$disableNotifications: '
      'Boolean!) { followUser(input: { targetID: \$targetId '
      'disableNotifications: \$disableNotifications } ) { follow { '
      'disableNotifications } error { code } } }';

  static const _unfollowUserDocument =
      'mutation UnfollowUserMutation(\$targetId: ID!) { unfollowUser(input: '
      '{ targetID: \$targetId } ) { follow { disableNotifications } } }';

  static const _followGameDocument =
      'mutation FollowGameMutation(\$gameID: ID!) { followGame(input: { '
      'gameID: \$gameID } ) { game { __typename ...GameModelFragment } } }'
      '  fragment TagModelFragment on Tag { id localizedName tagName '
      'isAutomated isLanguageTag localizedDescription scope }  fragment '
      'GameModelFragment on Game { id name originalReleaseDate viewersCount '
      'followersCount displayName broadcastersCount boxArtURL(width: 285, '
      'height: 380) gameTags: tags(limit: 5, tagType: CONTENT) { __typename '
      '...TagModelFragment } coverURL(width: 1600, height: 240) }';

  static const _unfollowGameDocument =
      'mutation UnfollowGameMutation(\$gameID: ID!) { unfollowGame(input: { '
      'gameID: \$gameID } ) { game { __typename ...GameModelFragment } } }'
      '  fragment TagModelFragment on Tag { id localizedName tagName '
      'isAutomated isLanguageTag localizedDescription scope }  fragment '
      'GameModelFragment on Game { id name originalReleaseDate viewersCount '
      'followersCount displayName broadcastersCount boxArtURL(width: 285, '
      'height: 380) gameTags: tags(limit: 5, tagType: CONTENT) { __typename '
      '...TagModelFragment } coverURL(width: 1600, height: 240) }';

  static const _giftSettingsDocument =
      'query UserGiftedSubSettingsQuery { currentUser { id '
      'subscriptionSettings { giftsToFollowedChannelsOnly isGiftCountHidden '
      '} } }';

  static const _updateGiftSettingsDocument =
      'mutation UserGiftedSubSettingsMutation(\$input: '
      'UpdateUserSubscriptionSettingsInput!) { '
      'updateUserSubscriptionSettings(input: \$input) { '
      'subscriptionSettings { giftsToFollowedChannelsOnly isGiftCountHidden '
      '} } }';

  Future<FollowResult> followChannel({
    required String channelId,
    required String authToken,
  }) => _follow(
    operation: 'FollowUserMutation',
    document: _followUserDocument,
    field: 'followUser',
    id: channelId,
    authToken: authToken,
    variables: {'targetId': channelId, 'disableNotifications': false},
  );

  Future<FollowResult> unfollowChannel({
    required String channelId,
    required String authToken,
  }) => _follow(
    operation: 'UnfollowUserMutation',
    document: _unfollowUserDocument,
    field: 'unfollowUser',
    id: channelId,
    authToken: authToken,
    variables: {'targetId': channelId},
  );

  Future<FollowResult> followCategory({
    required String categoryId,
    required String authToken,
  }) => _follow(
    operation: 'FollowGameMutation',
    document: _followGameDocument,
    field: 'followGame',
    id: categoryId,
    authToken: authToken,
    variables: {'gameID': categoryId},
  );

  Future<FollowResult> unfollowCategory({
    required String categoryId,
    required String authToken,
  }) => _follow(
    operation: 'UnfollowGameMutation',
    document: _unfollowGameDocument,
    field: 'unfollowGame',
    id: categoryId,
    authToken: authToken,
    variables: {'gameID': categoryId},
  );

  Future<FollowResult> _follow({
    required String operation,
    required String document,
    required String field,
    required String id,
    required String authToken,
    required Map<String, Object?> variables,
  }) async {
    if (authToken.isEmpty) return FollowResult.signedOut;
    if (!_numericId.hasMatch(id)) return FollowResult.failed;
    try {
      return FollowResult.fromBody(
        await post<dynamic>(
          _gqlUrl,
          extra: IntegrityRetryInterceptor.userAction,
          headers: _viewerHeaders(authToken),
          data: {
            'operationName': operation,
            'query': document,
            'variables': variables,
          },
        ),
        field,
      );
    } on UnauthorizedException {
      return FollowResult.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return FollowResult.failed;
    }
  }

  Future<GiftSettings?> giftSettings({required String authToken}) async {
    if (authToken.isEmpty) return null;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: _viewerHeaders(authToken),
        data: {
          'operationName': 'UserGiftedSubSettingsQuery',
          'query': _giftSettingsDocument,
          'variables': const <String, Object?>{},
        },
      );
      final data = body is Map ? body['data'] : null;
      final user = data is Map ? data['currentUser'] : null;
      return GiftSettings.fromSettings(
        user is Map ? user['subscriptionSettings'] : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('UserGiftedSubSettingsQuery failed: $e');
      return null;
    }
  }

  Future<ViewerActionOutcome> updateGiftSettings({
    required GiftSettings settings,
    required String authToken,
  }) => _send(
    operation: 'UserGiftedSubSettingsMutation',
    document: _updateGiftSettingsDocument,
    field: 'updateUserSubscriptionSettings',
    authToken: authToken,
    input: {
      'giftsToFollowedChannelsOnly': settings.followedChannelsOnly,
      'isGiftCountHidden': settings.countHidden,
    },
    succeeded: (payload) =>
        GiftSettings.fromSettings(payload['subscriptionSettings']) == settings,
  );

  static const _chatUiSettingsDocument =
      'query ChatUISettingsQuery { currentUser { id chatUISettings { '
      'isReadableChatColorsEnabled isEmoteAnimationsEnabled isGifsEnabled '
      'isGifAnimationsEnabled } } }';

  Future<ChatUiSettings?> chatUiSettings({required String authToken}) async {
    if (authToken.isEmpty) return null;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: _viewerHeaders(authToken),
        data: {
          'operationName': 'ChatUISettingsQuery',
          'query': _chatUiSettingsDocument,
          'variables': const <String, Object?>{},
        },
      );
      final data = body is Map ? body['data'] : null;
      final user = data is Map ? data['currentUser'] : null;
      return ChatUiSettings.fromSettings(
        user is Map ? user['chatUISettings'] : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ChatUISettingsQuery failed: $e');
      return null;
    }
  }

  Future<ViewerActionOutcome> updateChatUiSetting({
    required ChatUiSetting setting,
    required bool enabled,
    required String authToken,
  }) => _send(
    operation: setting.operation,
    document: setting.document,
    field: setting.mutation,
    authToken: authToken,
    input: {setting.field: enabled},
    succeeded: (payload) => payload[setting.field] == enabled,
  );

  static const _gifPickerConfigDocument =
      'query GetGifPickerConfig(\$channelID: ID!) { '
      'gifPickerConfig(channelID: \$channelID) { isEnabled isAllowlisted '
      'apiKey contentRating } }';

  static const _sendGifDocument =
      'mutation sendGifMessage(\$input: SendGifMessageInput!) { '
      'sendGifMessage(input: \$input) { error secondsUntilCanSend message { '
      'id } } }';

  Future<GifPickerConfig?> gifPickerConfig({
    required String channelId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || !_numericId.hasMatch(channelId)) return null;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: _viewerHeaders(authToken),
        data: {
          'operationName': 'GetGifPickerConfig',
          'query': _gifPickerConfigDocument,
          'variables': {'channelID': channelId},
        },
      );
      final data = body is Map ? body['data'] : null;
      return GifPickerConfig.fromConfig(
        data is Map ? data['gifPickerConfig'] : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('GetGifPickerConfig failed: $e');
      return null;
    }
  }

  Future<GifSendResult> sendGif({
    required String channelId,
    required GiphyGif gif,
    required String searchTerm,
    required String authToken,
  }) async {
    if (authToken.isEmpty) return const GifSendResult(GifSendStatus.signedOut);
    if (!_numericId.hasMatch(channelId)) {
      return const GifSendResult(GifSendStatus.failed);
    }
    final term = searchTerm.trim();
    try {
      return GifSendResult.fromBody(
        await post<dynamic>(
          _gqlUrl,
          extra: IntegrityRetryInterceptor.userAction,
          headers: _viewerHeaders(authToken),
          data: {
            'operationName': 'sendGifMessage',
            'query': _sendGifDocument,
            'variables': {
              'input': {
                'channelID': channelId,
                'gifID': gif.id,
                'gifURL': gif.url,
                if (term.isNotEmpty) 'searchTerm': term,
              },
            },
          },
        ),
      );
    } on UnauthorizedException {
      return const GifSendResult(GifSendStatus.signedOut);
    } catch (e) {
      if (kDebugMode) debugPrint('sendGifMessage failed: $e');
      return const GifSendResult(GifSendStatus.failed);
    }
  }

  static Map<String, String> _viewerHeaders(String authToken) => {
    'Client-ID': kTwitchWebClientId,
    'Authorization': 'OAuth $authToken',
  };

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
        extra: IntegrityRetryInterceptor.userAction,
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
