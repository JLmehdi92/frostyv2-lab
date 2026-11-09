import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/drop_campaign.dart';

import 'package:onset/models/weekly_rewards.dart';

import '../fixtures/community_goal_payloads.dart';
import '../fixtures/drops_gql_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchViewerActionsService service;
  late List<RequestOptions> requests;

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
    service = TwitchViewerActionsService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  Map<String, dynamic> sent() {
    final data = requests.single.data;
    return Map<String, dynamic>.from(
      data is String ? jsonDecode(data) as Map : data as Map,
    );
  }

  group('voteInPoll', () {
    Future<ViewerActionOutcome> vote() => service.voteInPoll(
      pollId: 'poll-1',
      choiceId: 'choice-2',
      userId: '77',
      authToken: 'tok',
    );

    test(
      'sends the poll vote with a fresh vote id and the viewer token',
      () async {
        reply({
          'data': {
            'voteInPoll': {
              'voter': {'id': 'v'},
              'error': null,
            },
          },
        });

        expect(await vote(), ViewerActionOutcome.done);
        final body = sent();
        expect(body['operationName'], 'PollsVoteMutation');
        expect(body['query'], contains('voteInPoll(input: \$input)'));
        final input = (body['variables'] as Map)['input'] as Map;
        expect(input['pollID'], 'poll-1');
        expect(input['choiceID'], 'choice-2');
        expect(input['userID'], '77');
        expect(input['voteID'], isA<String>());
        expect((input['voteID'] as String).isNotEmpty, isTrue);
        expect(requests.single.headers['Authorization'], 'OAuth tok');
        expect(
          requests.single.headers['Client-ID'],
          'kimne78kx3ncx6brgo4mv6wki5h1ko',
        );
      },
    );

    test('two votes never share a vote id', () async {
      reply({
        'data': {
          'voteInPoll': {'error': null},
        },
      });
      await vote();
      await vote();
      String id(RequestOptions r) {
        final data = r.data is String ? jsonDecode(r.data as String) : r.data;
        return ((data as Map)['variables'] as Map)['input']['voteID'] as String;
      }

      expect(id(requests[0]), isNot(id(requests[1])));
    });

    test('an error code is a refusal', () async {
      reply({
        'data': {
          'voteInPoll': {
            'error': {'code': 'POLL_NOT_ACTIVE'},
          },
        },
      });

      expect(await vote(), ViewerActionOutcome.refused);
    });

    test('an integrity error is told apart', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      expect(await vote(), ViewerActionOutcome.integrityRefused);
    });

    test('a missing payload fails closed', () async {
      reply({
        'data': {'voteInPoll': null},
      });

      expect(await vote(), ViewerActionOutcome.failed);
    });

    test('a refused token asks to sign in again', () async {
      reply({'error': 'Unauthorized'}, status: 401);

      expect(await vote(), ViewerActionOutcome.signedOut);
    });

    test('a server error fails without throwing', () async {
      reply('oops', status: 500);

      expect(await vote(), ViewerActionOutcome.failed);
    });

    test('nothing is sent without a token or with a bad id', () async {
      expect(
        await service.voteInPoll(
          pollId: 'p',
          choiceId: 'c',
          userId: '77',
          authToken: '',
        ),
        ViewerActionOutcome.signedOut,
      );
      expect(
        await service.voteInPoll(
          pollId: 'p',
          choiceId: 'c',
          userId: 'x y',
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
      expect(requests, isEmpty);
    });
  });

  group('raids', () {
    test('joinRaid sends the raid id', () async {
      reply({
        'data': {
          'joinRaid': {'raidID': 'raid-9'},
        },
      });

      expect(
        await service.joinRaid(raidId: 'raid-9', authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], 'JoinRaidMutation');
      expect((body['variables'] as Map)['input'], 'raid-9');
    });

    test('leaveRaid sends the raid id', () async {
      reply({
        'data': {
          'leaveRaid': {'raidID': 'raid-9'},
        },
      });

      expect(
        await service.leaveRaid(raidId: 'raid-9', authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], 'LeaveRaidMutation');
      expect((body['variables'] as Map)['input'], 'raid-9');
    });

    test('a raid answer without the raid id fails closed', () async {
      reply({
        'data': {'leaveRaid': null},
      });

      expect(
        await service.leaveRaid(raidId: 'raid-9', authToken: 'tok'),
        ViewerActionOutcome.failed,
      );
    });
  });

  group('shareWatchStreak', () {
    test('sends the milestone and channel', () async {
      reply({
        'data': {
          'shareViewerMilestone': {
            'milestone': {'id': 'm1', 'shareStatus': 'SHARED'},
            'error': null,
          },
        },
      });

      expect(
        await service.shareWatchStreak(
          channelId: '42',
          milestoneId: 'm1',
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], 'ShareViewerMilestoneMutation');
      final input = (body['variables'] as Map)['input'] as Map;
      expect(input, {'channelID': '42', 'milestoneID': 'm1'});
    });

    test('an error code is a refusal', () async {
      reply({
        'data': {
          'shareViewerMilestone': {
            'milestone': null,
            'error': {'code': 'ALREADY_SHARED'},
          },
        },
      });

      expect(
        await service.shareWatchStreak(
          channelId: '42',
          milestoneId: 'm1',
          authToken: 'tok',
        ),
        ViewerActionOutcome.refused,
      );
    });
  });

  group('acknowledgeWarning', () {
    test('sends the channel', () async {
      reply({
        'data': {
          'acknowledgeChatWarning': {'error': null},
        },
      });

      expect(
        await service.acknowledgeWarning(channelId: '42', authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], 'AcknowledgeChatWarning');
      expect((body['variables'] as Map)['input'], {'channelID': '42'});
    });

    test('a non-numeric channel is never sent', () async {
      expect(
        await service.acknowledgeWarning(channelId: '4 2', authToken: 'tok'),
        ViewerActionOutcome.failed,
      );
      expect(requests, isEmpty);
    });
  });

  group('shareResub', () {
    test('sends the token, the channel and the optional message', () async {
      reply({
        'data': {
          'useChatNotificationToken': {'isSuccess': true},
        },
      });

      expect(
        await service.shareResub(
          channelLogin: 'somechannel',
          tokenId: 'token-1',
          message: 'Still here',
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], 'UseChatNotificationToken');
      expect(body['variables'], {
        'channelLogin': 'somechannel',
        'tokenID': 'token-1',
        'message': 'Still here',
      });
    });

    test('an empty message is sent as none', () async {
      reply({
        'data': {
          'useChatNotificationToken': {'isSuccess': true},
        },
      });

      await service.shareResub(
        channelLogin: 'somechannel',
        tokenId: 'token-1',
        message: '  ',
        authToken: 'tok',
      );

      expect(sent()['variables'], {
        'channelLogin': 'somechannel',
        'tokenID': 'token-1',
      });
    });

    test('isSuccess false is a failure', () async {
      reply({
        'data': {
          'useChatNotificationToken': {'isSuccess': false},
        },
      });

      expect(
        await service.shareResub(
          channelLogin: 'somechannel',
          tokenId: 'token-1',
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
    });

    test('a bad login or token is never sent', () async {
      expect(
        await service.shareResub(
          channelLogin: 'some channel',
          tokenId: 'token-1',
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
      expect(
        await service.shareResub(
          channelLogin: 'somechannel',
          tokenId: 'bad token',
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
      expect(requests, isEmpty);
    });
  });
  group('claimDrop', () {
    test('claims the drop instance with the viewer token', () async {
      reply(claimDropResponse());

      expect(
        await service.claimDrop(dropInstanceId: 'instance-a', authToken: 'tok'),
        DropClaimResult.claimed,
      );
      final body = sent();
      expect(body['operationName'], 'ClaimDropRewardsMutation');
      expect(body['variables'], {'dropInstanceId': 'instance-a'});
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('says when the game account must be linked first', () async {
      reply(claimDropResponse(connected: false));

      expect(
        await service.claimDrop(dropInstanceId: 'instance-a', authToken: 'tok'),
        DropClaimResult.needsAccountLink,
      );
    });

    test('sends nothing when signed out or for a bad id', () async {
      expect(
        await service.claimDrop(dropInstanceId: 'instance-a', authToken: ''),
        DropClaimResult.signedOut,
      );
      expect(
        await service.claimDrop(dropInstanceId: 'bad id!', authToken: 'tok'),
        DropClaimResult.failed,
      );
      expect(requests, isEmpty);
    });

    test('a server failure is a failed claim', () async {
      reply({'error': 'boom'}, status: 500);

      expect(
        await service.claimDrop(dropInstanceId: 'instance-a', authToken: 'tok'),
        DropClaimResult.failed,
      );
    });
  });
  group('contributeToGoal', () {
    test('sends the amount with a fresh transaction id', () async {
      reply(goalContributionResponse());

      expect(
        await service.contributeToGoal(
          channelId: '42',
          goalId: 'goal-1',
          amount: 250,
          authToken: 'tok',
        ),
        GoalContributionResult.contributed,
      );
      final input = sent()['variables']['input'] as Map;
      expect(sent()['operationName'], 'CommunityGoalMutation');
      expect(input['amount'], 250);
      expect(input['channelID'], '42');
      expect(input['goalID'], 'goal-1');
      expect(input['transactionID'], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('reports a Twitch refusal code', () async {
      reply(goalContributionResponse(errorCode: 'MAX_PER_STREAM'));

      expect(
        await service.contributeToGoal(
          channelId: '42',
          goalId: 'goal-1',
          amount: 250,
          authToken: 'tok',
        ),
        GoalContributionResult.maxPerStream,
      );
    });

    test('sends nothing signed out, for a bad id or a zero amount', () async {
      expect(
        await service.contributeToGoal(
          channelId: '42',
          goalId: 'goal-1',
          amount: 1,
          authToken: '',
        ),
        GoalContributionResult.signedOut,
      );
      expect(
        await service.contributeToGoal(
          channelId: 'x',
          goalId: 'goal-1',
          amount: 1,
          authToken: 'tok',
        ),
        GoalContributionResult.failed,
      );
      expect(
        await service.contributeToGoal(
          channelId: '42',
          goalId: 'goal-1',
          amount: 0,
          authToken: 'tok',
        ),
        GoalContributionResult.failed,
      );
      expect(requests, isEmpty);
    });
  });

  group('community moments', () {
    test('a claim sends the official mutation with the moment', () async {
      reply({
        'data': {
          'claimCommunityMoment': {
            'moment': {'id': 'm-1'},
            'error': null,
          },
        },
      });

      final result = await service.claimMoment(
        momentId: 'm-1',
        authToken: 'tok',
      );

      expect(result, MomentClaimResult.claimed);
      expect(sent()['operationName'], 'ClaimMomentMutation');
      expect(sent()['variables'], {'momentID': 'm-1'});
      expect(sent()['query'], contains('claimCommunityMoment('));
    });

    test('signed out or a bad id sends nothing', () async {
      expect(
        await service.claimMoment(momentId: 'm', authToken: ''),
        MomentClaimResult.signedOut,
      );
      expect(
        await service.claimMoment(momentId: 'bad id', authToken: 'tok'),
        MomentClaimResult.invalid,
      );
      expect(requests, isEmpty);
    });

    test('a transport failure is a failure', () async {
      reply(null, status: 500);
      expect(
        await service.claimMoment(momentId: 'm', authToken: 'tok'),
        MomentClaimResult.failed,
      );
    });
  });
}
