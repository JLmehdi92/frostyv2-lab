import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/models/community_points.dart';

import '../fixtures/community_points_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

const _reward = PointsReward(id: 'r1', title: 'Hydrate', cost: 100);

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchPointsService service;
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
    service = TwitchPointsService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  Future<String?> redeem() =>
      service.redeemReward(channelId: '42', reward: _reward, authToken: 'tok');

  group('a mutation reduces the reply to an error code', () {
    test('no error is success', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {'error': null},
        },
      });

      expect(await redeem(), isNull);
    });

    test('the error code is passed through', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {
            'error': {'code': 'NOT_ENOUGH_POINTS'},
          },
        },
      });

      expect(await redeem(), 'NOT_ENOUGH_POINTS');
    });

    test('an error object without a code is unknown', () async {
      reply({
        'data': {
          'redeemCommunityPointsCustomReward': {'error': <String, dynamic>{}},
        },
      });

      expect(await redeem(), 'unknown_error');
    });

    test('a top-level error message is passed through', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      expect(await redeem(), 'failed integrity check');
    });

    test('a top-level error without a message is unknown', () async {
      reply({
        'errors': [<String, dynamic>{}],
      });

      expect(await redeem(), 'unknown_error');
    });

    test('an empty payload is not mistaken for success', () async {
      reply({
        'data': {'redeemCommunityPointsCustomReward': null},
      });

      expect(await redeem(), 'unknown_error');
    });

    test('a reply without data is not mistaken for success', () async {
      reply(<String, dynamic>{});

      expect(await redeem(), 'unknown_error');
    });

    test('a server error is a request failure', () async {
      reply({'error': 'boom'}, status: 500);

      expect(await redeem(), 'request_failed');
    });

    test('a connection error is a request failure', () async {
      adapter.onPost(
        _gql,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: _gql),
            reason: 'offline',
          ),
        ),
        data: Matchers.any,
      );

      expect(await redeem(), 'request_failed');
    });

    test(
      'a refused token is reported as such, not as a network error',
      () async {
        reply({'error': 'Unauthorized'}, status: 401);

        final code = await redeem();

        expect(code, 'unauthorized');
        expect(
          PointsActionResult.fromError(code).status,
          PointsActionStatus.notAuthenticated,
        );
      },
    );
  });

  test('the default client gives up on a hung request', () {
    final options = TwitchPointsService.defaultOptions;

    expect(options.connectTimeout, const Duration(seconds: 5));
    expect(options.receiveTimeout, const Duration(seconds: 10));
  });

  Map<String, dynamic> body(RequestOptions request) =>
      (request.data as Map).cast<String, dynamic>();

  Map<String, dynamic> input(RequestOptions request) =>
      ((body(request)['variables'] as Map)['input'] as Map)
          .cast<String, dynamic>();

  group('mutation requests', () {
    setUp(
      () => reply({
        'data': {
          'redeemCommunityPointsCustomReward': {'error': null},
          'claimCommunityPoints': {'error': null},
          'makePrediction': {'error': null},
        },
      }),
    );

    test('carry the web client id and the viewer token', () async {
      await redeem();

      final request = requests.single;
      expect(request.uri.toString(), _gql);
      expect(request.headers['Client-ID'], 'kimne78kx3ncx6brgo4mv6wki5h1ko');
      expect(request.headers['Authorization'], 'OAuth tok');
    });

    test('a redeem names its mutation and sends the reward', () async {
      await redeem();

      final query = body(requests.single)['query'] as String;
      expect(query, contains('redeemCommunityPointsCustomReward'));
      expect(query, contains('RedeemCommunityPointsCustomRewardInput!'));
      final sent = input(requests.single);
      expect(sent['channelID'], '42');
      expect(sent['rewardID'], 'r1');
      expect(sent['title'], 'Hydrate');
      expect(sent['cost'], 100);
      expect(sent['transactionID'], isA<String>());
      expect(sent['transactionID'], isNotEmpty);
      expect(sent.containsKey('prompt'), isFalse);
    });

    test('a prompt is sent only when given', () async {
      await service.redeemReward(
        channelId: '42',
        reward: _reward,
        authToken: 'tok',
        userInput: 'hello',
      );

      expect(input(requests.single)['prompt'], 'hello');
    });

    test('every spend gets its own transaction id', () async {
      await redeem();
      await redeem();

      expect(
        input(requests.first)['transactionID'],
        isNot(input(requests.last)['transactionID']),
      );
    });

    test('a claim sends the channel and the chest', () async {
      await service.claimBonus(
        channelId: '42',
        claimId: 'chest',
        authToken: 'tok',
      );

      final query = body(requests.single)['query'] as String;
      expect(query, contains('claimCommunityPoints'));
      expect(query, contains('ClaimCommunityPointsInput!'));
      expect(input(requests.single), {'channelID': '42', 'claimID': 'chest'});
    });

    test('a bet sends the event, the outcome and the stake', () async {
      await service.makePrediction(
        eventId: 'e',
        outcomeId: 'o',
        points: 500,
        authToken: 'tok',
      );

      final query = body(requests.single)['query'] as String;
      expect(query, contains('makePrediction'));
      expect(query, contains('MakePredictionInput!'));
      final sent = input(requests.single);
      expect(sent['eventID'], 'e');
      expect(sent['outcomeID'], 'o');
      expect(sent['points'], 500);
      expect(sent['transactionID'], isNotEmpty);
    });
  });

  group('fetchContext', () {
    test('reads the balance, the chest, the name and the icon', () async {
      reply(pointsContextFull);

      final context = await service.fetchContext(
        userLogin: 'streamer',
        authToken: 'tok',
      );

      expect(context.balance, 12345);
      expect(context.availableClaimId, 'claim-1');
      expect(context.pointsName, 'Tomcoins');
      expect(
        context.pointsImageUrl,
        'https://static-cdn.example/points/icon-1.png',
      );
      expect(requests.single.headers['Authorization'], 'OAuth tok');
      expect((body(requests.single)['variables'] as Map)['login'], 'streamer');
    });

    test('merges built-in and custom rewards, enabled only, by cost', () async {
      reply(pointsContextFull);

      final context = await service.fetchContext(userLogin: 'streamer');

      expect(context.rewards.map((r) => r.id), [
        'custom-small',
        'auto-highlight',
        'custom-big',
      ]);
      final highlight = context.rewards[1];
      expect(highlight.isAutomatic, isTrue);
      expect(highlight.title, 'Highlight my message');
      expect(highlight.imageUrl, 'https://static-cdn.example/hl.png');
      final big = context.rewards.last;
      expect(big.requiresInput, isTrue);
      expect(big.backgroundColor, const Color(0xFF1F69FF));
    });

    test('reads the running prediction', () async {
      reply(pointsContextFull);

      final context = await service.fetchContext(userLogin: 'streamer');

      final prediction = context.activePrediction!;
      expect(prediction.id, 'pred-1');
      expect(prediction.isOpen, isTrue);
      expect(prediction.outcomes.map((o) => o.id), ['o-yes', 'o-no']);
      expect(prediction.totalPoints, 4000);
    });

    test('signed out: no balance, everything else still read', () async {
      reply(pointsContextSignedOut);

      final context = await service.fetchContext(userLogin: 'streamer');

      expect(context.balance, isNull);
      expect(context.availableClaimId, isNull);
      expect(context.hasAnything, isFalse);
    });

    test('an unknown channel is an empty context', () async {
      reply(pointsContextNoChannel);

      final context = await service.fetchContext(userLogin: 'nobody');

      expect(context.hasAnything, isFalse);
      expect(context.rewards, isEmpty);
    });

    test('a failure is an empty context, never a throw', () async {
      reply({'error': 'boom'}, status: 500);

      final context = await service.fetchContext(userLogin: 'streamer');

      expect(context.hasAnything, isFalse);
    });

    test('no token, or an empty one, sends no Authorization', () async {
      reply(pointsContextSignedOut);

      await service.fetchContext(userLogin: 'streamer');
      await service.fetchContext(userLogin: 'streamer', authToken: '');

      for (final request in requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.headers['Client-ID'], 'kimne78kx3ncx6brgo4mv6wki5h1ko');
      }
    });

    test('parseContext tolerates wrongly typed sections', () {
      final context = TwitchPointsService.parseContext({
        'data': {
          'channel': {
            'self': 'nope',
            'communityPointsSettings': 5,
            'activePredictionEvents': {'not': 'a list'},
          },
        },
      });

      expect(context.balance, isNull);
      expect(context.rewards, isEmpty);
      expect(context.predictions, isEmpty);
    });
  });
}
