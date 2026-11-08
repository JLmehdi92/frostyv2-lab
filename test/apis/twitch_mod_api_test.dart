import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchModApi api;
  late List<RequestOptions> requests;

  const helix = 'https://api.twitch.tv/helix';
  const ids = {'broadcaster_id': '11', 'moderator_id': '22'};

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    api = TwitchApi(dio).moderation;
  });

  test('singleLine flattens line breaks and caps the length', () {
    expect(singleLine('  hello\nworld\r\n!  '), 'hello world !');
    expect(singleLine('a b'), 'a b');
    expect(singleLine('abcdef', maxLength: 3), 'abc');
    expect(singleLine('😀😀😀', maxLength: 2), '😀😀');
  });

  test('stream tags are letters and numbers only', () {
    expect(isValidStreamTag('English'), isTrue);
    expect(isValidStreamTag('Français2'), isTrue);
    expect(isValidStreamTag('हिंदी'), isTrue);
    expect(isValidStreamTag('no spaces'), isFalse);
    expect(isValidStreamTag('a-b'), isFalse);
    expect(isValidStreamTag('x' * 26), isFalse);
  });

  test('an announcement goes out on one line, quietly', () async {
    adapter.onPost(
      '$helix/chat/announcements',
      (server) => server.reply(204, null),
      queryParameters: ids,
      data: {'message': 'hello PRIVMSG #x :evil', 'color': 'purple'},
    );

    await api.sendAnnouncement(
      broadcasterId: '11',
      moderatorId: '22',
      message: 'hello\r\nPRIVMSG #x :evil',
      color: AnnouncementColor.purple,
    );
    expect(requests.single.extra[UnauthorizedInterceptor.quiet], isTrue);
  });

  test('an empty announcement is refused before any request', () {
    expect(
      () => api.sendAnnouncement(
        broadcasterId: '11',
        moderatorId: '22',
        message: ' \n ',
      ),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });

  test('a shoutout names both channels and the moderator', () async {
    adapter.onPost(
      '$helix/chat/shoutouts',
      (server) => server.reply(204, null),
      queryParameters: {
        'from_broadcaster_id': '11',
        'to_broadcaster_id': '33',
        'moderator_id': '22',
      },
    );

    await api.sendShoutout(
      broadcasterId: '11',
      moderatorId: '22',
      toBroadcasterId: '33',
    );
  });

  test('ids that are not Twitch ids never reach a query', () {
    expect(
      () => api.sendShoutout(
        broadcasterId: '11',
        moderatorId: '22',
        toBroadcasterId: '33&user_id=1',
      ),
      throwsArgumentError,
    );
    expect(
      () => api.setRole(
        broadcasterId: '11',
        userId: 'abc',
        role: ChannelRole.vip,
        granted: true,
      ),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });

  test('roles are read page by page and changed per user', () async {
    adapter
      ..onGet(
        '$helix/moderation/moderators',
        (server) => server.reply(200, {
          'data': [
            {'user_id': '1', 'user_login': 'mira', 'user_name': 'Mira'},
          ],
          'pagination': {'cursor': 'next'},
        }),
        queryParameters: {'broadcaster_id': '11', 'first': 100},
      )
      ..onGet(
        '$helix/moderation/moderators',
        (server) => server.reply(200, {
          'data': [
            {'user_id': '2', 'user_login': 'ana', 'user_name': ''},
          ],
          'pagination': {},
        }),
        queryParameters: {
          'broadcaster_id': '11',
          'first': 100,
          'after': 'next',
        },
      )
      ..onPost(
        '$helix/channels/vips',
        (server) => server.reply(204, null),
        queryParameters: {'broadcaster_id': '11', 'user_id': '33'},
      )
      ..onDelete(
        '$helix/moderation/moderators',
        (server) => server.reply(204, null),
        queryParameters: {'broadcaster_id': '11', 'user_id': '33'},
      );

    final mods = await api.getRoleUsers(
      broadcasterId: '11',
      role: ChannelRole.moderator,
    );
    expect([for (final m in mods) m.displayName], ['Mira', 'ana']);

    await api.setRole(
      broadcasterId: '11',
      userId: '33',
      role: ChannelRole.vip,
      granted: true,
    );
    await api.setRole(
      broadcasterId: '11',
      userId: '33',
      role: ChannelRole.moderator,
      granted: false,
    );
  });

  test('shield mode is read and set', () async {
    adapter
      ..onGet(
        '$helix/moderation/shield_mode',
        (server) => server.reply(200, {
          'data': [
            {'is_active': true, 'moderator_name': 'Mira'},
          ],
        }),
        queryParameters: ids,
      )
      ..onPut(
        '$helix/moderation/shield_mode',
        (server) => server.reply(200, {
          'data': [
            {'is_active': false},
          ],
        }),
        queryParameters: ids,
        data: {'is_active': false},
      );

    final status = await api.getShieldMode(
      broadcasterId: '11',
      moderatorId: '22',
    );
    expect(status.isActive, isTrue);
    expect(status.moderatorName, 'Mira');
    final updated = await api.setShieldMode(
      broadcasterId: '11',
      moderatorId: '22',
      active: false,
    );
    expect(updated.isActive, isFalse);
    expect(requests.last.extra[UnauthorizedInterceptor.quiet], isTrue);
  });

  test('a marker, an ad break and a raid', () async {
    adapter
      ..onPost(
        '$helix/streams/markers',
        (server) => server.reply(200, {'data': []}),
        data: {'user_id': '11', 'description': 'great play'},
      )
      ..onPost(
        '$helix/channels/commercial',
        (server) => server.reply(200, {
          'data': [
            {'length': 60, 'retry_after': 480},
          ],
        }),
        data: {'broadcaster_id': '11', 'length': 60},
      )
      ..onPost(
        '$helix/raids',
        (server) => server.reply(200, {'data': []}),
        queryParameters: {
          'from_broadcaster_id': '11',
          'to_broadcaster_id': '33',
        },
      )
      ..onDelete(
        '$helix/raids',
        (server) => server.reply(204, null),
        queryParameters: {'broadcaster_id': '11'},
      );

    await api.createMarker(broadcasterId: '11', description: 'great\nplay');
    final ad = await api.startCommercial(broadcasterId: '11', seconds: 60);
    expect(ad.retryAfter, 480);
    await api.startRaid(broadcasterId: '11', toBroadcasterId: '33');
    await api.cancelRaid(broadcasterId: '11');
  });

  test('ad lengths and raid targets Twitch refuses are refused here', () {
    expect(
      () => api.startCommercial(broadcasterId: '11', seconds: 181),
      throwsArgumentError,
    );
    expect(
      () => api.startRaid(broadcasterId: '11', toBroadcasterId: '11'),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });

  test('blocked terms: list, add, remove', () async {
    adapter
      ..onGet(
        '$helix/moderation/blocked_terms',
        (server) => server.reply(200, {
          'data': [
            {'id': 'term-1', 'text': 'spoiler', 'expires_at': null},
          ],
        }),
        queryParameters: {...ids, 'first': 100},
      )
      ..onPost(
        '$helix/moderation/blocked_terms',
        (server) => server.reply(200, {
          'data': [
            {'id': 'term-2', 'text': 'scam link'},
          ],
        }),
        queryParameters: ids,
        data: {'text': 'scam link'},
      )
      ..onDelete(
        '$helix/moderation/blocked_terms',
        (server) => server.reply(204, null),
        queryParameters: {...ids, 'id': 'term-1'},
      );

    final terms = await api.getBlockedTerms(
      broadcasterId: '11',
      moderatorId: '22',
    );
    expect(terms.single.text, 'spoiler');
    final added = await api.addBlockedTerm(
      broadcasterId: '11',
      moderatorId: '22',
      text: 'scam\nlink',
    );
    expect(added.id, 'term-2');
    await api.removeBlockedTerm(
      broadcasterId: '11',
      moderatorId: '22',
      termId: 'term-1',
    );
    expect(
      () =>
          api.addBlockedTerm(broadcasterId: '11', moderatorId: '22', text: 'a'),
      throwsArgumentError,
    );
    expect(
      () => api.removeBlockedTerm(
        broadcasterId: '11',
        moderatorId: '22',
        termId: 'a&id=b',
      ),
      throwsArgumentError,
    );
  });

  test('held messages and unban requests', () async {
    adapter
      ..onPost(
        '$helix/moderation/automod/message',
        (server) => server.reply(204, null),
        data: {'user_id': '22', 'msg_id': 'msg-1', 'action': 'DENY'},
      )
      ..onGet(
        '$helix/moderation/unban_requests',
        (server) => server.reply(200, {
          'data': [
            {
              'id': 'req-1',
              'user_id': '33',
              'user_login': 'ana',
              'user_name': 'Ana',
              'text': 'sorry',
              'status': 'pending',
              'created_at': '2026-11-07T10:00:00Z',
            },
          ],
        }),
        queryParameters: {...ids, 'status': 'pending', 'first': 100},
      )
      ..onPatch(
        '$helix/moderation/unban_requests',
        (server) => server.reply(200, {'data': []}),
        queryParameters: {
          ...ids,
          'unban_request_id': 'req-1',
          'status': 'approved',
          'resolution_text': 'welcome back',
        },
      );

    await api.resolveHeldMessage(
      moderatorId: '22',
      messageId: 'msg-1',
      decision: AutoModDecision.deny,
    );
    final requests = await api.getPendingUnbanRequests(
      broadcasterId: '11',
      moderatorId: '22',
    );
    expect(requests.single.displayName, 'Ana');
    await api.resolveUnbanRequest(
      broadcasterId: '11',
      moderatorId: '22',
      requestId: 'req-1',
      approve: true,
      resolution: 'welcome\nback',
    );
  });

  test('suspicious status is added and removed', () async {
    adapter
      ..onPost(
        '$helix/moderation/suspicious_users',
        (server) => server.reply(200, {'data': []}),
        queryParameters: ids,
        data: {'user_id': '33', 'status': 'RESTRICTED'},
      )
      ..onDelete(
        '$helix/moderation/suspicious_users',
        (server) => server.reply(200, {'data': []}),
        queryParameters: {...ids, 'user_id': '33'},
      );

    await api.setSuspiciousStatus(
      broadcasterId: '11',
      moderatorId: '22',
      userId: '33',
      status: SuspiciousStatus.restricted,
    );
    await api.setSuspiciousStatus(
      broadcasterId: '11',
      moderatorId: '22',
      userId: '33',
      status: null,
    );
  });

  test('a ban is read for one user, a timeout has its end', () async {
    adapter.onGet(
      '$helix/moderation/banned',
      (server) => server.reply(200, {
        'data': [
          {'user_id': '33', 'expires_at': '2026-11-07T10:10:00Z'},
        ],
      }),
      queryParameters: {'broadcaster_id': '11', 'user_id': '33'},
    );

    final ban = await api.getBan(broadcasterId: '11', userId: '33');
    expect(ban?.timeoutEndsAt, DateTime.utc(2026, 11, 7, 10, 10));
  });

  test('polls: create with clean choices, end', () async {
    adapter
      ..onPost(
        '$helix/polls',
        (server) => server.reply(200, {
          'data': [
            {
              'id': 'poll-1',
              'title': 'Next game?',
              'status': 'ACTIVE',
              'choices': [
                {'id': 'a', 'title': 'Chess', 'votes': 3},
                {'id': 'b', 'title': 'Go', 'votes': 1},
              ],
            },
          ],
        }),
        data: {
          'broadcaster_id': '11',
          'title': 'Next game?',
          'choices': [
            {'title': 'Chess'},
            {'title': 'Go'},
          ],
          'duration': 120,
        },
      )
      ..onPatch(
        '$helix/polls',
        (server) => server.reply(200, {
          'data': [
            {'id': 'poll-1', 'title': 'Next game?', 'status': 'TERMINATED'},
          ],
        }),
        data: {'broadcaster_id': '11', 'id': 'poll-1', 'status': 'TERMINATED'},
      );

    final poll = await api.createPoll(
      broadcasterId: '11',
      title: 'Next game?',
      choices: ['Chess', ' ', 'Go'],
      duration: const Duration(minutes: 2),
    );
    expect(poll.isActive, isTrue);
    expect(poll.totalVotes, 4);
    final ended = await api.endPoll(broadcasterId: '11', pollId: 'poll-1');
    expect(ended.isActive, isFalse);
    expect(
      () => api.createPoll(
        broadcasterId: '11',
        title: 'Q',
        choices: ['only one'],
        duration: const Duration(minutes: 2),
      ),
      throwsArgumentError,
    );
  });

  test('predictions: a result needs a winner', () async {
    adapter.onPatch(
      '$helix/predictions',
      (server) => server.reply(200, {
        'data': [
          {'id': 'p-1', 'title': 'Win?', 'status': 'RESOLVED'},
        ],
      }),
      data: {
        'broadcaster_id': '11',
        'id': 'p-1',
        'status': 'RESOLVED',
        'winning_outcome_id': 'o-1',
      },
    );

    expect(
      () => api.endPrediction(
        broadcasterId: '11',
        predictionId: 'p-1',
        end: PredictionEnd.resolved,
      ),
      throwsArgumentError,
    );
    final resolved = await api.endPrediction(
      broadcasterId: '11',
      predictionId: 'p-1',
      end: PredictionEnd.resolved,
      winningOutcomeId: 'o-1',
    );
    expect(resolved.isOpen, isFalse);
  });

  test('reward requests come from the rewards this app manages', () async {
    adapter
      ..onGet(
        '$helix/channel_points/custom_rewards',
        (server) => server.reply(200, {
          'data': [
            {'id': 'r-1', 'title': 'Hydrate'},
          ],
        }),
        queryParameters: {
          'broadcaster_id': '11',
          'only_manageable_rewards': true,
        },
      )
      ..onGet(
        '$helix/channel_points/custom_rewards/redemptions',
        (server) => server.reply(200, {
          'data': [
            {
              'id': 'x-1',
              'user_login': 'ana',
              'user_name': 'Ana',
              'user_input': 'now',
              'redeemed_at': '2026-11-07T10:00:00Z',
              'reward': {'id': 'r-1', 'title': 'Hydrate', 'cost': 500},
            },
          ],
        }),
        queryParameters: {
          'broadcaster_id': '11',
          'reward_id': 'r-1',
          'status': 'UNFULFILLED',
          'sort': 'OLDEST',
          'first': 100,
        },
      )
      ..onPatch(
        '$helix/channel_points/custom_rewards/redemptions',
        (server) => server.reply(200, {'data': []}),
        queryParameters: {
          'id': 'x-1',
          'broadcaster_id': '11',
          'reward_id': 'r-1',
        },
        data: {'status': 'CANCELED'},
      );

    final pending = await api.getPendingRedemptions(broadcasterId: '11');
    expect(pending.single.reward.cost, 500);
    await api.resolveRedemption(
      broadcasterId: '11',
      rewardId: 'r-1',
      redemptionId: 'x-1',
      decision: RedemptionDecision.canceled,
    );
  });

  test('stream info: title, category and tags', () async {
    adapter.onPatch(
      '$helix/channels',
      (server) => server.reply(204, null),
      queryParameters: {'broadcaster_id': '11'},
      data: {
        'title': 'Speedruns',
        'game_id': '509658',
        'tags': ['English', 'Speedrun'],
      },
    );

    await api.updateStreamInfo(
      broadcasterId: '11',
      title: 'Speedruns',
      gameId: '509658',
      tags: ['English', 'Speedrun', 'English'],
    );
    expect(
      () => api.updateStreamInfo(broadcasterId: '11', tags: ['two words']),
      throwsArgumentError,
    );
    expect(
      () => api.updateStreamInfo(broadcasterId: '11'),
      throwsArgumentError,
    );
  });

  test('a refusal is an ApiException the caller words', () async {
    adapter.onPost(
      '$helix/chat/shoutouts',
      (server) => server.reply(429, {'message': 'cooldown'}),
      queryParameters: {
        'from_broadcaster_id': '11',
        'to_broadcaster_id': '33',
        'moderator_id': '22',
      },
    );

    await expectLater(
      api.sendShoutout(
        broadcasterId: '11',
        moderatorId: '22',
        toBroadcasterId: '33',
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
