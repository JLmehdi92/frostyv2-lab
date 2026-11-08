import 'package:dio/dio.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';
import 'package:onset/models/moderation.dart';

enum AnnouncementColor { primary, blue, green, orange, purple }

enum ChannelRole { moderator, vip }

enum SuspiciousStatus {
  monitored('ACTIVE_MONITORING'),
  restricted('RESTRICTED');

  const SuspiciousStatus(this.helixValue);

  final String helixValue;
}

enum AutoModDecision {
  allow('ALLOW'),
  deny('DENY');

  const AutoModDecision(this.helixValue);

  final String helixValue;
}

enum PredictionEnd {
  resolved('RESOLVED'),
  canceled('CANCELED'),
  locked('LOCKED');

  const PredictionEnd(this.helixValue);

  final String helixValue;
}

enum RedemptionDecision {
  fulfilled('FULFILLED'),
  canceled('CANCELED');

  const RedemptionDecision(this.helixValue);

  final String helixValue;
}

class ModTextLimits {
  const ModTextLimits._();

  static const announcement = 500;
  static const marker = 140;
  static const blockedTermMin = 2;
  static const blockedTerm = 500;
  static const resolution = 500;
  static const pollTitle = 60;
  static const pollChoice = 25;
  static const pollChoicesMin = 2;
  static const pollChoicesMax = 5;
  static const pollDurationMin = Duration(seconds: 15);
  static const pollDurationMax = Duration(minutes: 30);
  static const predictionTitle = 45;
  static const predictionOutcome = 25;
  static const predictionOutcomesMin = 2;
  static const predictionOutcomesMax = 10;
  static const predictionWindowMin = Duration(seconds: 30);
  static const predictionWindowMax = Duration(minutes: 30);
  static const streamTitle = 140;
  static const tagsMax = 10;
  static const tag = 25;
  static const commercialMax = 180;
}

final _controlCharacters = RegExp(r'[\u0000-\u001f\u007f  ]+');
final _helixId = RegExp(r'^[0-9]{1,20}$');
final _opaqueId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _tagPattern = RegExp(r'^[\p{L}\p{M}\p{N}]{1,25}$', unicode: true);

String singleLine(String text, {int? maxLength}) {
  final flat = text.replaceAll(_controlCharacters, ' ').trim();
  if (maxLength == null) return flat;
  final characters = flat.runes.toList();
  if (characters.length <= maxLength) return flat;
  return String.fromCharCodes(characters.take(maxLength)).trimRight();
}

bool isValidStreamTag(String tag) => _tagPattern.hasMatch(tag);

class TwitchModApi extends BaseApiClient {
  TwitchModApi(Dio dio) : super(dio, 'https://api.twitch.tv/helix');

  static const _quiet = {UnauthorizedInterceptor.quiet: true};

  static String _id(String id, String name) {
    if (!_helixId.hasMatch(id)) {
      throw ArgumentError.value(id, name, 'Not a Twitch id');
    }
    return id;
  }

  static String _opaque(String id, String name) {
    if (!_opaqueId.hasMatch(id)) {
      throw ArgumentError.value(id, name, 'Not an id');
    }
    return id;
  }

  static QueryParams _modQuery(String broadcasterId, String moderatorId) => {
    'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
    'moderator_id': _id(moderatorId, 'moderatorId'),
  };

  static String _required(String text, String name, int maxLength) {
    final clean = singleLine(text, maxLength: maxLength);
    if (clean.isEmpty) throw ArgumentError.value(text, name, 'Empty');
    return clean;
  }

  static List<Map<String, dynamic>> _list(Object? data) {
    final list = data is Map ? data['data'] : null;
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static String? _cursor(Object? data) {
    final pagination = data is Map ? data['pagination'] : null;
    final cursor = pagination is Map ? pagination['cursor'] : null;
    return cursor is String && cursor.isNotEmpty ? cursor : null;
  }

  Future<List<T>> _pages<T>(
    String path,
    QueryParams query,
    T Function(Map<String, dynamic> json) parse, {
    int maxPages = 10,
  }) async {
    final results = <T>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final data = await get<dynamic>(
        path,
        queryParameters: {...query, 'first': 100, 'after': ?cursor},
        extra: _quiet,
      );
      results.addAll(_list(data).map(parse));
      cursor = _cursor(data);
      if (cursor == null) break;
    }
    return results;
  }

  Future<void> sendAnnouncement({
    required String broadcasterId,
    required String moderatorId,
    required String message,
    AnnouncementColor color = AnnouncementColor.primary,
  }) async {
    await post<dynamic>(
      '/chat/announcements',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {
        'message': _required(message, 'message', ModTextLimits.announcement),
        'color': color.name,
      },
      extra: _quiet,
    );
  }

  Future<void> sendShoutout({
    required String broadcasterId,
    required String moderatorId,
    required String toBroadcasterId,
  }) async {
    await post<dynamic>(
      '/chat/shoutouts',
      queryParameters: {
        'from_broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'to_broadcaster_id': _id(toBroadcasterId, 'toBroadcasterId'),
        'moderator_id': _id(moderatorId, 'moderatorId'),
      },
      extra: _quiet,
    );
  }

  String _rolePath(ChannelRole role) => switch (role) {
    ChannelRole.moderator => '/moderation/moderators',
    ChannelRole.vip => '/channels/vips',
  };

  Future<List<ChannelRoleUser>> getRoleUsers({
    required String broadcasterId,
    required ChannelRole role,
  }) => _pages(_rolePath(role), {
    'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
  }, ChannelRoleUser.fromJson);

  Future<void> setRole({
    required String broadcasterId,
    required String userId,
    required ChannelRole role,
    required bool granted,
  }) async {
    final query = {
      'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
      'user_id': _id(userId, 'userId'),
    };
    if (granted) {
      await post<dynamic>(
        _rolePath(role),
        queryParameters: query,
        extra: _quiet,
      );
    } else {
      await delete<dynamic>(
        _rolePath(role),
        queryParameters: query,
        extra: _quiet,
      );
    }
  }

  Future<ShieldModeStatus> getShieldMode({
    required String broadcasterId,
    required String moderatorId,
  }) async {
    final data = await get<dynamic>(
      '/moderation/shield_mode',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed shield mode');
    return ShieldModeStatus.fromJson(first);
  }

  Future<ShieldModeStatus> setShieldMode({
    required String broadcasterId,
    required String moderatorId,
    required bool active,
  }) async {
    final data = await put<dynamic>(
      '/moderation/shield_mode',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {'is_active': active},
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    return first == null
        ? ShieldModeStatus(isActive: active)
        : ShieldModeStatus.fromJson(first);
  }

  Future<void> createMarker({
    required String broadcasterId,
    String description = '',
  }) async {
    final text = singleLine(description, maxLength: ModTextLimits.marker);
    await post<dynamic>(
      '/streams/markers',
      data: {
        'user_id': _id(broadcasterId, 'broadcasterId'),
        if (text.isNotEmpty) 'description': text,
      },
      extra: _quiet,
    );
  }

  Future<CommercialStart> startCommercial({
    required String broadcasterId,
    required int seconds,
  }) async {
    if (seconds < 1 || seconds > ModTextLimits.commercialMax) {
      throw ArgumentError.value(seconds, 'seconds', '1 to 180');
    }
    final data = await post<dynamic>(
      '/channels/commercial',
      data: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'length': seconds,
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    return first == null
        ? CommercialStart(length: seconds)
        : CommercialStart.fromJson(first);
  }

  Future<void> startRaid({
    required String broadcasterId,
    required String toBroadcasterId,
  }) async {
    if (broadcasterId == toBroadcasterId) {
      throw ArgumentError.value(toBroadcasterId, 'toBroadcasterId', 'Self');
    }
    await post<dynamic>(
      '/raids',
      queryParameters: {
        'from_broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'to_broadcaster_id': _id(toBroadcasterId, 'toBroadcasterId'),
      },
      extra: _quiet,
    );
  }

  Future<void> cancelRaid({required String broadcasterId}) async {
    await delete<dynamic>(
      '/raids',
      queryParameters: {'broadcaster_id': _id(broadcasterId, 'broadcasterId')},
      extra: _quiet,
    );
  }

  Future<List<BlockedTerm>> getBlockedTerms({
    required String broadcasterId,
    required String moderatorId,
  }) => _pages(
    '/moderation/blocked_terms',
    _modQuery(broadcasterId, moderatorId),
    BlockedTerm.fromJson,
  );

  Future<BlockedTerm> addBlockedTerm({
    required String broadcasterId,
    required String moderatorId,
    required String text,
  }) async {
    final term = singleLine(text, maxLength: ModTextLimits.blockedTerm);
    if (term.runes.length < ModTextLimits.blockedTermMin) {
      throw ArgumentError.value(text, 'text', 'Too short');
    }
    final data = await post<dynamic>(
      '/moderation/blocked_terms',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {'text': term},
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed blocked term');
    return BlockedTerm.fromJson(first);
  }

  Future<void> removeBlockedTerm({
    required String broadcasterId,
    required String moderatorId,
    required String termId,
  }) async {
    await delete<dynamic>(
      '/moderation/blocked_terms',
      queryParameters: {
        ..._modQuery(broadcasterId, moderatorId),
        'id': _opaque(termId, 'termId'),
      },
      extra: _quiet,
    );
  }

  Future<void> resolveHeldMessage({
    required String moderatorId,
    required String messageId,
    required AutoModDecision decision,
  }) async {
    await post<dynamic>(
      '/moderation/automod/message',
      data: {
        'user_id': _id(moderatorId, 'moderatorId'),
        'msg_id': _opaque(messageId, 'messageId'),
        'action': decision.helixValue,
      },
      extra: _quiet,
    );
  }

  Future<List<UnbanRequest>> getPendingUnbanRequests({
    required String broadcasterId,
    required String moderatorId,
  }) => _pages('/moderation/unban_requests', {
    ..._modQuery(broadcasterId, moderatorId),
    'status': 'pending',
  }, UnbanRequest.fromJson);

  Future<void> resolveUnbanRequest({
    required String broadcasterId,
    required String moderatorId,
    required String requestId,
    required bool approve,
    String resolution = '',
  }) async {
    final text = singleLine(resolution, maxLength: ModTextLimits.resolution);
    await patch<dynamic>(
      '/moderation/unban_requests',
      queryParameters: {
        ..._modQuery(broadcasterId, moderatorId),
        'unban_request_id': _opaque(requestId, 'requestId'),
        'status': approve ? 'approved' : 'denied',
        if (text.isNotEmpty) 'resolution_text': text,
      },
      extra: _quiet,
    );
  }

  Future<void> setSuspiciousStatus({
    required String broadcasterId,
    required String moderatorId,
    required String userId,
    required SuspiciousStatus? status,
  }) async {
    if (status == null) {
      await delete<dynamic>(
        '/moderation/suspicious_users',
        queryParameters: {
          ..._modQuery(broadcasterId, moderatorId),
          'user_id': _id(userId, 'userId'),
        },
        extra: _quiet,
      );
      return;
    }
    await post<dynamic>(
      '/moderation/suspicious_users',
      queryParameters: _modQuery(broadcasterId, moderatorId),
      data: {'user_id': _id(userId, 'userId'), 'status': status.helixValue},
      extra: _quiet,
    );
  }

  Future<BannedUser?> getBan({
    required String broadcasterId,
    required String userId,
  }) async {
    final data = await get<dynamic>(
      '/moderation/banned',
      queryParameters: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'user_id': _id(userId, 'userId'),
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) return null;
    final ban = BannedUser.fromJson(first);
    return ban.userId == userId ? ban : null;
  }

  Future<ChannelPoll?> getLatestPoll({required String broadcasterId}) async {
    final data = await get<dynamic>(
      '/polls',
      queryParameters: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'first': 1,
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    return first == null ? null : ChannelPoll.fromJson(first);
  }

  Future<ChannelPoll> createPoll({
    required String broadcasterId,
    required String title,
    required List<String> choices,
    required Duration duration,
  }) async {
    final cleanChoices = [
      for (final choice in choices)
        if (singleLine(choice, maxLength: ModTextLimits.pollChoice)
            case final text when text.isNotEmpty)
          text,
    ];
    if (cleanChoices.length < ModTextLimits.pollChoicesMin ||
        cleanChoices.length > ModTextLimits.pollChoicesMax) {
      throw ArgumentError.value(choices, 'choices', '2 to 5');
    }
    if (duration < ModTextLimits.pollDurationMin ||
        duration > ModTextLimits.pollDurationMax) {
      throw ArgumentError.value(duration, 'duration', '15 s to 30 min');
    }
    final data = await post<dynamic>(
      '/polls',
      data: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'title': _required(title, 'title', ModTextLimits.pollTitle),
        'choices': [
          for (final choice in cleanChoices) {'title': choice},
        ],
        'duration': duration.inSeconds,
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed poll');
    return ChannelPoll.fromJson(first);
  }

  Future<ChannelPoll> endPoll({
    required String broadcasterId,
    required String pollId,
  }) async {
    final data = await patch<dynamic>(
      '/polls',
      data: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'id': _opaque(pollId, 'pollId'),
        'status': 'TERMINATED',
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed poll');
    return ChannelPoll.fromJson(first);
  }

  Future<ChannelPrediction?> getLatestPrediction({
    required String broadcasterId,
  }) async {
    final data = await get<dynamic>(
      '/predictions',
      queryParameters: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'first': 1,
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    return first == null ? null : ChannelPrediction.fromJson(first);
  }

  Future<ChannelPrediction> createPrediction({
    required String broadcasterId,
    required String title,
    required List<String> outcomes,
    required Duration window,
  }) async {
    final cleanOutcomes = [
      for (final outcome in outcomes)
        if (singleLine(outcome, maxLength: ModTextLimits.predictionOutcome)
            case final text when text.isNotEmpty)
          text,
    ];
    if (cleanOutcomes.length < ModTextLimits.predictionOutcomesMin ||
        cleanOutcomes.length > ModTextLimits.predictionOutcomesMax) {
      throw ArgumentError.value(outcomes, 'outcomes', '2 to 10');
    }
    if (window < ModTextLimits.predictionWindowMin ||
        window > ModTextLimits.predictionWindowMax) {
      throw ArgumentError.value(window, 'window', '30 s to 30 min');
    }
    final data = await post<dynamic>(
      '/predictions',
      data: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'title': _required(title, 'title', ModTextLimits.predictionTitle),
        'outcomes': [
          for (final outcome in cleanOutcomes) {'title': outcome},
        ],
        'prediction_window': window.inSeconds,
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed prediction');
    return ChannelPrediction.fromJson(first);
  }

  Future<ChannelPrediction> endPrediction({
    required String broadcasterId,
    required String predictionId,
    required PredictionEnd end,
    String? winningOutcomeId,
  }) async {
    if (end == PredictionEnd.resolved && winningOutcomeId == null) {
      throw ArgumentError('A resolved prediction needs a winner');
    }
    final data = await patch<dynamic>(
      '/predictions',
      data: {
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'id': _opaque(predictionId, 'predictionId'),
        'status': end.helixValue,
        if (end == PredictionEnd.resolved)
          'winning_outcome_id': _opaque(winningOutcomeId!, 'winningOutcomeId'),
      },
      extra: _quiet,
    );
    final first = _list(data).firstOrNull;
    if (first == null) throw const ApiException('Malformed prediction');
    return ChannelPrediction.fromJson(first);
  }

  Future<List<RewardRedemption>> getPendingRedemptions({
    required String broadcasterId,
  }) async {
    final rewards = _list(
      await get<dynamic>(
        '/channel_points/custom_rewards',
        queryParameters: {
          'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
          'only_manageable_rewards': true,
        },
        extra: _quiet,
      ),
    );
    final redemptions = <RewardRedemption>[];
    for (final reward in rewards) {
      final rewardId = reward['id'];
      if (rewardId is! String || !_opaqueId.hasMatch(rewardId)) continue;
      redemptions.addAll(
        await _pages(
          '/channel_points/custom_rewards/redemptions',
          {
            'broadcaster_id': broadcasterId,
            'reward_id': rewardId,
            'status': 'UNFULFILLED',
            'sort': 'OLDEST',
          },
          RewardRedemption.fromJson,
          maxPages: 2,
        ),
      );
    }
    redemptions.sort((a, b) => a.redeemedAt.compareTo(b.redeemedAt));
    return redemptions;
  }

  Future<void> resolveRedemption({
    required String broadcasterId,
    required String rewardId,
    required String redemptionId,
    required RedemptionDecision decision,
  }) async {
    await patch<dynamic>(
      '/channel_points/custom_rewards/redemptions',
      queryParameters: {
        'id': _opaque(redemptionId, 'redemptionId'),
        'broadcaster_id': _id(broadcasterId, 'broadcasterId'),
        'reward_id': _opaque(rewardId, 'rewardId'),
      },
      data: {'status': decision.helixValue},
      extra: _quiet,
    );
  }

  Future<void> updateStreamInfo({
    required String broadcasterId,
    String? title,
    String? gameId,
    List<String>? tags,
  }) async {
    final body = <String, Object>{};
    if (title != null) {
      body['title'] = _required(title, 'title', ModTextLimits.streamTitle);
    }
    if (gameId != null) {
      body['game_id'] = gameId.isEmpty ? '' : _id(gameId, 'gameId');
    }
    if (tags != null) {
      final unique = <String>{
        for (final tag in tags) singleLine(tag),
      }.where((tag) => tag.isNotEmpty).toList();
      if (unique.length > ModTextLimits.tagsMax ||
          unique.any((tag) => !isValidStreamTag(tag))) {
        throw ArgumentError.value(tags, 'tags', 'Up to 10 letters-only tags');
      }
      body['tags'] = unique;
    }
    if (body.isEmpty) throw ArgumentError('Nothing to change');
    await patch<dynamic>(
      '/channels',
      queryParameters: {'broadcaster_id': _id(broadcasterId, 'broadcasterId')},
      data: body,
      extra: _quiet,
    );
  }
}
