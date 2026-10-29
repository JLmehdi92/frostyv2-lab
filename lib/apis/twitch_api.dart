import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/unauthorized_interceptor.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/badges.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/cheermote.dart';
import 'package:frosty/models/clip.dart' show isValidClipSlug;
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/models/shared_chat_session.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';

/// Why Twitch would not clip a stream (Helix `POST /clips` answers).
enum ClipCreateFailure {
  /// The token lacks `clips:edit` (a login from before clips), or is gone.
  missingScope,

  /// Clips are off, only for followers or subscribers, or the viewer is
  /// banned or timed out in this chat.
  restricted,

  /// The channel is not live.
  offline,

  /// The category may not be clipped (or the request was refused).
  notClippable,

  /// Too many clips in a short time.
  rateLimited,

  unknown,
}

class ClipCreateException extends ApiException {
  const ClipCreateException(this.reason, [String message = 'Clip failed'])
    : super(message);

  final ClipCreateFailure reason;

  @override
  String toString() => 'ClipCreateException: $reason';
}

/// A clip Twitch started making: its id, and the twitch.tv page where its
/// title and range are set and it is published.
class ClipCreation {
  const ClipCreation({required this.id, this.editUrl});

  final String id;

  /// Null when Twitch sent no twitch.tv link.
  final Uri? editUrl;

  /// The clip's public link.
  String get link => 'https://clips.twitch.tv/$id';
}

/// A clip Twitch has finished making.
class CreatedClip {
  const CreatedClip({required this.id, this.thumbnailUrl});

  final String id;
  final String? thumbnailUrl;
}

/// The Twitch service for making API calls.
class TwitchApi extends BaseApiClient {
  static const String _helixBaseUrl = 'https://api.twitch.tv/helix';
  static const String _oauthBaseUrl = 'https://id.twitch.tv/oauth2';
  static const String _recentMessagesUrl =
      'https://recent-messages.robotty.de/api/v2';

  TwitchApi(Dio dio) : super(dio, _helixBaseUrl);

  /// Returns a list of all Twitch global emotes.
  Future<List<Emote>> getEmotesGlobal() async {
    final data = await get<JsonMap>('/chat/emotes/global');

    final decoded = data['data'] as JsonList;
    final emotes = decoded.map((emote) => EmoteTwitch.fromJson(emote)).toList();

    return emotes
        .map((emote) => Emote.fromTwitch(emote, EmoteType.twitchGlobal))
        .toList();
  }

  /// Returns a list of a channel's Twitch emotes given their [id].
  Future<List<Emote>> getEmotesChannel({required String id}) async {
    final data = await get<JsonMap>(
      '/chat/emotes',
      queryParameters: {'broadcaster_id': id},
    );

    final decoded = data['data'] as JsonList;
    final emotes = decoded.map((emote) => EmoteTwitch.fromJson(emote)).toList();

    return emotes.map((emote) {
      switch (emote.emoteType) {
        case 'bitstier':
          return Emote.fromTwitch(emote, EmoteType.twitchBits);
        case 'follower':
          return Emote.fromTwitch(emote, EmoteType.twitchFollower);
        case 'subscriptions':
          return Emote.fromTwitch(emote, EmoteType.twitchChannel);
        default:
          return Emote.fromTwitch(emote, EmoteType.twitchChannel);
      }
    }).toList();
  }

  /// Pages of the viewer's emotes read at most (each holds a few hundred).
  static const _maxEmotePages = 10;

  /// Every emote [userId] can use in [broadcasterId]'s chat: subscriptions
  /// anywhere, follower emotes, unlocked and global ones. Needs
  /// `user:read:emotes`; a token from before that scope fails quietly
  /// (callers fall back to the chat's emote sets).
  Future<List<Emote>> getUserEmotes({
    required String userId,
    required String broadcasterId,
  }) async {
    final emotes = <Emote>[];
    String? cursor;
    for (var page = 0; page < _maxEmotePages; page++) {
      final data = await get<JsonMap>(
        '/chat/emotes/user',
        queryParameters: {
          'user_id': _checkId(userId, 'userId'),
          'broadcaster_id': _checkId(broadcasterId, 'broadcasterId'),
          'after': ?cursor,
        },
        extra: {UnauthorizedInterceptor.quiet: true},
      );
      for (final json in data['data'] as JsonList) {
        final emote = EmoteTwitch.fromJson(json as JsonMap);
        emotes.add(
          Emote.fromTwitch(emote, switch (emote.emoteType) {
            'globals' || 'smilies' => EmoteType.twitchGlobal,
            'subscriptions' => EmoteType.twitchSub,
            'follower' => EmoteType.twitchFollower,
            'bitstier' => EmoteType.twitchBits,
            _ => EmoteType.twitchUnlocked,
          }),
        );
      }
      cursor = (data['pagination'] as JsonMap?)?['cursor'] as String?;
      if (cursor == null || cursor.isEmpty) break;
    }
    return emotes;
  }

  /// Returns a list of Twitch emotes under the provided [setId].
  Future<List<Emote>> getEmotesSets({required String setId}) async {
    final data = await get<JsonMap>(
      '/chat/emotes/set',
      queryParameters: {'emote_set_id': setId},
    );

    final decoded = data['data'] as JsonList;
    final emotes = decoded.map((emote) => EmoteTwitch.fromJson(emote)).toList();

    return emotes.map((emote) {
      switch (emote.emoteType) {
        case 'globals':
        case 'smilies':
          return Emote.fromTwitch(emote, EmoteType.twitchGlobal);
        case 'subscriptions':
          return Emote.fromTwitch(emote, EmoteType.twitchSub);
        default:
          return Emote.fromTwitch(emote, EmoteType.twitchUnlocked);
      }
    }).toList();
  }

  /// Returns a map of global Twitch badges to their [Emote] object.
  Future<Map<String, ChatBadge>> getBadgesGlobal() async {
    final data = await get<JsonMap>('/chat/badges/global');

    final result = <String, ChatBadge>{};
    final decoded = data['data'] as JsonList;

    for (final badge in decoded) {
      final id = badge['set_id'] as String;
      final versions = badge['versions'] as JsonList;

      for (final version in versions) {
        final badgeInfo = BadgeInfoTwitch.fromJson(version);
        result['$id/${badgeInfo.id}'] = ChatBadge.fromTwitch(badgeInfo);
      }
    }

    return result;
  }

  /// Returns a map of a channel's Twitch badges to their [Emote] object.
  Future<Map<String, ChatBadge>> getBadgesChannel({required String id}) async {
    final data = await get<JsonMap>(
      '/chat/badges',
      queryParameters: {'broadcaster_id': id},
    );

    final result = <String, ChatBadge>{};
    final decoded = data['data'] as JsonList;

    for (final badge in decoded) {
      final id = badge['set_id'] as String;
      final versions = badge['versions'] as JsonList;

      for (final version in versions) {
        final badgeInfo = BadgeInfoTwitch.fromJson(version);
        result['$id/${badgeInfo.id}'] = ChatBadge.fromTwitch(badgeInfo);
      }
    }

    return result;
  }

  /// Returns the user's info given their token.
  Future<UserTwitch> getUserInfo() async {
    final data = await get<JsonMap>('/users');

    final userData = data['data'] as JsonList;
    return UserTwitch.fromJson(userData.first);
  }

  /// Returns a token for an anonymous user.
  Future<String> getDefaultToken() async {
    // Use custom base URL for OAuth
    final data = await post<JsonMap>(
      '$_oauthBaseUrl/token',
      queryParameters: {
        'client_id': clientId,
        'client_secret': secret,
        'grant_type': 'client_credentials',
      },
    );

    return data['access_token'] as String;
  }

  /// Revokes the user's [token] so it stops working everywhere (logout).
  Future<void> revokeToken({required String token}) async {
    await post<dynamic>(
      '$_oauthBaseUrl/revoke',
      data: {'client_id': clientId, 'token': token},
      headers: {Headers.contentTypeHeader: Headers.formUrlEncodedContentType},
    );
  }

  /// Returns a bool indicating the validity of the given token.
  Future<bool> validateToken({required String token}) async {
    try {
      await get<JsonMap>(
        '$_oauthBaseUrl/validate',
        headers: {'Authorization': 'Bearer $token'},
      );
      return true;
    } on UnauthorizedException {
      // 401 -> token is invalid/expired (propagated from interceptor for validate requests)
      return false;
    } on ApiException catch (e) {
      // Network/timeout/server errors -> treat as indeterminate, not invalid
      debugPrint('Token validation indeterminate: $e');
      rethrow;
    }
  }

  /// The scopes the current token was granted (Twitch's token validation),
  /// to tell a login from before a feature apart without failing a request.
  Future<Set<String>> getTokenScopes() async {
    final data = await get<JsonMap>(
      '$_oauthBaseUrl/validate',
      extra: {UnauthorizedInterceptor.quiet: true},
    );
    final scopes = data['scopes'];
    return {
      if (scopes is List)
        for (final scope in scopes)
          if (scope is String) scope,
    };
  }

  /// Asks Twitch to clip the last moments of [broadcasterId]'s live stream,
  /// as the viewer (needs the `clips:edit` scope). Twitch makes the clip in
  /// the background: [getCreatedClip] tells when it exists.
  Future<ClipCreation> createClip({required String broadcasterId}) async {
    final id = _checkId(broadcasterId, 'broadcasterId');
    final JsonMap data;
    try {
      data = await post<JsonMap>(
        '/clips',
        queryParameters: {'broadcaster_id': id},
        // The clip sheet explains a missing scope itself.
        extra: {UnauthorizedInterceptor.quiet: true},
      );
    } on ApiException catch (e) {
      throw ClipCreateException(switch (e.statusCode) {
        401 => ClipCreateFailure.missingScope,
        403 => ClipCreateFailure.restricted,
        404 => ClipCreateFailure.offline,
        400 => ClipCreateFailure.notClippable,
        429 => ClipCreateFailure.rateLimited,
        _ => ClipCreateFailure.unknown,
      }, e.message);
    }
    final list = data['data'];
    final clip = list is List && list.isNotEmpty ? list.first : null;
    final clipId = clip is Map ? clip['id'] : null;
    if (clipId is! String || !isValidClipSlug(clipId)) {
      throw const ClipCreateException(ClipCreateFailure.unknown);
    }
    final edit = Uri.tryParse('${clip['edit_url']}');
    final onTwitch =
        edit != null &&
        edit.scheme == 'https' &&
        edit.userInfo.isEmpty &&
        (edit.host == 'twitch.tv' || edit.host.endsWith('.twitch.tv'));
    return ClipCreation(id: clipId, editUrl: onTwitch ? edit : null);
  }

  /// The clip [id] once Twitch has made it; null while it is being made.
  Future<CreatedClip?> getCreatedClip(String id) async {
    if (!isValidClipSlug(id)) {
      throw ArgumentError.value(id, 'id', 'Not a clip id');
    }
    final data = await get<JsonMap>('/clips', queryParameters: {'id': id});
    final list = data['data'];
    final clip = list is List && list.isNotEmpty ? list.first : null;
    if (clip is! Map) return null;
    final thumbnail = clip['thumbnail_url'];
    return CreatedClip(
      id: id,
      thumbnailUrl: thumbnail is String && thumbnail.startsWith('https://')
          ? thumbnail
          : null,
    );
  }

  /// Returns a [StreamsTwitch] object that contains the top 20 streams and a cursor for further requests.
  Future<StreamsTwitch> getTopStreams({
    String? cursor,
    String language = '',
  }) async {
    final queryParams = <String, String>{};
    if (cursor != null) queryParams['after'] = cursor;
    if (language.isNotEmpty) queryParams['language'] = language;
    final data = await get<JsonMap>(
      '/streams',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    return StreamsTwitch.fromJson(data);
  }

  /// Returns a [StreamsTwitch] object that contains the given user ID's top 20 followed streams and a cursor for further requests.
  ///
  /// [quiet]: a refusal shows no "Session expired" prompt (a side list, like
  /// the channel screen's "Also live", is no reason to interrupt).
  Future<StreamsTwitch> getFollowedStreams({
    required String id,
    String? cursor,
    int? first,
    bool quiet = false,
  }) async {
    final queryParams = {'user_id': id};
    if (cursor != null) queryParams['after'] = cursor;
    if (first != null) queryParams['first'] = '${first.clamp(1, 100)}';

    final data = await get<JsonMap>(
      '/streams/followed',
      extra: quiet ? {UnauthorizedInterceptor.quiet: true} : null,
      queryParameters: queryParams,
    );

    return StreamsTwitch.fromJson(data);
  }

  /// Returns a [FollowedChannels] object containing all followed channels (including offline ones) for the given user ID.
  Future<FollowedChannels> getFollowedChannels({
    required String userId,
    String? cursor,
  }) async {
    final queryParams = {'user_id': userId, 'first': '20'};
    if (cursor != null) queryParams['after'] = cursor;

    final data = await get<JsonMap>(
      '/channels/followed',
      queryParameters: queryParams,
    );

    return FollowedChannels.fromJson(data);
  }

  /// Whether [userId] follows [broadcasterId] (`user:read:follows`, the
  /// scope the followed lists already need). A refusal is quiet: the
  /// channel screen then shows "Follow", as it would for a viewer who
  /// does not follow.
  Future<bool> isFollowing({
    required String userId,
    required String broadcasterId,
  }) async {
    final data = await get<JsonMap>(
      '/channels/followed',
      extra: {UnauthorizedInterceptor.quiet: true},
      queryParameters: {
        'user_id': _checkId(userId, 'userId'),
        'broadcaster_id': _checkId(broadcasterId, 'broadcasterId'),
      },
    );
    final followed = data['data'];
    if (followed is! List) return false;
    return followed.any(
      (channel) => channel is Map && channel['broadcaster_id'] == broadcasterId,
    );
  }

  /// Returns a [StreamsTwitch] object that contains the list of streams under the given game/category ID.
  Future<StreamsTwitch> getStreamsUnderCategory({
    required String gameId,
    String? cursor,
    String language = '',
  }) async {
    final queryParams = {'game_id': gameId};
    if (cursor != null) queryParams['after'] = cursor;
    if (language.isNotEmpty) queryParams['language'] = language;

    final data = await get<JsonMap>('/streams', queryParameters: queryParams);

    return StreamsTwitch.fromJson(data);
  }

  /// Returns a [StreamTwitch] object containing the stream info associated with the given [userLogin].
  Future<StreamTwitch> getStream({required String userLogin}) async {
    final data = await get<JsonMap>(
      '/streams',
      queryParameters: {'user_login': userLogin},
    );

    final streamData = data['data'] as JsonList;
    if (streamData.isNotEmpty) {
      return StreamTwitch.fromJson(streamData.first);
    } else {
      throw ApiException('$userLogin is offline', 404);
    }
  }

  Future<StreamsTwitch> getStreamsByIds({required List<String> userIds}) async {
    // Create query string manually for multiple user_id parameters
    final userIdParams = userIds.map((id) => 'user_id=$id').join('&');
    final url = '/streams?$userIdParams&first=100';

    final data = await get<JsonMap>(url);

    return StreamsTwitch.fromJson(data);
  }

  /// The cheermotes usable in [broadcasterId]'s chat (global and the
  /// channel's own).
  Future<Cheermotes> getCheermotes({required String broadcasterId}) async {
    final data = await get<JsonMap>(
      '/bits/cheermotes',
      queryParameters: {'broadcaster_id': _checkId(broadcasterId, 'id')},
    );
    return Cheermotes.fromHelix(data);
  }

  /// Returns a [UserTwitch] object containing the user info associated with the given [userLogin].
  Future<UserTwitch> getUser({String? userLogin, String? id}) async {
    final queryParams = <String, String>{};
    if (id != null) {
      queryParams['id'] = id;
    } else if (userLogin != null) {
      queryParams['login'] = userLogin;
    }

    final data = await get<JsonMap>('/users', queryParameters: queryParams);

    final userData = data['data'] as JsonList;
    if (userData.isNotEmpty) {
      return UserTwitch.fromJson(userData.first);
    } else {
      throw NotFoundException('User does not exist');
    }
  }

  /// The users with [ids] (unknown ones are left out), asked 100 at a time.
  Future<List<UserTwitch>> getUsersByIds(List<String> ids) async {
    final users = <UserTwitch>[];
    for (var start = 0; start < ids.length; start += 100) {
      final batch = ids.sublist(start, (start + 100).clamp(0, ids.length));
      final data = await get<JsonMap>(
        '/users',
        queryParameters: {
          'id': [for (final id in batch) _checkId(id, 'id')],
        },
      );
      users.addAll([
        for (final json in data['data'] as JsonList)
          UserTwitch.fromJson(json as JsonMap),
      ]);
    }
    return users;
  }

  /// The channels of [ids] (Helix `GET /channels`, 100 per request), by
  /// broadcaster id; ids Twitch does not know are left out.
  Future<Map<String, Channel>> getChannelsByIds(List<String> ids) async {
    final channels = <String, Channel>{};
    for (var start = 0; start < ids.length; start += 100) {
      final batch = ids.sublist(start, (start + 100).clamp(0, ids.length));
      final data = await get<JsonMap>(
        '/channels',
        queryParameters: {
          'broadcaster_id': [for (final id in batch) _checkId(id, 'id')],
        },
      );
      for (final json in data['data'] as JsonList) {
        final channel = Channel.fromJson(json as JsonMap);
        channels[channel.broadcasterId] = channel;
      }
    }
    return channels;
  }

  /// Returns a [Channel] object containing a channels's info associated with the given [userId].
  Future<Channel> getChannel({required String userId}) async {
    final data = await get<JsonMap>(
      '/channels',
      queryParameters: {'broadcaster_id': userId},
    );

    final channelData = data['data'] as JsonList;
    if (channelData.isNotEmpty) {
      return Channel.fromJson(channelData.first);
    } else {
      throw ApiException('Channel does not exist', 404);
    }
  }

  /// Returns a list of [ChannelQuery] objects closest matching the given [query].
  Future<List<ChannelQuery>> searchChannels({required String query}) async {
    final data = await get<JsonMap>(
      '/search/channels',
      queryParameters: {'first': '8', 'query': query},
    );

    final channelData = data['data'] as JsonList;
    return channelData.map((e) => ChannelQuery.fromJson(e)).toList();
  }

  /// Returns a [CategoriesTwitch] object containing the next top 20 categories/games and a cursor for further requests.
  Future<CategoriesTwitch> getTopCategories({String? cursor}) async {
    final data = await get<JsonMap>(
      '/games/top',
      queryParameters: cursor != null ? {'after': cursor} : null,
    );

    return CategoriesTwitch.fromJson(data);
  }

  /// Returns a [CategoriesTwitch] object containing the category info corresponding to the provided [gameId].
  Future<CategoriesTwitch> getCategory({required String gameId}) async {
    final data = await get<JsonMap>('/games', queryParameters: {'id': gameId});

    return CategoriesTwitch.fromJson(data);
  }

  /// Returns a [CategoriesTwitch] containing up to 20 categories/games closest matching the [query] and a cursor for further requests.
  Future<CategoriesTwitch> searchCategories({
    required String query,
    String? cursor,
  }) async {
    final queryParams = {'first': '8', 'query': query};
    if (cursor != null) queryParams['after'] = cursor;

    final data = await get<JsonMap>(
      '/search/categories',
      queryParameters: queryParams,
    );

    return CategoriesTwitch.fromJson(data);
  }

  /// Returns the sub count associated with the given [userId].
  Future<int> getSubscriberCount({required String userId}) async {
    final data = await get<JsonMap>(
      '/subscriptions',
      queryParameters: {'broadcaster_id': userId},
    );

    return data['total'] as int;
  }

  /// Returns a user's list of blocked users given their id.
  Future<List<UserBlockedTwitch>> getUserBlockedList({
    required String id,
    String? cursor,
  }) async {
    final queryParams = {'first': '100', 'broadcaster_id': id};
    if (cursor != null) queryParams['after'] = cursor;

    final data = await get<JsonMap>(
      '/users/blocks',
      queryParameters: queryParams,
    );

    final paginationCursor = data['pagination']['cursor'];
    final blockedList = data['data'] as JsonList;

    if (blockedList.isNotEmpty) {
      final result = blockedList
          .map((e) => UserBlockedTwitch.fromJson(e))
          .toList();

      if (paginationCursor != null) {
        // Wait a bit (150 milliseconds) before recursively calling.
        // This will prevent going over the rate limit to due a massive blocked users list.
        //
        // With the Twitch API, we can make up to 800 requests per minute.
        // Waiting 150 milliseconds between requests will cap the rate here at 400 requests per minute.
        await Future.delayed(const Duration(milliseconds: 150));
        result.addAll(
          await getUserBlockedList(id: id, cursor: paginationCursor),
        );
      }

      return result;
    } else {
      debugPrint('User does not have anyone blocked');
      return [];
    }
  }

  // Blocks the user with the given ID and returns true on success or false on failure.
  Future<bool> blockUser({required String userId}) async {
    try {
      await put<dynamic>(
        '/users/blocks',
        queryParameters: {'target_user_id': userId},
      );
      return true; // If no exception, operation succeeded
    } on ApiException {
      return false;
    }
  }

  // Unblocks the user with the given ID and returns true on success or false on failure.
  Future<bool> unblockUser({required String userId}) async {
    try {
      await delete<dynamic>(
        '/users/blocks',
        queryParameters: {'target_user_id': userId},
      );
      return true; // If no exception, operation succeeded
    } on ApiException {
      return false;
    }
  }

  Future<SharedChatSession?> getSharedChatSession({
    required String broadcasterId,
  }) async {
    final data = await get<JsonMap>(
      '/shared_chat/session',
      queryParameters: {'broadcaster_id': broadcasterId},
    );

    final sessionData = data['data'] as JsonList;
    if (sessionData.isEmpty) {
      return null;
    }

    return SharedChatSession.fromJson(sessionData.first);
  }

  /// Gets the color used for the user's name in chat.
  /// [userId] - The ID of the user whose chat color to get
  /// Returns the color as a hex string or empty string if no color is set.
  Future<String> getUserChatColor({required String userId}) async {
    try {
      final data = await get<JsonMap>(
        '/chat/color',
        queryParameters: {'user_id': userId},
      );

      final users = data['data'] as JsonList;
      if (users.isNotEmpty) {
        final user = users.first as JsonMap;
        return user['color'] as String? ?? '';
      }

      return '';
    } on ApiException {
      return '';
    }
  }

  /// Updates the color used for the user's name in chat.
  /// [userId] - The ID of the user whose chat color to update
  /// [color] - The color to use. Can be a named color (blue, blue_violet, etc.) or hex code for Turbo/Prime users
  /// Returns true on success or false on failure.
  Future<bool> updateUserChatColor({
    required String userId,
    required String color,
  }) async {
    try {
      await put<dynamic>(
        '/chat/color',
        queryParameters: {'user_id': userId, 'color': color},
      );
      return true; // If no exception, operation succeeded
    } on ApiException catch (e) {
      // Log the specific error for debugging
      debugPrint('Failed to update chat color: $e');
      return false;
    }
  }

  static final _helixId = RegExp(r'^[0-9]{1,20}$');
  static final _messageId = RegExp(r'^[0-9a-fA-F-]{1,64}$');

  /// Twitch's longest timeout (two weeks) and reason.
  static const maxTimeout = Duration(days: 14);
  static const maxReasonLength = 500;

  /// The query naming the channel and the moderator acting in it (the
  /// broadcaster is their own moderator).
  static QueryParams _modQuery(String broadcasterId, String moderatorId) => {
    'broadcaster_id': _checkId(broadcasterId, 'broadcasterId'),
    'moderator_id': _checkId(moderatorId, 'moderatorId'),
  };

  static String _checkId(String id, String name) {
    if (!_helixId.hasMatch(id)) {
      throw ArgumentError.value(id, name, 'Not a Twitch id');
    }
    return id;
  }

  static String _reason(String reason) {
    final trimmed = reason.trim();
    return trimmed.length > maxReasonLength
        ? trimmed.substring(0, maxReasonLength)
        : trimmed;
  }

  /// Bans [userId] from the chat, or times them out when [duration] is set
  /// (1 second to two weeks). Needs `moderator:manage:banned_users`.
  Future<void> banUser({
    required String broadcasterId,
    required String moderatorId,
    required String userId,
    Duration? duration,
    String reason = '',
  }) async {
    final seconds = duration?.inSeconds;
    if (seconds != null && (seconds < 1 || duration! > maxTimeout)) {
      throw ArgumentError.value(duration, 'duration', '1s to 14 days');
    }
    await post<dynamic>(
      '/moderation/bans',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {
        'data': {
          'user_id': _checkId(userId, 'userId'),
          'duration': ?seconds,
          'reason': _reason(reason),
        },
      },
    );
  }

  /// Lifts the ban or the timeout of [userId].
  Future<void> unbanUser({
    required String broadcasterId,
    required String moderatorId,
    required String userId,
  }) async {
    await delete<dynamic>(
      '/moderation/bans',
      queryParameters: {
        ..._modQuery(broadcasterId, moderatorId),
        'user_id': _checkId(userId, 'userId'),
      },
    );
  }

  /// Deletes the chat message [messageId], or every message of the chat
  /// when it is null. Needs `moderator:manage:chat_messages`.
  Future<void> deleteChatMessages({
    required String broadcasterId,
    required String moderatorId,
    String? messageId,
  }) async {
    if (messageId != null && !_messageId.hasMatch(messageId)) {
      throw ArgumentError.value(messageId, 'messageId', 'Not a message id');
    }
    await delete<dynamic>(
      '/moderation/chat',
      queryParameters: {
        ..._modQuery(broadcasterId, moderatorId),
        'message_id': ?messageId,
      },
    );
  }

  /// Warns [userId], who must acknowledge [reason] before chatting again.
  /// Needs `moderator:manage:warnings`.
  Future<void> warnUser({
    required String broadcasterId,
    required String moderatorId,
    required String userId,
    required String reason,
  }) async {
    final text = _reason(reason);
    if (text.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A warning needs a reason');
    }
    await post<dynamic>(
      '/moderation/warnings',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {
        'data': {'user_id': _checkId(userId, 'userId'), 'reason': text},
      },
    );
  }

  /// When [userId] followed [broadcasterId]; null when they do not.
  ///
  /// Throws [UnauthorizedException] when the viewer does not moderate
  /// there or the token lacks `moderator:read:followers` (tokens from
  /// before that scope): expected, so it shows no login dialog.
  Future<DateTime?> getFollowedAt({
    required String broadcasterId,
    required String userId,
  }) async {
    final data = await get<JsonMap>(
      '/channels/followers',
      extra: {UnauthorizedInterceptor.quiet: true},
      queryParameters: {
        'broadcaster_id': _checkId(broadcasterId, 'broadcasterId'),
        'user_id': _checkId(userId, 'userId'),
      },
    );
    final followers = data['data'];
    if (followers is! List || followers.isEmpty) return null;
    final follower = followers.first;
    if (follower is! Map || follower['user_id'] != userId) return null;
    final followedAt = follower['followed_at'];
    return followedAt is String ? DateTime.tryParse(followedAt) : null;
  }

  /// Twitch's bounds for the slow-mode wait and the follow age.
  static const minSlowWait = Duration(seconds: 3);
  static const maxSlowWait = Duration(seconds: 120);
  static const maxFollowAge = Duration(days: 90);

  /// Turns the chat's modes on or off; only the ones given change. Needs
  /// `moderator:manage:chat_settings`.
  Future<void> updateChatSettings({
    required String broadcasterId,
    required String moderatorId,
    bool? emoteMode,
    bool? followerMode,
    Duration? followerModeDuration,
    bool? slowMode,
    Duration? slowModeWaitTime,
    bool? subscriberMode,
    bool? uniqueChatMode,
  }) async {
    if (slowModeWaitTime != null &&
        (slowModeWaitTime < minSlowWait || slowModeWaitTime > maxSlowWait)) {
      throw ArgumentError.value(slowModeWaitTime, 'slowModeWaitTime');
    }
    if (followerModeDuration != null &&
        (followerModeDuration.isNegative ||
            followerModeDuration > maxFollowAge)) {
      throw ArgumentError.value(followerModeDuration, 'followerModeDuration');
    }
    final body = <String, Object>{
      'emote_mode': ?emoteMode,
      'follower_mode': ?followerMode,
      'follower_mode_duration': ?followerModeDuration?.inMinutes,
      'slow_mode': ?slowMode,
      'slow_mode_wait_time': ?slowModeWaitTime?.inSeconds,
      'subscriber_mode': ?subscriberMode,
      'unique_chat_mode': ?uniqueChatMode,
    };
    if (body.isEmpty) throw ArgumentError('Nothing to change');
    await patch<dynamic>(
      '/chat/settings',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: body,
    );
  }

  /// Twitch's longest whisper (to someone not yet whispered: 500).
  static const maxWhisperLength = 10000;

  /// Subscribes the EventSub websocket session [sessionId] to [type] for
  /// [condition] and returns the subscription id.
  Future<String> createEventSubSubscription({
    required String type,
    required String version,
    required Map<String, String> condition,
    required String sessionId,
  }) async {
    final data = await post<JsonMap>(
      '/eventsub/subscriptions',
      // Runs by itself at start: a token from before the whisper scope is
      // refused, which must not pop the login dialog.
      extra: {UnauthorizedInterceptor.quiet: true},
      data: {
        'type': type,
        'version': version,
        'condition': condition,
        'transport': {'method': 'websocket', 'session_id': sessionId},
      },
    );
    final subscriptions = data['data'];
    final first = subscriptions is List && subscriptions.isNotEmpty
        ? subscriptions.first
        : null;
    final id = first is Map ? first['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const ApiException('Malformed EventSub subscription');
    }
    return id;
  }

  Future<void> deleteEventSubSubscription(String id) async {
    await delete<dynamic>(
      '/eventsub/subscriptions',
      queryParameters: {'id': id},
      extra: {UnauthorizedInterceptor.quiet: true},
    );
  }

  /// Whispers [message] from [fromUserId] (the viewer, who needs a verified
  /// phone number) to [toUserId]. Needs `user:manage:whispers`.
  Future<void> sendWhisper({
    required String fromUserId,
    required String toUserId,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty || text.length > maxWhisperLength) {
      // Not the text itself: it must not reach a crash report.
      throw ArgumentError('A whisper is 1 to 10000 characters');
    }
    await post<dynamic>(
      '/whispers',
      queryParameters: {
        'from_user_id': _checkId(fromUserId, 'fromUserId'),
        'to_user_id': _checkId(toUserId, 'toUserId'),
      },
      data: {'message': text},
    );
  }

  // Gets recent messages from a third-party service.
  Future<JsonList> getRecentMessages({required String userLogin}) async {
    // Use custom base URL for third-party service
    final data = await get<JsonMap>(
      '$_recentMessagesUrl/recent-messages/$userLogin',
    );

    return data['messages'] as JsonList;
  }
}
