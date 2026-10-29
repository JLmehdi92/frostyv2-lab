import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TwitchApi api;

  const helix = 'https://api.twitch.tv/helix';
  const ids = {'broadcaster_id': '11', 'moderator_id': '22'};

  setUp(() {
    dio = Dio(BaseOptions());
    dioAdapter = DioAdapter(dio: dio);
    api = TwitchApi(dio);
  });

  group('banUser', () {
    test('bans with a reason and no duration', () async {
      dioAdapter.onPost(
        '$helix/moderation/bans',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {
          'data': {'user_id': '33', 'reason': 'spam'},
        },
      );

      await api.banUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        reason: 'spam',
      );
    });

    test('a duration makes it a timeout', () async {
      dioAdapter.onPost(
        '$helix/moderation/bans',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {
          'data': {'user_id': '33', 'duration': 600, 'reason': ''},
        },
      );

      await api.banUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        duration: const Duration(minutes: 10),
      );
    });

    test('refuses a duration Twitch does not accept', () {
      for (final duration in [
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(days: 15),
      ]) {
        expect(
          () => api.banUser(
            broadcasterId: '11',
            moderatorId: '22',
            userId: '33',
            duration: duration,
          ),
          throwsArgumentError,
        );
      }
    });

    test('refuses ids that are not Twitch ids', () {
      expect(
        () => api.banUser(
          broadcasterId: '11',
          moderatorId: '22',
          userId: '33&user_id=44',
        ),
        throwsArgumentError,
      );
    });

    test('keeps the reason within Twitch limits', () async {
      final long = 'a' * 600;
      dioAdapter.onPost(
        '$helix/moderation/bans',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {
          'data': {'user_id': '33', 'reason': 'a' * 500},
        },
      );

      await api.banUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        reason: long,
      );
    });

    test("Twitch's refusal comes through", () {
      dioAdapter.onPost(
        '$helix/moderation/bans',
        (server) => server.reply(400, {
          'message':
              'The user specified in the user_id field is already '
              'banned.',
        }),
        queryParameters: ids,
        data: Matchers.any,
      );

      expect(
        () => api.banUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('already banned'),
          ),
        ),
      );
    });
  });

  test('unbanUser lifts a ban or a timeout', () async {
    dioAdapter.onDelete(
      '$helix/moderation/bans',
      (server) => server.reply(204, null),
      queryParameters: {...ids, 'user_id': '33'},
    );

    await api.unbanUser(broadcasterId: '11', moderatorId: '22', userId: '33');
  });

  group('deleteChatMessages', () {
    test('one message', () async {
      dioAdapter.onDelete(
        '$helix/moderation/chat',
        (server) => server.reply(204, null),
        queryParameters: {...ids, 'message_id': 'abc-123'},
      );

      await api.deleteChatMessages(
        broadcasterId: '11',
        moderatorId: '22',
        messageId: 'abc-123',
      );
    });

    test('without a message clears the chat', () async {
      dioAdapter.onDelete(
        '$helix/moderation/chat',
        (server) => server.reply(204, null),
        queryParameters: ids,
      );

      await api.deleteChatMessages(broadcasterId: '11', moderatorId: '22');
    });

    test('refuses a message id that is not one', () {
      expect(
        () => api.deleteChatMessages(
          broadcasterId: '11',
          moderatorId: '22',
          messageId: 'a b',
        ),
        throwsArgumentError,
      );
    });
  });

  test('warnUser sends the reason', () async {
    dioAdapter.onPost(
      '$helix/moderation/warnings',
      (server) => server.reply(200, {'data': []}),
      queryParameters: ids,
      data: {
        'data': {'user_id': '33', 'reason': 'be nice'},
      },
    );

    await api.warnUser(
      broadcasterId: '11',
      moderatorId: '22',
      userId: '33',
      reason: 'be nice',
    );
  });

  test('warnUser needs a reason', () {
    expect(
      () => api.warnUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        reason: '  ',
      ),
      throwsArgumentError,
    );
  });

  group('updateChatSettings', () {
    test('sends only what changes', () async {
      dioAdapter.onPatch(
        '$helix/chat/settings',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {'slow_mode': true, 'slow_mode_wait_time': 30},
      );

      await api.updateChatSettings(
        broadcasterId: '11',
        moderatorId: '22',
        slowMode: true,
        slowModeWaitTime: const Duration(seconds: 30),
      );
    });

    test('every mode', () async {
      dioAdapter.onPatch(
        '$helix/chat/settings',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {
          'emote_mode': false,
          'follower_mode': true,
          'follower_mode_duration': 10,
          'subscriber_mode': true,
          'unique_chat_mode': false,
        },
      );

      await api.updateChatSettings(
        broadcasterId: '11',
        moderatorId: '22',
        emoteMode: false,
        followerMode: true,
        followerModeDuration: const Duration(minutes: 10),
        subscriberMode: true,
        uniqueChatMode: false,
      );
    });

    test('refuses a slow wait or follow age out of range', () {
      expect(
        () => api.updateChatSettings(
          broadcasterId: '11',
          moderatorId: '22',
          slowMode: true,
          slowModeWaitTime: const Duration(seconds: 2),
        ),
        throwsArgumentError,
      );
      expect(
        () => api.updateChatSettings(
          broadcasterId: '11',
          moderatorId: '22',
          followerMode: true,
          followerModeDuration: const Duration(days: 91),
        ),
        throwsArgumentError,
      );
    });

    test('refuses an empty change', () {
      expect(
        () => api.updateChatSettings(broadcasterId: '11', moderatorId: '22'),
        throwsArgumentError,
      );
    });
  });

  group('getFollowedAt', () {
    const query = {'broadcaster_id': '11', 'user_id': '33'};

    test('the follow date of a follower', () async {
      dioAdapter.onGet(
        '$helix/channels/followers',
        (server) => server.reply(200, {
          'total': 8,
          'data': [
            {
              'user_id': '33',
              'user_login': 'troll',
              'user_name': 'Troll',
              'followed_at': '2023-01-02T03:04:05Z',
            },
          ],
          'pagination': <String, Object>{},
        }),
        queryParameters: query,
      );

      expect(
        await api.getFollowedAt(broadcasterId: '11', userId: '33'),
        DateTime.utc(2023, 1, 2, 3, 4, 5),
      );
    });

    test('not following, or only the total given: unknown', () async {
      dioAdapter.onGet(
        '$helix/channels/followers',
        (server) => server.reply(200, {'total': 8, 'data': []}),
        queryParameters: query,
      );
      expect(
        await api.getFollowedAt(broadcasterId: '11', userId: '33'),
        isNull,
      );
    });

    test('someone else answered: unknown', () async {
      dioAdapter.onGet(
        '$helix/channels/followers',
        (server) => server.reply(200, {
          'data': [
            {'user_id': '44', 'followed_at': '2023-01-02T03:04:05Z'},
          ],
        }),
        queryParameters: query,
      );
      expect(
        await api.getFollowedAt(broadcasterId: '11', userId: '33'),
        isNull,
      );
    });

    test('a token without the scope fails quietly', () async {
      final extras = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            extras.add(options.extra);
            handler.next(options);
          },
        ),
      );
      dioAdapter.onGet(
        '$helix/channels/followers',
        (server) => server.reply(401, {'message': 'Missing scope'}),
        queryParameters: query,
      );

      await expectLater(
        api.getFollowedAt(broadcasterId: '11', userId: '33'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(extras.single[UnauthorizedInterceptor.quiet], isTrue);
    });

    test('refuses ids that are not Twitch ids', () {
      expect(
        () => api.getFollowedAt(broadcasterId: '11', userId: 'x'),
        throwsArgumentError,
      );
    });
  });
}
