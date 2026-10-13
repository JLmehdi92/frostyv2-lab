import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../fixtures/hype_train_gql.dart';
import '../fixtures/hype_train_payloads.dart';
import '../fixtures/hype_train_payloads_tbc.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchHypeTrainService service;
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
    service = TwitchHypeTrainService(dio);
  });

  /// Fixtures are raw JSON strings, decoded unless [raw]; maps go as is.
  void reply(Object body, {int status = 200, bool raw = false}) =>
      adapter.onPost(
        _gql,
        (s) =>
            s.reply(status, body is String && !raw ? jsonDecode(body) : body),
        data: Matchers.any,
      );

  Map<String, dynamic> lastBody() =>
      (requests.last.data as Map).cast<String, dynamic>();

  group('getHypeTrain', () {
    test('sends the lean execution document anonymously', () async {
      reply(htGqlNone);

      await service.getHypeTrain('42');

      expect(requests.last.uri.toString(), _gql);
      expect(requests.last.headers['Client-ID'], kTwitchWebClientId);
      expect(requests.last.headers['Authorization'], isNull);
      final body = lastBody();
      expect(body['operationName'], 'GetHypeTrainExecution');
      expect(body['variables'], {
        'channelId': '42',
        'includeSharedHypeTrain': true,
      });
      final query = body['query'] as String;
      expect(query, isNot(contains('levels {')));
      expect(query, contains('isFastMode'));
      expect(query, contains('kickoff { minPoints }'));
    });

    test('a running regular train', () async {
      reply(htGqlActive);

      final snapshot = await service.getHypeTrain('42');

      final train = (snapshot as HtOngoingSnapshot).train;
      expect(train.level, 7);
      expect(train.progress.value, 1540);
      expect(train.progress.goal, 4700);
      expect(train.variant, HtVariant.regular);
    });

    test('a golden kappa train', () async {
      reply(htGqlGolden);

      final snapshot = await service.getHypeTrain('42');

      expect(
        (snapshot as HtOngoingSnapshot).train.variant,
        HtVariant.goldenKappa,
      );
    });

    test('a live shared train with fast mode and kickoff', () async {
      reply(htGqlShared);

      final train =
          ((await service.getHypeTrain('46')) as HtOngoingSnapshot).train;

      expect(train.level, 4);
      expect(train.progress.value, 1500);
      expect(train.progress.goal, 2300);
      expect(train.progress.total, 7000);
      expect(train.isFastMode, isFalse);
      expect(train.config.kickoffMinPoints, 100);
      expect(train.config.maxLevel, 392);
      expect(train.shared, isNotNull);
      expect(train.conductors, hasLength(1));
    });

    test('no train', () async {
      reply(htGqlNone);

      expect(await service.getHypeTrain('42'), isA<HtNoTrain>());
    });

    test('an approaching train', () async {
      reply(htTbcGqlApproaching);

      final snapshot = await service.getHypeTrain('42');

      expect((snapshot as HtApproachingSnapshot).approaching.id, 'approach-1');
    });

    test('an unknown channel is no train', () async {
      reply({
        'data': {'user': null},
      });

      expect(await service.getHypeTrain('42'), isA<HtNoTrain>());
    });

    test('an ended execution is no train', () async {
      reply({
        'data': {
          'user': {
            'id': '42',
            'channel': {
              'id': '42',
              'hypeTrain': {
                'execution': {
                  'id': 'train',
                  'isActive': false,
                  'progress': {
                    'goal': 100,
                    'progression': 0,
                    'total': 100,
                    'level': {'value': 1, 'goal': 100},
                  },
                },
                'approaching': null,
              },
            },
          },
        },
      });

      expect(await service.getHypeTrain('42'), isA<HtNoTrain>());
    });

    test('the snapshot records when it was fetched', () async {
      reply(htGqlActive);
      final before = DateTime.now();

      final snapshot = await service.getHypeTrain('42') as HtOngoingSnapshot;

      expect(snapshot.fetchedAt.isBefore(before), isFalse);
    });

    test('GQL errors are typed; integrity is flagged', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });

      await expectLater(
        service.getHypeTrain('42'),
        throwsA(
          isA<HypeTrainApiException>().having(
            (e) => e.isIntegrity,
            'isIntegrity',
            isTrue,
          ),
        ),
      );
    });

    test('other GQL errors are not integrity', () async {
      reply({
        'errors': [
          {'message': 'service timeout'},
        ],
      });

      await expectLater(
        service.getHypeTrain('42'),
        throwsA(
          isA<HypeTrainApiException>().having(
            (e) => e.isIntegrity,
            'isIntegrity',
            isFalse,
          ),
        ),
      );
    });

    test('transport errors stay ApiExceptions', () async {
      reply({'error': 'oops'}, status: 500);

      await expectLater(
        service.getHypeTrain('42'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a body that is not a map is a typed error', () async {
      for (final body in <Object>[
        [
          {'data': null},
        ],
        'oops',
      ]) {
        reply(body, raw: true);

        await expectLater(
          service.getHypeTrain('42'),
          throwsA(isA<HypeTrainApiException>()),
        );
      }
    });

    test('a nested error keeps the rest of the answer', () async {
      final body = jsonDecode(htGqlActive) as Map<String, dynamic>;
      reply({
        ...body,
        'errors': [
          {
            'message': 'service error',
            'path': [
              'user',
              'channel',
              'hypeTrain',
              'execution',
              'allTimeHigh',
            ],
          },
        ],
      });

      final snapshot = await service.getHypeTrain('42');

      expect((snapshot as HtOngoingSnapshot).train.level, 7);
    });

    test('community details ask for the max reward level', () async {
      reply(htGqlNone);

      await service.getHypeTrain('42');

      expect(lastBody()['query'], contains('maxRewardLevel'));
    });

    test('a malformed channel id is refused before any request', () async {
      expect(() => service.getHypeTrain('12a'), throwsArgumentError);
      expect(requests, isEmpty);
    });
  });

  group('getUpcomingRewards', () {
    test('groups the emotes by level, in level order', () async {
      reply(htGqlRewards);

      final rewards = await service.getUpcomingRewards('44');

      expect(rewards.map((r) => r.$1), [1, 5, 10, 50, 126]);
      expect(rewards.first.$2, hasLength(2));
      expect(rewards.first.$2.first.type, HtRewardType.emote);
      expect(rewards.first.$2.first.emoteUrl, isNotNull);
      expect(lastBody()['operationName'], 'GetHypeTrainRewards');
      expect(lastBody()['variables'], {'channelId': '44'});
    });

    test('never throws: errors and failures are empty', () async {
      reply({
        'errors': [
          {'message': 'nope'},
        ],
      });
      expect(await service.getUpcomingRewards('42'), isEmpty);

      reply({'error': 'oops'}, status: 500);
      expect(await service.getUpcomingRewards('42'), isEmpty);

      reply(htGqlNone);
      expect(await service.getUpcomingRewards('42'), isEmpty);

      expect(await service.getUpcomingRewards('bad id'), isEmpty);
    });
  });

  group('getActiveStatuses', () {
    test('parses the statuses of the running trains', () async {
      reply({
        'data': {
          'allActiveHypeTrainStatuses': [
            {
              'channel': {'id': '1'},
              'level': 5,
              'isAllTimeHighTrain': false,
              'isSharedTrain': true,
              'hypeTrainType': 'REGULAR',
            },
            {
              'channel': {'id': '2'},
              'level': 18,
              'isAllTimeHighTrain': true,
              'isSharedTrain': false,
              'hypeTrainType': 'TREASURE',
            },
            {'channel': null, 'level': 3},
          ],
        },
      });

      final statuses = await service.getActiveStatuses(['1', '2', '3']);

      expect(statuses.keys, unorderedEquals(['1', '2']));
      expect(statuses['1']!.isShared, isTrue);
      expect(statuses['2']!.level, 18);
      expect(statuses['2']!.variant, HtVariant.treasure);
      expect(statuses['2']!.isAllTimeHigh, isTrue);
      expect(lastBody()['variables'], {
        'channelIds': ['1', '2', '3'],
      });
    });

    test('asks 100 channels at a time, skipping bad ids', () async {
      reply({
        'data': {'allActiveHypeTrainStatuses': <Object>[]},
      });

      await service.getActiveStatuses([
        for (var i = 1; i <= 250; i++) '$i',
        'bad id',
      ]);

      expect(requests, hasLength(3));
      expect(
        ((requests.last.data as Map)['variables'] as Map)['channelIds'],
        hasLength(50),
      );
    });

    test('never throws', () async {
      reply({'error': 'oops'}, status: 500);

      expect(await service.getActiveStatuses(['1']), isEmpty);
      expect(await service.getActiveStatuses(const []), isEmpty);
    });
  });

  test('normalizeChannelId', () {
    expect(TwitchHypeTrainService.normalizeChannelId('42'), '42');
    expect(TwitchHypeTrainService.normalizeChannelId(' 42 '), '42');
    for (final bad in ['', '12a', '-1', '1' * 21, '4 2']) {
      expect(
        () => TwitchHypeTrainService.normalizeChannelId(bad),
        throwsArgumentError,
        reason: bad,
      );
    }
  });
}
