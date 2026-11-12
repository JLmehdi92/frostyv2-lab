import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/models/recommended_channel.dart';
import 'package:onset/models/whisper_history.dart';

class OnsiteNotificationPage {
  const OnsiteNotificationPage({required this.notifications, this.cursor});

  final List<OnsiteNotification> notifications;
  final String? cursor;
}

class TwitchSocialService extends BaseApiClient {
  TwitchSocialService(Dio dio) : super(dio, '');

  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _threadId = RegExp(r'^[0-9]{1,20}_[0-9]{1,20}$');
  static final _opaqueId = RegExp(r'^[A-Za-z0-9_:.\-]{1,256}$');
  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');
  static const threadsPage = 30;
  static const messagesPage = 50;
  static const notificationsPage = 30;
  static const maxRecommendations = 12;

  static const _whisperMessageFragment =
      'fragment WhisperMessageFragment on WhisperMessage { id from { login '
      'displayName id chatColor displayBadges { setID version } } sentAt '
      'content { content emotes { emoteID from id setID to } } }';

  static const _whisperThreadFragment =
      'fragment WhisperThreadFragment on WhisperThread { id participants { '
      'login displayName id chatColor } messages(first: 1) { edges { node { '
      '__typename ...WhisperMessageFragment } } } unreadMessagesCount '
      'isArchived isMuted }';

  static const _threadsDocument =
      'query UserWhisperThreadsQuery(\$limit: Int!, \$cursor: Cursor) { '
      'currentUser { whisperThreads(first: \$limit, after: \$cursor) { edges '
      '{ cursor node { __typename ...WhisperThreadFragment } } pageInfo { '
      'hasNextPage hasPreviousPage } totalCount totalUnreadCount } } }  '
      '$_whisperMessageFragment  $_whisperThreadFragment';

  static const _messagesDocument =
      'query WhisperMessageQuery(\$thread: ID, \$cursor: Cursor, '
      '\$numMessages: Int) { whisperThread(id: \$thread) { messages(first: '
      '\$numMessages, after: \$cursor) { edges { node { __typename '
      '...WhisperMessageFragment } cursor } pageInfo { hasNextPage } } '
      'lastMessage { __typename ...WhisperMessageFragment } } }  '
      '$_whisperMessageFragment';

  static const _privacyDocument =
      'query WhisperSettingsGetterQuery { currentUser { login '
      'whisperSettings { isWhisperBanned isBlockingWhispersFromStrangers '
      'isWhispersDisabledByParent } } }';

  static const _updatePrivacyDocument =
      'mutation UpdateWhisperSettings(\$input: UpdateWhisperSettingsInput!) { '
      'updateWhisperSettings(input: \$input) { user { login whisperSettings '
      '{ isWhisperBanned isBlockingWhispersFromStrangers } } } }';

  static const _removeWhitelistDocument =
      'mutation RemoveWhisperThreadWhitelistMutation(\$threadID: ID!) { '
      'updateWhisperThread(input: { removeWhitelist: true threadID: '
      '\$threadID } ) { thread { id } } }';

  static const _notificationsDocument =
      'query OnsiteNotificationsForUserQuery(\$user: ID, \$limit: Int, '
      '\$cursor: Cursor, \$language: String, \$capabilities: '
      '[OnsiteNotificationsCapability!]) { user(id: \$user) { '
      'notifications(first: \$limit, after: \$cursor, language: \$language, '
      'capabilities: \$capabilities) { edges { cursor node { __typename '
      '...OnsiteNotificationFragment } } } } }  fragment '
      'OnsiteNotificationFragment on OnsiteNotification { actions { body '
      'type url } body category createdAt creators { profileImageURL(width: '
      '70) id displayName } destinationType displayType extra { __typename '
      '... on Clip { slug } ... on Video { id offsetSeconds title } ... on '
      'VideoComment { id contentOffsetSeconds video { id } } ... on '
      'ClipComment { id clip { slug } parentComment { id } } ... on User { '
      'login id } ... on Game { id } ... on OnsiteNotificationExternalLink { '
      'url } ... on OnsiteNotificationGuestStar { channelID channelName } '
      '... on Story { id creator { id } } ... on TwitchProvidedBackground { '
      'assetkey } ... on StoryClipBlock { clip { id } clipAsset { id } } ... '
      'on DropCampaign { id } ... on TimeBasedDrop { id } ... on '
      'EventBasedDrop { id } ... on ManualTriggerBasedDrop { id } ... on '
      'Subfeed { id feedLocation } ... on OnsiteNotificationRecap { id clip '
      '{ slug } } } id isRead thumbnailURL type updatedAt }';

  static const _summaryDocument =
      'query OnsiteNotificationsSummaryQuery(\$user: ID, \$capabilities: '
      '[OnsiteNotificationsCapability!]) { user(id: \$user) { '
      'notifications(capabilities: \$capabilities) { summary { lastSeenAt '
      'unseenCount safetyUnreadSummary { unreadCount } } } } }';

  static const _readDocument =
      'mutation ReadOnsiteNotificationMutation(\$input: '
      'ReadNotificationsInput!) { readNotifications(input: \$input) { count '
      '} }';

  static const _settingsDocument =
      'query UserNotificationSettingsQuery(\$user: ID) { user(id: \$user) { '
      'notificationSettings { category platforms { platformName '
      'settingState isEnabled } } } }';

  static const _sectionsDocument =
      'query PersonalSections(\$input: PersonalSectionInput!) { '
      'personalSections(input: \$input) { type title { localizedFallback } '
      'items { __typename ... on PersonalSectionChannel { user { id login '
      'displayName profileImageURL(width: 70) } content { __typename ... on '
      'Stream { id broadcaster { id broadcastSettings { id title } } codec '
      'isDualFormat viewersCount game { displayName } } } } } } }';

  static const _feedbackDocument =
      'mutation AddRecommendationFeedbackMutation(\$input: '
      'AddRecommendationFeedbackInput!) { addRecommendationFeedback(input: '
      '\$input) { recommendationFeedback { id } } }';

  Future<List<WhisperHistoryThread>?> whisperThreads({
    required String me,
    required String authToken,
  }) async {
    if (!_numericId.hasMatch(me)) return null;
    final data = await _query('UserWhisperThreadsQuery', _threadsDocument, {
      'limit': threadsPage,
    }, authToken: authToken);
    final user = data?['currentUser'];
    final threads = user is Map ? user['whisperThreads'] : null;
    final edges = threads is Map ? threads['edges'] : null;
    if (edges is! List) return null;
    return [
      for (final edge in edges)
        if (edge is Map) ?WhisperHistoryThread.fromJson(edge['node'], me: me),
    ];
  }

  Future<List<WhisperHistoryMessage>?> whisperMessages({
    required String threadId,
    required String authToken,
  }) async {
    if (!_threadId.hasMatch(threadId)) return null;
    final data = await _query('WhisperMessageQuery', _messagesDocument, {
      'thread': threadId,
      'numMessages': messagesPage,
    }, authToken: authToken);
    final thread = data?['whisperThread'];
    final messages = thread is Map ? thread['messages'] : null;
    final edges = messages is Map ? messages['edges'] : null;
    if (edges is! List) return null;
    return [
      for (final edge in edges)
        if (edge is Map) ?WhisperHistoryMessage.fromJson(edge['node']),
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  Future<WhisperPrivacy?> whisperPrivacy({required String authToken}) async {
    final data = await _query(
      'WhisperSettingsGetterQuery',
      _privacyDocument,
      const {},
      authToken: authToken,
    );
    final user = data?['currentUser'];
    return WhisperPrivacy.fromSettings(
      user is Map ? user['whisperSettings'] : null,
    );
  }

  Future<ViewerActionOutcome> setBlockStrangers({
    required bool block,
    required String authToken,
  }) => _send(
    'UpdateWhisperSettings',
    _updatePrivacyDocument,
    'updateWhisperSettings',
    {
      'input': {'isBlockingWhispersFromStrangers': block},
    },
    authToken: authToken,
    succeeded: (payload) {
      final user = payload['user'];
      final settings = user is Map ? user['whisperSettings'] : null;
      return WhisperPrivacy.fromSettings(settings)?.blockStrangers == block;
    },
  );

  Future<ViewerActionOutcome> removeWhisperAllowance({
    required String threadId,
    required String authToken,
  }) {
    if (!_threadId.hasMatch(threadId)) {
      return Future.value(ViewerActionOutcome.failed);
    }
    return _send(
      'RemoveWhisperThreadWhitelistMutation',
      _removeWhitelistDocument,
      'updateWhisperThread',
      {'threadID': threadId},
      authToken: authToken,
      succeeded: (payload) {
        final thread = payload['thread'];
        return thread is Map && thread['id'] == threadId;
      },
    );
  }

  Future<OnsiteNotificationPage?> notifications({
    required String userId,
    required String authToken,
    required String language,
    String? cursor,
  }) async {
    if (!_numericId.hasMatch(userId)) return null;
    if (cursor != null && !_opaqueId.hasMatch(cursor)) return null;
    final data = await _query(
      'OnsiteNotificationsForUserQuery',
      _notificationsDocument,
      {
        'user': userId,
        'limit': notificationsPage,
        'language': ?_languageOf(language),
        'cursor': ?cursor,
      },
      authToken: authToken,
    );
    final user = data?['user'];
    final notifications = user is Map ? user['notifications'] : null;
    final edges = notifications is Map ? notifications['edges'] : null;
    if (edges is! List) return null;
    String? last;
    final parsed = <OnsiteNotification>[];
    for (final edge in edges) {
      if (edge is! Map) continue;
      final edgeCursor = edge['cursor'];
      if (edgeCursor is String && _opaqueId.hasMatch(edgeCursor)) {
        last = edgeCursor;
      }
      if (OnsiteNotification.fromJson(edge['node']) case final n?) {
        parsed.add(n);
      }
    }
    return OnsiteNotificationPage(
      notifications: parsed,
      cursor: edges.length >= notificationsPage ? last : null,
    );
  }

  Future<int?> unseenNotifications({
    required String userId,
    required String authToken,
  }) async {
    if (!_numericId.hasMatch(userId)) return null;
    final data = await _query(
      'OnsiteNotificationsSummaryQuery',
      _summaryDocument,
      {'user': userId},
      authToken: authToken,
    );
    final user = data?['user'];
    final notifications = user is Map ? user['notifications'] : null;
    final summary = notifications is Map ? notifications['summary'] : null;
    final count = summary is Map ? summary['unseenCount'] : null;
    return count is int && count >= 0 ? count : null;
  }

  Future<ViewerActionOutcome> markNotificationsRead({
    required List<String> ids,
    required String authToken,
  }) {
    if (ids.isEmpty || ids.any((id) => !_opaqueId.hasMatch(id))) {
      return Future.value(ViewerActionOutcome.failed);
    }
    return _send(
      'ReadOnsiteNotificationMutation',
      _readDocument,
      'readNotifications',
      {
        'input': {'ids': ids},
      },
      authToken: authToken,
      succeeded: (payload) => payload['count'] is int,
    );
  }

  Future<List<NotificationCategorySetting>?> notificationSettings({
    required String userId,
    required String authToken,
  }) async {
    if (!_numericId.hasMatch(userId)) return null;
    final data = await _query(
      'UserNotificationSettingsQuery',
      _settingsDocument,
      {'user': userId},
      authToken: authToken,
    );
    final user = data?['user'];
    final settings = user is Map ? user['notificationSettings'] : null;
    if (settings is! List) return null;
    final parsed = [
      for (final setting in settings)
        ?NotificationCategorySetting.fromJson(setting),
    ];
    return parsed.isEmpty ? null : parsed;
  }

  Future<List<RecommendedChannel>?> recommendations({
    required RecommendationSection section,
    String? channelLogin,
    String? authToken,
  }) async {
    final login = channelLogin?.toLowerCase();
    if (login != null && !_login.hasMatch(login)) return null;
    final data = await _query('PersonalSections', _sectionsDocument, {
      'input': {
        'sectionInputs': [section.apiValue],
        'contextChannelName': ?login,
      },
    }, authToken: authToken);
    final sections = data?['personalSections'];
    if (sections is! List) return null;
    final seen = <String>{};
    final channels = <RecommendedChannel>[];
    for (final section in sections) {
      final items = section is Map ? section['items'] : null;
      if (items is! List) continue;
      for (final item in items) {
        final channel = RecommendedChannel.fromItem(item);
        if (channel == null || channel.login == login) continue;
        if (!seen.add(channel.userId)) continue;
        channels.add(channel);
        if (channels.length >= maxRecommendations) return channels;
      }
    }
    return channels;
  }

  Future<ViewerActionOutcome> notInterested({
    required String channelId,
    required NotInterestedReason reason,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId)) {
      return Future.value(ViewerActionOutcome.failed);
    }
    return _send(
      'AddRecommendationFeedbackMutation',
      _feedbackDocument,
      'addRecommendationFeedback',
      {
        'input': {
          'category': reason.apiValue,
          'itemID': channelId,
          'itemType': 'CHANNEL',
          'sourceItemPage': '',
          'sourceItemRequestID': '',
          'sourceItemTrackingID': '',
        },
      },
      authToken: authToken,
      succeeded: (payload) => payload['recommendationFeedback'] is Map,
    );
  }

  static String? _languageOf(String code) {
    final language = code.split(RegExp('[-_]')).first.toLowerCase();
    return RegExp(r'^[a-z]{2,3}$').hasMatch(language) ? language : null;
  }

  static Map<String, String> _headers(String? authToken) => {
    'Client-ID': kTwitchWebClientId,
    if (authToken != null && authToken.isNotEmpty)
      'Authorization': 'OAuth $authToken',
  };

  Future<Map<dynamic, dynamic>?> _query(
    String operation,
    String document,
    Map<String, Object?> variables, {
    String? authToken,
  }) async {
    if (authToken != null && authToken.isEmpty) return null;
    try {
      final Object? body = await post<dynamic>(
        kTwitchGqlUrl,
        headers: _headers(authToken),
        data: {
          'operationName': operation,
          'query': document,
          'variables': variables,
        },
      );
      if (body is! Map) return null;
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) return null;
      final data = body['data'];
      return data is Map ? data : null;
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return null;
    }
  }

  Future<ViewerActionOutcome> _send(
    String operation,
    String document,
    String field,
    Map<String, Object?> variables, {
    required String authToken,
    required bool Function(Map<dynamic, dynamic> payload) succeeded,
  }) async {
    if (authToken.isEmpty) return ViewerActionOutcome.signedOut;
    try {
      final Object? body = await post<dynamic>(
        kTwitchGqlUrl,
        extra: TwitchTvSessionInterceptor.userAction,
        headers: _headers(authToken),
        data: {
          'operationName': operation,
          'query': document,
          'variables': variables,
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
    bool Function(Map<dynamic, dynamic> payload) succeeded,
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
    return succeeded(payload)
        ? ViewerActionOutcome.done
        : ViewerActionOutcome.failed;
  }
}
