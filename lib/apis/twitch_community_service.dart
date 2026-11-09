import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/models/shoutout_profile.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/weekly_rewards.dart';

class TwitchCommunityService extends BaseApiClient {
  TwitchCommunityService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

  static const _shoutoutQuery =
      'query ShoutoutQuery(\$channelLogin: String!, \$targetLogin: String!) '
      '{ channel(name: \$channelLogin) { id name } user(login: '
      '\$targetLogin) { id displayName profileImageURL(width: 300) '
      'primaryColorHex channel { id name home { shelves { categoryShelf('
      'first: 3) { edges { node { id boxArtURL(width: 285, height: 380) '
      'displayName } } } } } schedule { id nextSegment { id categories { id '
      'displayName } hasReminder startAt endAt isCancelled title } } } } }';

  static const _shoutoutStatusQuery =
      'query ShoutoutHighlightStatusQuery(\$targetLogin: String!) { '
      'user(login: \$targetLogin) { id self { follower { followedAt } '
      'canFollow banStatus { createdAt } } } }';

  Future<ShoutoutProfile?> getShoutoutProfile({
    required String channelLogin,
    required String targetLogin,
    String? authToken,
  }) async {
    final channel = channelLogin.toLowerCase();
    final target = targetLogin.toLowerCase();
    if (!_login.hasMatch(channel) || !_login.hasMatch(target)) return null;
    final profile = ShoutoutProfile.tryParse(
      await _ask('ShoutoutQuery', _shoutoutQuery, {
        'channelLogin': channel,
        'targetLogin': target,
      }),
    );
    if (profile == null || authToken == null || authToken.isEmpty) {
      return profile;
    }
    return profile.withFollowing(
      ShoutoutProfile.followingIn(
        await _ask('ShoutoutHighlightStatusQuery', _shoutoutStatusQuery, {
          'targetLogin': target,
        }, authToken: authToken),
      ),
    );
  }

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
      await _ask('ChannelLeaderboardsQuery', _leaderboardsQuery, {
        'channelId': channelId,
        'fetchChannelSettings': true,
      }, authToken: authToken),
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

  static const _dropCampaignFragments =
      '  fragment DropCampaignModelFragment on DropCampaign { id name game { '
      'id name boxArtURL(width: 285, height: 380) } owner { name } imageURL '
      'accountLinkURL detailsURL startAt endAt status self { '
      'isAccountConnected } summary { isPermanentlyDismissible } }  fragment '
      'DropBenefitEdgeFragment on DropBenefitEdge { benefit { id game { name '
      '} imageAssetURL name entitlementLimit distributionType } '
      'entitlementLimit }  fragment TimeBasedDropModelFragment on '
      'TimeBasedDrop { id name requiredMinutesWatched requiredSubs '
      'requiredTurboSubs startAt endAt preconditionDrops { id } benefitEdges '
      '{ __typename ...DropBenefitEdgeFragment } }  fragment '
      'TimeBasedDropSelfEdgeFragment on TimeBasedDrop { self { '
      'currentMinutesWatched currentSubs currentTurboSubs hasPreconditionsMet '
      'isClaimed dropInstanceID } }';

  static const _dropCampaignsQuery =
      'query ViewerDropsCampaignsQuery(\$channelID: ID!) { user(id: '
      '\$channelID) { id channel { viewerDropCampaigns { __typename '
      '...DropCampaignModelFragment timeBasedDrops { __typename '
      '...TimeBasedDropModelFragment ...TimeBasedDropSelfEdgeFragment } } } '
      '} }$_dropCampaignFragments';

  static const _anonymousDropCampaignsQuery =
      'query ViewerDropsCampaignsQuery(\$channelID: ID!) { user(id: '
      '\$channelID) { id channel { viewerDropCampaigns { __typename '
      '...DropCampaignModelFragment timeBasedDrops { __typename '
      '...TimeBasedDropModelFragment } } } } }  fragment '
      'DropCampaignModelFragment on DropCampaign { id name game { id name '
      'boxArtURL(width: 285, height: 380) } owner { name } imageURL '
      'accountLinkURL detailsURL startAt endAt status summary { '
      'isPermanentlyDismissible } }  fragment DropBenefitEdgeFragment on '
      'DropBenefitEdge { benefit { id game { name } imageAssetURL name '
      'entitlementLimit distributionType } entitlementLimit }  fragment '
      'TimeBasedDropModelFragment on TimeBasedDrop { id name '
      'requiredMinutesWatched requiredSubs requiredTurboSubs startAt endAt '
      'preconditionDrops { id } benefitEdges { __typename '
      '...DropBenefitEdgeFragment } }';

  Future<List<DropCampaign>?> getDropCampaigns({
    required String channelId,
    String? authToken,
  }) async {
    if (!_numericId.hasMatch(channelId)) return null;
    final signedIn = authToken != null && authToken.isNotEmpty;
    return DropCampaign.listFrom(
      await _ask(
        'ViewerDropsCampaignsQuery',
        signedIn ? _dropCampaignsQuery : _anonymousDropCampaignsQuery,
        {'channelID': channelId},
        authToken: authToken,
      ),
    );
  }

  static const _communityGoalsQuery =
      'query CommunityGoalQuery(\$id: ID!) { user(id: \$id) { channel { '
      'communityPointsSettings { goals { __typename '
      '...CommunityGoalItemFragment } } } } }  fragment '
      'CommunityPointsImageFragment on CommunityPointsImage { url url2x url4x '
      '}  fragment CommunityGoalItemFragment on CommunityPointsCommunityGoal { '
      'id status backgroundColor durationDays title description image { '
      '__typename ...CommunityPointsImageFragment } defaultImage { __typename '
      '...CommunityPointsImageFragment } amountNeeded pointsContributed '
      'smallContribution perStreamUserMaximumContribution isInStock startedAt '
      'endedAt type }';

  static const _goalContributionsQuery =
      'query CommunityGoalUserContributionsQuery(\$id: ID!) { user(id: \$id) '
      '{ channel { self { communityPoints { goalContributions { goal { id } '
      'userPointsContributedThisStream } } } } } }';

  Future<List<CommunityGoal>?> getCommunityGoals({
    required String channelId,
    String? authToken,
  }) async {
    if (!_numericId.hasMatch(channelId)) return null;
    final goals = CommunityGoal.listFrom(
      await _ask('CommunityGoalQuery', _communityGoalsQuery, {'id': channelId}),
    );
    if (goals == null ||
        goals.isEmpty ||
        authToken == null ||
        authToken.isEmpty) {
      return goals;
    }
    final mine = CommunityGoal.contributionsFrom(
      await _ask(
        'CommunityGoalUserContributionsQuery',
        _goalContributionsQuery,
        {'id': channelId},
        authToken: authToken,
      ),
    );
    return [
      for (final goal in goals)
        goal.withContributedThisStream(mine[goal.id] ?? 0),
    ];
  }

  static const _weeklyRewardsQuery =
      'query WeeklyVisitRewardsQuery(\$channelID: ID!) { channel(id: '
      '\$channelID) { id self { id weeklyVisitRewards { daysVisitedThisWeek '
      'accumulatedWeeks hasEarnedWeeklyRewardThisWeek hasVisitedToday '
      'currentReward { tier channelPoints badge { id image4x: imageURL(size: '
      'QUADRUPLE) } } eventConfig { id daysRequiredPerWeek endDate '
      'weekResetDates rewardTiers { tier channelPoints badge { id image4x: '
      'imageURL(size: QUADRUPLE) } } } } } } }';

  Future<WeeklyRewards?> getWeeklyRewards({
    required String channelId,
    required String authToken,
  }) async {
    if (authToken.isEmpty || !_numericId.hasMatch(channelId)) return null;
    return WeeklyRewards.fromBody(
      await _ask('WeeklyVisitRewardsQuery', _weeklyRewardsQuery, {
        'channelID': channelId,
      }, authToken: authToken),
    );
  }

  static const _unlockableEmotesQuery =
      'query OnsetUnlockableEmotes(\$channelID: ID!) { user(id: '
      '\$channelID) { id subscriptionProducts { id tier emotes { id token } '
      '} } }';

  Future<List<UnlockableEmote>?> getUnlockableEmotes({
    required String channelId,
  }) async {
    if (!_numericId.hasMatch(channelId)) return null;
    return UnlockableEmote.listFrom(
      await _ask('OnsetUnlockableEmotes', _unlockableEmotesQuery, {
        'channelID': channelId,
      }),
    );
  }

  static const _legendaryCollectionQuery =
      'query LegendaryEmoteCollection(\$channelID: ID) { '
      'legendaryEmoteSeason(channelID: \$channelID) { id campaign { id name '
      'imageURL } emotePool { tier isOwned emote { id token } } userProgress '
      '{ chestInventory { chestType unopenedCount } } } }';

  Future<LegendaryCollection?> getLegendaryCollection({
    required String channelId,
    String? authToken,
  }) async {
    if (!_numericId.hasMatch(channelId)) return null;
    return LegendaryCollection.fromBody(
      await _ask('LegendaryEmoteCollection', _legendaryCollectionQuery, {
        'channelID': channelId,
      }, authToken: authToken),
    );
  }

  static const _costreamersQuery =
      'query CostreamersRoster(\$login: String!) { user(login: \$login) { id '
      'stream { id costreamDetails { role costreamersCount totalViewersCount '
      'organizer { id login displayName profileImageURL(width: 70) stream { '
      'id viewersCount } } topCostreamers { id login displayName '
      'profileImageURL(width: 70) stream { id viewersCount } } } } } }';

  static const _guestStarQuery =
      'query GuestStarSessionViewerQuery(\$channelID: ID!) { channel(id: '
      '\$channelID) { owner { __typename '
      '...GuestStarUserWithFollowDetailsFragment } guestStarSessionCall { id '
      'guests { user { __typename ...GuestStarUserWithFollowDetailsFragment } '
      '} } } }  fragment GuestStarUserWithFollowDetailsFragment on User { id '
      'login displayName profileImageURL(width: 70) primaryColorHex self { '
      'canFollow follower { followedAt } } stream { id viewersCount } }';

  Future<LiveTogether?> getCostreamers({required String channelLogin}) async {
    final login = channelLogin.toLowerCase();
    if (!_login.hasMatch(login)) return null;
    return LiveTogether.fromCostream(
      await _ask('CostreamersRoster', _costreamersQuery, {'login': login}),
    );
  }

  Future<LiveTogether?> getGuestStarSession({required String channelId}) async {
    if (!_numericId.hasMatch(channelId)) return null;
    return LiveTogether.fromGuestStar(
      await _ask('GuestStarSessionViewerQuery', _guestStarQuery, {
        'channelID': channelId,
      }),
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
