import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_community_highlights_service.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../fixtures/community_highlights_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchCommunityHighlightsService service;
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
    service = TwitchCommunityHighlightsService(dio);
  });

  void reply(Object body) => adapter.onPost(
    _gql,
    (s) => s.reply(200, body is String ? jsonDecode(body) : body),
    data: Matchers.any,
  );

  Map<String, dynamic> lastBody() =>
      (requests.last.data as Map).cast<String, dynamic>();

  test('asks anonymously with the web client id and the channel id', () async {
    reply(gqlGetViewablePollACTIVE);

    await service.getPoll('105584645');

    expect(
      requests.last.headers['Client-ID'],
      'kimne78kx3ncx6brgo4mv6wki5h1ko',
    );
    expect(requests.last.headers['Authorization'], isNull);
    expect(lastBody()['variables'], {'channelID': '105584645'});
    expect(lastBody()['query'], contains('viewablePoll'));
  });

  test('a malformed channel id never reaches the network', () {
    expect(() => service.getPoll('12 or 1=1'), throwsArgumentError);
    expect(() => service.getPinned(''), throwsArgumentError);
    expect(requests, isEmpty);
  });

  group('polls', () {
    test('active and completed polls', () async {
      reply(gqlGetViewablePollACTIVE);
      expect((await service.getPoll('105584645'))!.status, PollStatus.active);

      reply(gqlGetViewablePollCOMPLETED);
      expect(
        (await service.getPoll('105584645'))!.status,
        PollStatus.completed,
      );
    });

    test('no poll is null', () async {
      reply(gqlGetViewablePollAfterArchiveNull);
      expect(await service.getPoll('105584645'), isNull);
    });
  });

  group('predictions', () {
    test('the active one', () async {
      reply(gqlGetActivePredictionACTIVE);

      final predictions = await service.getPredictions('182714869');

      expect(predictions.active?.title, 'TOP 10?');
      expect(lastBody()['query'], contains('resolvedPredictionEvents'));
    });

    test('a locked one with the last resolved', () async {
      reply(gqlGetActivePredictionLOCKEDWithLastRESOLVED);

      final predictions = await service.getPredictions('1');

      expect(predictions.locked?.status, PredictionStatus.locked);
      expect(predictions.lastResolved?.status, PredictionStatus.resolved);
    });

    test('a partial resolver error keeps the rest of the answer', () async {
      final body =
          jsonDecode(gqlGetActivePredictionACTIVE) as Map<String, dynamic>;
      body['errors'] = [
        {
          'message': 'server error',
          'path': [
            'user',
            'channel',
            'resolvedPredictionEvents',
            'edges',
            0,
            'node',
            'createdBy',
          ],
        },
      ];
      reply(body);

      final predictions = await service.getPredictions('182714869');

      expect(predictions.active, isNotNull);
    });
  });

  group('pinned', () {
    test('the pinned message', () async {
      reply(gqlGetPinnedChat0);
      final pin = await service.getPinned('145972905');
      expect(pin?.senderLogin, 'nightbot');
    });

    test('nothing pinned is null', () async {
      reply({
        'data': {
          'channel': {
            'id': '1',
            'pinnedChatMessages': {'edges': <Object>[]},
          },
        },
      });
      expect(await service.getPinned('1'), isNull);
    });
  });

  test(
    'an error on the asked field fails instead of reading as none',
    () async {
      reply({
        'errors': [
          {
            'message': 'service timeout',
            'path': ['user', 'viewablePoll'],
          },
        ],
        'data': {
          'user': {'id': '1', 'viewablePoll': null},
        },
      });
      await expectLater(
        service.getPoll('1'),
        throwsA(isA<CommunityHighlightsApiException>()),
      );

      reply({
        'errors': [
          {
            'message': 'service timeout',
            'path': ['channel', 'pinnedChatMessages'],
          },
        ],
        'data': {
          'channel': {'id': '1', 'pinnedChatMessages': null},
        },
      });
      await expectLater(
        service.getPinned('1'),
        throwsA(isA<CommunityHighlightsApiException>()),
      );
    },
  );

  test('integrity and data-less errors throw typed', () async {
    reply({
      'errors': [
        {'message': 'failed integrity check'},
      ],
      'data': {
        'user': {'id': '1'},
      },
    });
    await expectLater(
      service.getPoll('1'),
      throwsA(
        isA<CommunityHighlightsApiException>().having(
          (e) => e.isIntegrity,
          'integrity',
          true,
        ),
      ),
    );

    reply({
      'errors': [
        {'message': 'service timeout'},
      ],
      'data': null,
    });
    await expectLater(
      service.getPinned('1'),
      throwsA(isA<CommunityHighlightsApiException>()),
    );

    adapter.onPost(
      _gql,
      (s) => s.reply(200, 'not json at all'),
      data: Matchers.any,
    );
    await expectLater(service.getPoll('1'), throwsA(isA<ApiException>()));
  });
}
