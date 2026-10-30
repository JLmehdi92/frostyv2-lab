import 'dart:async' show TimeoutException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart' hide TimeoutException;
import 'package:onset/constants.dart';
import 'package:onset/models/chat_history.dart';

/// The chat said in a channel before the viewer joined, the way the
/// official Twitch app loads it: one `ChatHistory` GQL query reading
/// `Channel.recentChatMessages`.
///
/// Twitch answers it only for a logged-in twitch.tv session, so it is read
/// with the viewer's twitch.tv web token (the one 2K uses) and the web
/// Client-ID. ONSET's own Helix token is never sent here: GQL refuses it,
/// and it is not Twitch's web session.
///
/// Read only, once per chat opened. Every failure (no answer within
/// [timeout], a refused token, a GQL error, data that cannot be read) is
/// an empty history: the chat works the same without it, and nothing here
/// retries.
class TwitchChatHistoryService extends BaseApiClient {
  TwitchChatHistoryService(Dio dio, {this.timeout = const Duration(seconds: 4)})
    : super(dio, '');

  /// How long the history may take: past it, the chat goes on without.
  final Duration timeout;

  /// The most messages kept (the newest), whatever Twitch sends.
  static const maxMessages = 200;

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _channelId = RegExp(r'^[0-9]{1,20}$');
  static final _channelLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  // The fields of the official app's ChatHistory documents (Android 31.5.2,
  // its web portal's `channel(name:)` form with the channel's badges) that
  // ONSET draws: no AutoMod topics, no Shared Chat source badges.
  static const _query =
      'query ChatHistory(\$channelLogin: String!, \$channelID: ID) { '
      'channel(name: \$channelLogin) { recentChatMessages { '
      'id sentAt deletedAt '
      'content { text fragments { text content { __typename '
      '... on Emote { id } '
      '... on CheermoteToken { bitsAmount } '
      '... on GifContent { id url } } } } '
      'sender { id login displayName chatColor } '
      'senderBadges(channelID: \$channelID) { setID version } '
      'senderChatColor '
      'sourceChannel { id } '
      'parentMessage { id content { text } sender { id login displayName } } '
      'threadParentMessage { id sender { id login displayName } } '
      '} } }';

  /// The recent chat of the channel [channelLogin] ([channelId]), oldest
  /// first as Twitch sends it, read with the twitch.tv web token
  /// [authToken]; empty when it is not available.
  Future<List<ChatHistoryMessage>> getRecentMessages({
    required String channelLogin,
    required String channelId,
    required String authToken,
  }) async {
    if (authToken.isEmpty ||
        !_channelLogin.hasMatch(channelLogin) ||
        !_channelId.hasMatch(channelId)) {
      return const [];
    }
    final cancel = CancelToken();
    try {
      final body =
          await post<Object?>(
            _gqlUrl,
            headers: {
              'Client-ID': kTwitchWebClientId,
              'Authorization': 'OAuth $authToken',
            },
            data: {
              'operationName': 'ChatHistory',
              'query': _query,
              'variables': {
                'channelLogin': channelLogin.toLowerCase(),
                'channelID': channelId,
              },
            },
            cancelToken: cancel,
            // The token must not follow a redirect to another host.
            followRedirects: false,
          ).timeout(
            timeout,
            onTimeout: () {
              cancel.cancel();
              throw TimeoutException('Chat history', timeout);
            },
          );
      return _parse(body);
    } catch (e) {
      // The type only: the error can carry the request (and its token).
      if (kDebugMode) debugPrint('Chat history unavailable: ${e.runtimeType}');
      return const [];
    }
  }

  static List<ChatHistoryMessage> _parse(Object? body) {
    if (body is! Map) return const [];
    // An error beside data is not trusted either: the list may be partial.
    if (body['errors'] != null) {
      if (kDebugMode) debugPrint('Chat history unavailable: GQL error');
      return const [];
    }
    final data = body['data'];
    final channel = data is Map ? data['channel'] : null;
    final recent = channel is Map ? channel['recentChatMessages'] : null;
    if (recent is! List) return const [];
    // The newest only, cut before reading: a huge answer costs nothing.
    final newest = recent.length > maxMessages
        ? recent.sublist(recent.length - maxMessages)
        : recent;
    return [for (final entry in newest) ?ChatHistoryMessage.tryParse(entry)];
  }
}
